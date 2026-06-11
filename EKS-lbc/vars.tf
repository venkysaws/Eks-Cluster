
# eks-lbc/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "Environment must be production, staging, or dev."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eks"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "production-eks-cluster"
}

variable "lbc_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.1"
  # Always check latest version at:
  # https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller
}