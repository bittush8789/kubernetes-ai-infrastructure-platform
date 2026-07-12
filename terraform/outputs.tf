output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "The EKS Cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "The certificate authority data for EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "model_registry_bucket_arn" {
  description = "The S3 bucket ARN for MLflow model storage"
  value       = aws_s3_bucket.model_registry.arn
}

output "irsa_s3_access_role_arn" {
  description = "IAM Role ARN for Kubernetes S3 service account integration (IRSA)"
  value       = module.iam_irsa.s3_access_role_arn
}
