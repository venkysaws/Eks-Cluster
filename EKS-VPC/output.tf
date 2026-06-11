output "eks_vpc_id" {
    description = "The ID of the VPC created for EKS cluster"
    value       = aws_vpc.Eks_Proj_vpc.id
}

output "pub_subnet_id" {
    description = "The IDs of the public subnets created for EKS cluster"
    value       = aws_subnet.Eks_Pub_Subnet[*].id
}

output "pri_subnet_id" {
    description = "The IDs of the private subnets created for EKS cluster"
    value       = aws_subnet.Eks_Pri_Subnet[*].id
}

output "intra_subnet_id" {
    description = "The IDs of the intra subnets created for EKS cluster"
    value       = aws_subnet.Eks_Intra_subnet[*].id
}

output "eip_nat" {
    description = "The IDs of the EIP created for NAT Gateway"
    value       = aws_eip.Nat_Gw_EIP[*].id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.Eks_Ngw[*].id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
