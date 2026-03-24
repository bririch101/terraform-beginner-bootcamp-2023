############################
# us-west-1 — VPC
############################
resource "aws_vpc" "usw1" {
  provider             = aws.usw1
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "${var.project_name}-vpc-usw1"
    Project = var.project_name
    Region  = "us-west-1"
  }
}

############################
# us-west-1 — Subnets
############################
data "aws_availability_zones" "usw1" {
  provider = aws.usw1
  state    = "available"
}

# us-west-1 only has 2 AZs; use both
resource "aws_subnet" "usw1_public" {
  count                   = 2
  provider                = aws.usw1
  vpc_id                  = aws_vpc.usw1.id
  cidr_block              = cidrsubnet(aws_vpc.usw1.cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.usw1.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name    = "${var.project_name}-public-usw1-${count.index}"
    Tier    = "public"
    Project = var.project_name
  }
}

resource "aws_subnet" "usw1_private" {
  count             = 2
  provider          = aws.usw1
  vpc_id            = aws_vpc.usw1.id
  cidr_block        = cidrsubnet(aws_vpc.usw1.cidr_block, 4, 8 + count.index)
  availability_zone = data.aws_availability_zones.usw1.names[count.index]
  tags = {
    Name    = "${var.project_name}-private-usw1-${count.index}"
    Tier    = "private"
    Project = var.project_name
  }
}

############################
# us-west-1 — Internet Gateway & Public Routing
############################
resource "aws_internet_gateway" "usw1" {
  provider = aws.usw1
  vpc_id   = aws_vpc.usw1.id
  tags = {
    Name    = "${var.project_name}-igw-usw1"
    Project = var.project_name
  }
}

resource "aws_route_table" "usw1_public" {
  provider = aws.usw1
  vpc_id   = aws_vpc.usw1.id
  tags = {
    Name    = "${var.project_name}-public-rt-usw1"
    Project = var.project_name
  }
}

resource "aws_route" "usw1_public_inet" {
  provider               = aws.usw1
  route_table_id         = aws_route_table.usw1_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.usw1.id
}

resource "aws_route_table_association" "usw1_public" {
  count          = 2
  provider       = aws.usw1
  subnet_id      = aws_subnet.usw1_public[count.index].id
  route_table_id = aws_route_table.usw1_public.id
}

############################
# us-west-1 — NAT Gateway & Private Routing
############################
resource "aws_eip" "usw1_nat" {
  provider   = aws.usw1
  domain     = "vpc"
  depends_on = [aws_internet_gateway.usw1]
  tags = {
    Name    = "${var.project_name}-nat-eip-usw1"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "usw1" {
  provider      = aws.usw1
  allocation_id = aws_eip.usw1_nat.id
  subnet_id     = aws_subnet.usw1_public[0].id
  depends_on    = [aws_internet_gateway.usw1]
  tags = {
    Name    = "${var.project_name}-ngw-usw1"
    Project = var.project_name
  }
}

resource "aws_route_table" "usw1_private" {
  count    = 2
  provider = aws.usw1
  vpc_id   = aws_vpc.usw1.id
  tags = {
    Name    = "${var.project_name}-private-rt-usw1-${count.index}"
    Project = var.project_name
  }
}

resource "aws_route" "usw1_private_nat" {
  count                  = 2
  provider               = aws.usw1
  route_table_id         = aws_route_table.usw1_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.usw1.id
}

resource "aws_route_table_association" "usw1_private" {
  count          = 2
  provider       = aws.usw1
  subnet_id      = aws_subnet.usw1_private[count.index].id
  route_table_id = aws_route_table.usw1_private[count.index].id
}

############################
# us-west-1 — Security Groups
############################
resource "aws_security_group" "usw1_public" {
  provider    = aws.usw1
  name        = "${var.project_name}-public-sg-usw1"
  description = "SSH and RDP from allowed IP only"
  vpc_id      = aws_vpc.usw1.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-public-sg-usw1"
    Project = var.project_name
  }
}

resource "aws_security_group" "usw1_private" {
  provider    = aws.usw1
  name        = "${var.project_name}-private-sg-usw1"
  description = "No inbound; egress only (SSM via NAT)"
  vpc_id      = aws_vpc.usw1.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-private-sg-usw1"
    Project = var.project_name
  }
}

############################
# us-west-1 — AMI (Ubuntu 22.04 LTS)
############################
data "aws_ami" "usw1_ubuntu" {
  provider    = aws.usw1
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################
# us-west-1 — EC2 Instances
############################

# Public instance — t3.xlarge for Ubuntu Desktop
resource "aws_instance" "usw1_public" {
  provider                    = aws.usw1
  ami                         = data.aws_ami.usw1_ubuntu.id
  instance_type               = "t3.xlarge"
  subnet_id                   = aws_subnet.usw1_public[0].id
  vpc_security_group_ids      = [aws_security_group.usw1_public.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.usw1.key_name
  user_data                   = local.public_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-public-usw1"
    Tier        = "public"
    Project     = var.project_name
    Environment = "dev"
  }
}

# Private instance — SSM access, no public IP
resource "aws_instance" "usw1_private" {
  provider               = aws.usw1
  ami                    = data.aws_ami.usw1_ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.usw1_private[0].id
  vpc_security_group_ids = [aws_security_group.usw1_private.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-private-usw1"
    Tier        = "private"
    Project     = var.project_name
    Environment = "dev"
  }
}
