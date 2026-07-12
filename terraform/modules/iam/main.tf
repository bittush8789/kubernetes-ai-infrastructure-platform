# Cluster Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Node Group Role
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

# S3 Access Role for MLflow / KServe via OIDC (IRSA)
resource "aws_iam_role" "s3_access" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = [
              "system:serviceaccount:ml-platform:mlflow-sa",
              "system:serviceaccount:kserve:kserve-sa"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_bucket_policy" {
  count       = var.enable_irsa ? 1 : 0
  name        = "${var.cluster_name}-s3-bucket-policy"
  description = "Permissions for MLflow and KServe to read/write to model registry S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.model_registry_bucket_name}",
          "arn:aws:s3:::${var.model_registry_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  count      = var.enable_irsa ? 1 : 0
  policy_arn = aws_iam_policy.s3_bucket_policy[0].arn
  role       = aws_iam_role.s3_access[0].name
}

# Variables
variable "cluster_name" { type = string }
variable "enable_irsa" {
  type    = bool
  default = false
}
variable "oidc_arn" {
  type    = string
  default = ""
}
variable "oidc_provider" {
  type    = string
  default = ""
}
variable "model_registry_bucket_name" {
  type    = string
  default = "ai-platform-model-registry"
}

# Outputs
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "s3_access_role_arn" {
  value = length(aws_iam_role.s3_access) > 0 ? aws_iam_role.s3_access[0].arn : ""
}
