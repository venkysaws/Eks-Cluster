# eks-cluster/variables.tf

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
  default     = "eks-cluster"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "production-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
  # Use second latest version
  # Not latest (least tested) not oldest (near end of life)
}

variable "cluster_log_types" {
  description = "Control plane log types to send to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  # api               → all requests to API server
  # audit             → who did what in the cluster (compliance)
  # authenticator     → IAM authentication attempts
  # controllerManager → controller loop logs
  # scheduler         → pod scheduling decisions
  # Enable all 5 in production — you need them for troubleshooting
}