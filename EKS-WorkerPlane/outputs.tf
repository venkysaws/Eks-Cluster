# eks-nodegroup/outputs.tf

output "system_node_group_name" {
  description = "Name of the system node group"
  value       = aws_eks_node_group.system.node_group_name
}

output "application_node_group_name" {
  description = "Name of the application node group"
  value       = aws_eks_node_group.app_node_group.node_group_name
}

output "system_node_group_status" {
  description = "Status of system node group"
  value       = aws_eks_node_group.system.status
}

output "application_node_group_status" {
  description = "Status of application node group"
  value       = aws_eks_node_group.application.status
}