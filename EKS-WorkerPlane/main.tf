data "terraform_remote_state" "Iam_details" {
    backend = "s3"
    config = {
        
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/iam.tfstate"
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

data "terraform_remote_state" "Controlplane_details" {
    backend = "s3"
    config = {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/eks/controlplane.tfstate"
        region = "ap-south-1"
    }
}

resource "aws_launch_template" "System_node_group_template" {
    name = "System-node-group"
    description = ""
    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = 50
            volume_type = "gp3"
            delete_on_termination = true
            encrypted             = true
        }
    }
    metadata_options {
        http_endpoint = "enabled"
        http_tokens   = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags = "enabled"
    }

    vpc_security_group_ids = [
      data.terraform_remote_state.Controlplane_details.outputs.node_group_sg_id
  ]

  tag_specifications {
    resource_type = "instance" 
    tags = {
    "Name" = "production-eks-cluster-System-node-group"
    "ManagedBy" = "terraform"
    "Environment" = "production"
    "Project" = "eks"
    }
  }
    
  tag_specifications {
    resource_type = "volume"
    tags = {
        "Name" = "production-eks-cluster-System-node-group"
        "ManagedBy" = "terraform"
        "Environment" = "production"
        "Project" = "eks"  
    }
  }
}


resource "aws_eks_node_group" "System_node_group" {
    cluster_name = data.terraform_remote_state.Controlplane_details.outputs.cluster_name
    node_group_name = "System-node-group"
    node_role_arn = data.terraform_remote_state.Iam_details.outputs.eksNodeRoleARN
    subnet_ids = data.terraform_remote_state.vpc_details.outputs.pri_subnet_ids
            
    scaling_config {
        desired_size = 2
        max_size = 3
        min_size = 1
    }
    instance_types = ["m7i-flex.large", "m5a.large"]
    remote_access {
        ec2_ssh_key = "newkey(27/5)"
    }
    launch_template {
        id = aws_launch_template.System_node_group_template.id
        version = aws_launch_template.System_node_group_template.latest_version
    }
    capacity_type = "ON_DEMAND"

    labels = {
        role = "system"
        environment = "production"
        project = "eks"
    }

    taint {
        key = "CriticalAddonsOnly"
        value = "true"
        effect = "NO_SCHEDULE"
    }

    update_config {
        max_unavailable = 1
    }

    tags = {
    Name                                            = "${var.cluster_name}-system-node-group"
    Environment                                     = production
    project                                         = "eks"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }

    lifecycle {
      ignore_changes = [
         scaling_config[0].desired_size
      ]
    }
}


resource "aws_launch_template" "app_node_group_template" {
    name = "app_node_group"
    description = ""
    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = 50
            volume_type = "gp3"
            delete_on_termination = true
            encrypted             = true
        }
    }
    metadata_options {
        http_endpoint = "enabled"
        http_tokens   = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags = "enabled"
    }
    vpc_security_group_ids = [
     data.terraform_remote_state.Controlplane_details.outputs.node_group_sg_id
     ]
    tag_specifications {
        resource_type = "instance" 
        tags = {
        "Name" = "production-eks-cluster-app-node-group"
        "ManagedBy" = "terraform"
        "Environment" = "production"
        "Project" = "eks"
      }
    }

    tag_specifications {
        resource_type = "volume"
        tags = {
            "Name" = "production-eks-cluster-app-node-group"
            "ManagedBy" = "terraform"
            "Environment" = "production"
            "Project" = "eks"  
        }
    }
}

resource "aws_eks_node_group" "app_node_group" {
    cluster_name = data.terraform_remote_state.Controlplane_details.outputs.cluster_name
    node_role_arn   = data.terraform_remote_state.Iam_details.outputs.eksNodeRoleARN
    node_group_name = "app-node-group"
    subnet_ids = data.terraform_remote_state.vpc_details.outputs.pri_subnet_ids
    scaling_config {
        desired_size = 2
        max_size = 3
        min_size = 1
    }
    launch_template {
        id = aws_launch_template.app_node_group_template.id
        version = aws_launch_template.app_node_group_template.latest_version
    }
    update_config {
        max_unavailable = 1
    }
    instance_types = ["m7i-flex.large", "m5a.large"]
    remote_access {
        ec2_ssh_key = "newkey(27/5)"
    }
    lifecycle {
      ignore_changes = [
      scaling_config[0].desired_size
      ]
    }

    labels = {
        role = "app"
        environment = "production"
        project = "eks"
    }

    tags = {
      Name = "${var.cluster_name}-app-node-group"
    "Environment" = "production"
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "project" = "eks"
    }
    
}
