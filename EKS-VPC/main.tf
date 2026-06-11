resource "aws_vpc" "Eks_Proj_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true 
    tags = {
        Name        = "prod-eks-vpc"
        Environment = "production"
        Project     = "eks"
    }
}

resource "aws_internet_gateway" "Eks_Igw" {
  vpc_id = aws_vpc.Eks_Proj_vpc.id
  tags = {
    Name        = "prod-eks-igw"
    Environment = "production"
    Project = "eks"
  }
}

resource "aws_subnet" "Eks_Pub_Subnet" {
    count = length(var.pub_subnet_cidr_block)
    availability_zone = var.availability_zones[count.index]
    cidr_block = var.pub_subnet_cidr_block[count.index]
    map_public_ip_on_launch = true
    vpc_id = aws_vpc.Eks_Proj_vpc.id
    tags = {
        Name        = "prod-eks-pub-subnet-${count.index}"
        Environment = "production"
        Project     = "eks"
        "kubernetes.io/role/elb" = "1"
        "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    }
}

resource "aws_subnet" "Eks_Pri_Subnet" {
    count = length(var.priv_subnet_cidr_block)
    availability_zone = var.availability_zones[count.index]
    cidr_block = var.priv_subnet_cidr_block[count.index]
    vpc_id = aws_vpc.Eks_Proj_vpc.id
    tags = {
        Name        = "prod-eks-pri-subnet-${count.index}"
        Environment = "production"
        Project     = "eks"
        "kubernetes.io/role/internal-elb" = "1"
        "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    }
}

resource "aws_subnet" "Eks_Intra_subnet" {
    count = length(var.intra_subnet_cidr_block)
    availability_zone = var.availability_zones[count.index]
    cidr_block = var.intra_subnet_cidr_block[count.index]
    vpc_id = aws_vpc.Eks_Proj_vpc.id
    map_public_ip_on_launch = false
}

resource "aws_eip" "Eks_Proj_natIP" {
    count = length(var.pub_subnet_cidr_block)
    domain = vpc
    tags = {
    Name        = "prod-eks-nat-eip-${count.index}"
    Environment = "production"
    Project     = "eks"
    }
}

resource "aws_nat_gateway" "Eks_Ngw" {
    count = length(var.pub_subnet_cidr_block)
    allocation_id = aws_eip.Eks_Proj_natIP[count.index].id
    subnet_id = aws_subnet.Eks_Pub_Subnet[count.index].id
    tags = {
        Name        = "prod-eks-ngw-${count.index}"
        Environment = "production"
        Project     = "eks"
    }   
}

resource "aws_route_table" "public_route_Table" {
    vpc_id = aws_vpc.Eks_Proj_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.Eks_Igw.id
    }
    route {
        cidr_block = "10.1.0.0/16"
        gateway_id = "local"
    }
    tags = {
        Name        = "prod-eks-public-route-table"
        Environment = "production"
        Project     = "eks"
    }
}

resource "aws_route_table" "private_Route_Table" {
    count = length(var.priv_subnet_cidr_block)
    vpc_id = aws_vpc.Eks_Proj_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.Eks_Ngw[count.index].id
    }
    tags = {
        Name        = "prod-eks-private-route-table-${count.index}"
        Environment = "production"
        Project     = "eks"
    }
}

resource "aws_route_table" "Intra_route_table" {
    vpc_id = aws_vpc.Eks_Proj_vpc.id
  # Intentionally NO routes added here
  # AWS automatically adds the local VPC route:
  # Destination: 10.0.0.0/16 → Target: local
  # That is the only route intra subnets need
    tags = {
        Name        = "prod-eks-intra-route-table"
        Environment = "production"
        Project     = "eks"
    }
}

resource "aws_route_table_association" "Public_Association" {
    count = length(var.pub_subnet_cidr_block)
    subnet_id = aws_subnet.Eks_Pub_Subnet[count.index].id
    route_table_id = aws_route_table.public_route_Table.id
}

resource "aws_route_table_association" "private_association" {
  count = length(var.priv_subnet_cidr_block)
  subnet_id      = aws_subnet.Eks_Pri_Subnet[count.index].id
  route_table_id = aws_route_table.private_Route_Table[count.index].id
}

resource "aws_route_table_association" "intra_association" {
  count = length(var.intra_subnet_cidr_block)
  subnet_id      = aws_subnet.Eks_Intra_subnet[count.index].id
  route_table_id = aws_route_table.Intra_route_table.id
}








