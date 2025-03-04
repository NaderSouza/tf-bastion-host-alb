# VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc
  instance_tenancy = "default"
  tags             = { Name = "PrivateBastionVPC" }
}
# INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Terraform-InternetGateway"
  }
}
# SUBNETS
resource "aws_subnet" "bastion" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_ip[0]
  availability_zone       = var.az[0]
  map_public_ip_on_launch = true


  tags = {
    Name = "BastionHostSubnet"
  }
}

resource "aws_subnet" "lb" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_ip[1]
  availability_zone       = var.az[1]
  map_public_ip_on_launch = true


  tags = {
    Name = "LoadBalancer-Subnet"
  }
}

resource "aws_subnet" "nat" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_ip[2]
  availability_zone       = var.az[2]
  map_public_ip_on_launch = true


  tags = {
    Name = "NAT-Subnet"
  }
}

resource "aws_subnet" "web" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_ip[3]
  availability_zone       = var.az[1]
  map_public_ip_on_launch = false


  tags = {
    Name = "App-Subnet"
  }
}

# ELASTIC IP
resource "aws_eip" "eip" {
  # instance = aws_instance.web.id 
  domain = "vpc"
  tags = {
    Name = "terraform-eip"
  }

}
# NAT GATEWAY
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.nat.id

  tags = {
    Name = "Terraform-NatGateway"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.internet
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "PublicRouteTable-Terraform"
  }
}

# PRIVATE ROUTE TABLE
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = var.internet
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "PrivateRouteTable-Terraform"
  }
}

# ROUTE TABLE ASSOCIATION PUBLIC BASTION
resource "aws_route_table_association" "bastion" {
  subnet_id      = aws_subnet.bastion.id
  route_table_id = aws_route_table.public.id
}
# ROUTE TABLE ASSOCIATION NAT GATEWAY
resource "aws_route_table_association" "nat" {
  subnet_id      = aws_subnet.nat.id
  route_table_id = aws_route_table.public.id
}
# ROUTE TABLE ASSOCIATION LOAD BALANCER
resource "aws_route_table_association" "lb" {
  subnet_id      = aws_subnet.lb.id
  route_table_id = aws_route_table.public.id
}

# ROUTE TABLE ASSOCIATION PRIVATE
resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.private.id
}
# ROUTE TABLE ASSOCIATION PRIVATE DB1
resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private.id
}

# ROUTE TABLE ASSOCIATION PRIVATE DB2
resource "aws_route_table_association" "db2" {
  subnet_id      = aws_subnet.db2.id
  route_table_id = aws_route_table.private.id
}

# SECURITY GROUPS BASTION 
resource "aws_security_group" "bastion" {
  name        = "BastionSecurityGroup"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from VPC"
    from_port   = var.ssh
    to_port     = var.ssh
    protocol    = "TCP"
    cidr_blocks = [var.internet]
  }
  egress {
    from_port   = var.ssh
    to_port     = var.ssh
    protocol    = "TCP"
    cidr_blocks = [var.internet]
  }
  tags = {
    Name = "BastionSecurityGroup"
  }
}

# SECURITY GROUPS LOAD BALANCER
resource "aws_security_group" "lb" {
  name        = "LoadBalancerSecurityGroup"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP inbound traffic and security group for Load Balancer"

  ingress {
    description = "HTTP Allow from anywhere"
    from_port   = var.http[0]
    to_port     = var.http[0]
    protocol    = "TCP"
    cidr_blocks = [var.internet]
  }
  ingress {
    description = "HTTP Allow from anywhere"
    from_port   = var.http[1]
    to_port     = var.http[1]
    protocol    = "TCP"
    cidr_blocks = [var.internet]
  }
  egress {
    from_port   = var.web_port
    to_port     = var.web_port
    protocol    = "TCP"
    cidr_blocks = [var.internet]
  }
  tags = {
    Name = "LoadBalancerSecurityGroup"
  }
}

# SECURITY GROUPS WEB
resource "aws_security_group" "web" {
  description = "Allow HTTP inbound traffic and security group for Web"
  name        = "WebSecurityGroup"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP Allow from anywhere"
    from_port       = var.ssh
    to_port         = var.ssh
    protocol        = "TCP"
    security_groups = ["${aws_security_group.bastion.id}"]

  }
  ingress {
    description     = "HTTP Allow from anywhere"
    from_port       = var.web_port
    to_port         = var.web_port
    protocol        = "TCP"
    security_groups = ["${aws_security_group.lb.id}"]
  }
  egress {
    from_port   = var.all
    to_port     = var.all
    protocol    = "-1"
    cidr_blocks = [var.internet]
  }
  tags = {
    Name = "WebSecurityGroup"
  }
}

# SECURITY GROUPS DB
resource "aws_security_group" "db" {
  description = "Allow HTTP inbound traffic and security group for DB"
  name        = "DBSecurityGroup"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP Allow from anywhere"
    from_port       = var.ssh
    to_port         = var.ssh
    protocol        = "TCP"
    security_groups = ["${aws_security_group.web.id}"]
  }
  ingress {
    description     = "HTTP Allow from anywhere"
    from_port       = var.web_port
    to_port         = var.web_port
    protocol        = "TCP"
    security_groups = ["${aws_security_group.web.id}"]
  }
  ingress {
    description     = "Allow incoming TCP from Web"
    from_port       = 3306
    to_port         = 3306
    protocol        = "TCP"
    security_groups = ["${aws_security_group.web.id}"]
  }
  egress {
    description = "Allow all out traffic"
    from_port   = var.all
    to_port     = var.all
    protocol    = "-1"
    cidr_blocks = [var.internet]
  }
  tags = {
    Name = "DBSecurityGroup"
  }
}
