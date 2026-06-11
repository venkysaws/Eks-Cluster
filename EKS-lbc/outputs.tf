# eks-lbc/outputs.tf

output "lbc_role_arn" {
  description = "ARN of the LBC IAM role"
  value       = aws_iam_role.lbc_role.arn
}

output "lbc_service_account_name" {
  description = "Name of the LBC Kubernetes service account"
  value       = kubernetes_service_account.lbc.metadata[0].name
}


