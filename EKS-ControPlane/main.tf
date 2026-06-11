data "terraform_remote_state" "Iam_details" {
    backend = "s3"
    config = {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/iam.tfstate"
        region = "ap-south-1"
    }
}

data "terraform_remote_state" "vpc_details" {
    backend = "s3"
    config = {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/eks/vpc.tfstate"
        region = "ap-south-1"
    }
}

resource "aws_kms_key" "key_for_etcd_encryption" {
    description             = "An example symmetric encryption KMS key"
    enable_key_rotation     = true
    deletion_window_in_days = 30

     tags = {
        Name = "etcd_encryption_key"
        Environment = "production"
        Project = "eks"
    }
}

resource "aws_kms_alias" "alias_etcd_kms_key" {
    name          = "alias/eks-etcd-encryption-key"
    target_key_id = aws_kms_key.key_for_etcd_encryption.key_id
}

resource "aws_cloudwatch_log_group" "logs_eks_group" {
    name = "/aws/eks/production-eks-cluster/cluster"
     # AWS expects this exact naming format(/aws/eks/<cluster-name>/cluster)
    retention_in_days = 90
     tags = {
        Name = "eks-cluster-logs"
        Environment = "production"
        Project = "eks"
    }
}


resource "aws_eks_cluster" "main_eks_cluster" {
    name = "production-eks-cluster"
    version = "1.30"
    role_arn = data.terraform_remote_state.Iam_details.outputs.eksClusterRoleARN
    vpc_config {
        subnet_ids = concat (
           data.terraform_remote_state.vpc_details.outputs.pri_subnet_ids,
            data.terraform_remote_state.vpc_details.outputs.intra_subnet_idss)
        endpoint_private_access = true
        endpoint_public_access = false
        security_group_ids = [aws_security_group.eks_control_Sg.id]
        
    }
    enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    encryption_config {
        
        resources = ["secrets"]
        provider {
            key_arn = aws_kms_key.key_for_etcd_encryption.arn
        }

    }
    access_config {
        authentication_mode = "API_AND_CONFIGMAP"
    }

    depends_on = [
        aws_kms_key.key_for_etcd_encryption,
        aws_kms_alias.alias_etcd_kms_key,
        aws_cloudwatch_log_group.logs_eks_group,
        aws_security_group.eks_control_sg_rule
    ]
     tags = {
        Name = "production-eks-cluster"
        Environment = "production"
        Project = "eks"
    }
}

resource "aws_security_group" "eks_control_Sg" {
    name = "eks_cluster_security_group"
    description = "Security group for EKS control plane"
    vpc_id = data.terraform_remote_state.vpc_details.outputs.eks_vpc_id
     tags = {
        Name = "eks-cluster-sg"
        Environment = "production"
        Project = "eks"
    }
}

resource "aws_security_group_rule" "eks_control_sg_Inrule" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_group_id = aws_security_group.eks_control_Sg.id
    source_security_group_id = aws_security_group.eks_nodes_sg.id
    description = "Allow worker nodes to reach API server"
}

resource "aws_security_group_rule" "eks_control_sg_OutRule" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    security_group_id = aws_security_group.eks_control_Sg.id
    source_security_group_id = aws_security_group.eks_nodes_sg.id
    description = "Allow API server to reach worker nodes"
}


resource "aws_security_group" "eks_nodes_sg" {
    name = "eks_worker_nodes_security_group"
    description = "Security group for EKS worker nodes"
    vpc_id = data.terraform_remote_state.vpc_details.outputs.eks_vpc_id
     tags = {
        Name = "eks-worker-nodes-sg"
        Environment = "production"
        Project = "eks"
        "kubernetes.io/cluster/production-eks-cluster" = "owned"
    }
}

resource "aws_security_group_rule" "eks_node_inrule" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    security_group_id = aws_security_group.eks_nodes_sg.id
    source_security_group_id = aws_security_group.eks_control_Sg.id
    description = "Allow API server to reach worker nodes"
}

resource "aws_security_group_rule" "eks_node_inRule" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    security_group_id = aws_security_group.eks_nodes_sg.id
    self              = true
    description = "This Rule is for communication of nodes"
}

resource "aws_security_group_rule" "eks_nodes_outrule" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_group_id = aws_security_group.eks_nodes_sg.id
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow worker nodes to reach outside"
}

data "tls_certificate" "OIDC_cert" {
  url = aws_eks_cluster.main_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.OIDC_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main_eks_cluster.identity[0].oidc[0].issuer

   tags = {
    Name        = "production-eks-cluster-provider"
    Environment = "production"
    Project     = "eks"
  }
}