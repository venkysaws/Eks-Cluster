# eks-monitoring/variables.tf

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

variable "monitoring_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "56.6.2"
  # Check latest at:
  # https://github.com/prometheus-community/helm-charts
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  # sensitive = true means:
  # Terraform will not print this in logs or plan output
  # Pass via environment variable:
  # export TF_VAR_grafana_admin_password="your-password"
  # Never hardcode passwords in Terraform files
}

variable "prometheus_retention_days" {
  description = "How many days to keep metrics"
  type        = number
  default     = 15
  # 15 days is good balance between
  # storage cost and historical data
  # For compliance requirements increase to 30-90 days
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus data"
  type        = string
  default     = "50Gi"
  # 50GB for 15 days of metrics
  # Increase if you have many pods or longer retention
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "10Gi"
  # Grafana stores dashboards and settings
  # 10GB is more than enough
}