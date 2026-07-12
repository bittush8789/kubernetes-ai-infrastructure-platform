terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # This is configured to use a local backend by default for ease of testing, 
  # but can be pointed to an S3 backend in production.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for MLflow Model Registry artifacts
resource "aws_s3_bucket" "model_registry" {
  bucket        = "k8s-ai-platform-model-registry-bucket"
  force_destroy = true

  tags = {
    Name        = "k8s-ai-platform-model-registry-bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "model_registry_block" {
  bucket = aws_s3_bucket.model_registry.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Module 1: VPC Provisioning
module "vpc" {
  source               = "./modules/vpc"
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# Module 2: IAM (Initial cluster roles)
module "iam_initial" {
  source                     = "./modules/iam"
  cluster_name               = var.cluster_name
  enable_irsa                = false
  model_registry_bucket_name = aws_s3_bucket.model_registry.id
}

# Module 3: EKS Cluster & Node Groups
module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  cluster_role_arn   = module.iam_initial.eks_cluster_role_arn
  node_role_arn      = module.iam_initial.eks_node_group_role_arn
  subnet_ids         = module.vpc.private_subnet_ids
  min_size           = var.node_group_min_size
  max_size           = var.node_group_max_size
  desired_size       = var.node_group_desired_size
  cpu_instance_types = var.cpu_instance_types
  gpu_instance_types = var.gpu_instance_types
}

# Module 4: IAM with IRSA bindings (post-EKS creation)
module "iam_irsa" {
  source                     = "./modules/iam"
  cluster_name               = var.cluster_name
  enable_irsa                = true
  oidc_arn                   = module.eks.oidc_arn
  oidc_provider              = module.eks.oidc_provider
  model_registry_bucket_name = aws_s3_bucket.model_registry.id
}
