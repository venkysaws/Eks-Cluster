output "eks_clsuter_id" {
    value = aws_eks_cluster.main_eks_cluster.id
    description = "EKS Cluster ID"
}

output "cluster_name" {
    value = aws_eks_cluster.main_eks_cluster.name
    description = "EKS Cluster Name"
}

output "eks_cluster_endpoint" {
    value = aws_eks_cluster.main_eks_cluster.endpoint
    description = "EKS Cluster Endpoint"
}

output "eks_cluster_arn" {
    value = aws_eks_cluster.main_eks_cluster.arn
    description = "EKS Cluster ARN"
}

output "cluster_ca_certificate"{
    value = aws_eks_cluster.main_eks_cluster.certificate_authority[0].data
    description = "EKS Cluster Certificate Authority Data"
    
}

output "eks_control_sg_id" {
    value = aws_security_group.eks_control_Sg.id
    description = "Security Group ID for EKS Control Plane"
}

output "kms_key_id" {
    value = aws_kms_key.key_for_etcd_encryption.key_id
    description = "KMS Key ID for etcd encryption"
}

output "node_group_sg_id" {
    value = aws_security_group.eks_nodes_sg.id
    description = "Security Group ID for EKS Nodes"
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
  # Needed when creating IRSA roles for pods
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
