output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate data (base64 encoded)"
  value       = module.eks.cluster_certificate_authority_data
}

output "node_iam_role_name" {
  description = "IAM role name for Karpenter-managed nodes"
  value       = module.karpenter.node_iam_role_name
}
