variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
    description = "describe environment"
    type = string
    default = "production"
    validation {
        condition     = contains(["production", "staging", "dev"], var.environment)
        error_message = "Environment must be production, staging, or dev."
    }
}
variable "vpc_cidr"{
    description = "Name of the VPC"
    type = string
    default = "10.0.0.0/16"
}
variable "pub_subnet_cidr_block" {
   description = "Cidr list for pub subnet"
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "priv_subnet_cidr_block" {
   description = "Cidr list for private subnet"
    type = list(string)
    default = ["10.0.5.0/24", "10.0.6.0/24", "10.0.7.0/24"]
}

variable "intra_subnet_cidr_block" {
    description = "Cidr list for int subnet"
     type = list(string)
     default = ["10.0.8.0/24", "10.0.9.0/24", "10.0.10.0/24"]
}

variable "availability_zones" {
    description = "List of availability zones"
    type = list(string)
    default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}