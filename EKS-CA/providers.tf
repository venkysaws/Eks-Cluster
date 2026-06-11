terraform {
    required_version = "=>1.6.0"
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~>5.0"
        }

        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "~>2.24"
        }

        helm = {
            source = "hashicorp/helm"
            version = "~> 2.12"
        }
    }

    backend "s3" {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/eks/ca.tfstate"
        region = "ap-south-1"
        dynamodb_table = "statelock"
        encrypt = true  
    }

}

    provider "aws" {
        region = "ap-south-1"

        default_tags {
            tags = {
                ManagedBy   = "terraform"
                Environment = "production"
                Project     = "eks"
            }
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


provider "kubernetes" {
    host = data.terraform_remote_state.Controlplane_details.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.Controlplane_details.outputs.cluster_ca_certificate)
    exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command = "aws"
        args = [
                "eks",
                "get-token",
                "--cluster-name",
                data.terraform_remote_state.Controlplane_details.outputs.cluster_name 
        ]
    }
}

provider "helm" {
    kubernetes = {
        host = data.terraform_remote_state.Controlplane_details.outputs.eks_cluster_endpoint
        cluster_ca_certificate = base64decode(data.terraform_remote_state.Controlplane_details.outputs.cluster_ca_certificate)
        exec = {
            api_version = "client.authentication.k8s.io/v1beta1"
            command = "aws"
            args = [
                    "eks",
                    "get-token",
                    "--cluster-name",
                    data.terraform_remote_state.Controlplane_details.outputs.cluster_name 
            ]
        }               
    }
}


