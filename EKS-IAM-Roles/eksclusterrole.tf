resource "aws_iam_role" "EksClusterRole" {
  name = "test_role"
  description = "IAM role for EKS Cluster - production"
  path = "/eks/prod/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "EKSClusterAssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "eks"
    Component   = "eks-Cluster"
  }
}

resource "aws_iam_role_policy_attachment" "EksClusterRoleAttachment" {
  role       = aws_iam_role.EksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
