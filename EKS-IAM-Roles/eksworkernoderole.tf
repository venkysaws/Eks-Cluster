resource "aws_iam_role" "eksWorkerRole" {
  name = "eksWorkerRole"
  description = "IAM role for EKS worker nodes - production"
  path = "/eks/prod/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "EKSNodeAssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "eks-cluster"
    Component   = "eks-worker-nodes"
  }
}

resource "aws_iam_role_policy_attachment" "workerNodePolicy" {
    role       = aws_iam_role.eksWorkerRole.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    depends_on = [aws_iam_role.eksWorkerRole]
}

resource "aws_iam_role_policy_attachment" "workerVPCCniPolicy" {
    role = aws_iam_role.eksWorkerRole.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    depends_on = [aws_iam_role.eksWorkerRole]
}

resource "aws_iam_role_policy_attachment" "ECRPolicy" {
    role = aws_iam_role.eksWorkerRole.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    depends_on = [aws_iam_role.eksWorkerRole]
}

