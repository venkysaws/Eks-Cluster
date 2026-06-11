terraform {
    required_version  = "~>1.6.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"}
    }


    backend "s3" {
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/controlplane.tfstate"
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

