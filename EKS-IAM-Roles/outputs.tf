output "eksClusterRoleARN" {
    value = aws_iam_role.EksClusterRole.arn
    description = "ARN of the EKS cluster IAM role"
}

output "ekClusterRoleName" {
    value = aws_iam_role.EksClusterRole.name
    description = "Name of the EKS cluster IAM role"
}

output "eksNodeRoleARN" {
    value = aws_iam_role.eksWorkerRole.arn
    description = "Arn of the EKS WorkerRole"
}

output "eksNodeRoleARN" {
    value = aws_iam_role.eksWorkerRole.name
    description = "Name of the EKS WorkerRole"
}