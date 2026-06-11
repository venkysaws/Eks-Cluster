# eks-ca/variables.tf

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

variable "ca_version" {
  description = "Cluster Autoscaler Helm chart version"
  type        = string
  default     = "9.36.0"
  # Chart version must match your Kubernetes version
  # Kubernetes 1.30 → CA chart 9.36.x
  # Always check:
  # https://github.com/kubernetes/autoscaler/releases
}