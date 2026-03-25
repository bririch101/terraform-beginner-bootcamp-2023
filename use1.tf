############################
# us-east-1 — VPC
############################
resource "aws_vpc" "use1" {
  provider             = aws.use1
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "${var.project_name}-vpc-use1"
    Project = var.project_name
    Region  = "us-east-1"
  }
}

############################
# us-east-1 — Subnets
############################
data "aws_availability_zones" "use1" {
  provider = aws.use1
  state    = "available"
}

# Public subnet — single AZ is enough for one public instance; use two for ALB requirement
resource "aws_subnet" "use1_public" {
  count                   = 2
  provider                = aws.use1
  vpc_id                  = aws_vpc.use1.id
  cidr_block              = cidrsubnet(aws_vpc.use1.cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.use1.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name    = "${var.project_name}-public-use1-${count.index}"
    Tier    = "public"
    Project = var.project_name
  }
}

# Private subnet
resource "aws_subnet" "use1_private" {
  count             = 2
  provider          = aws.use1
  vpc_id            = aws_vpc.use1.id
  cidr_block        = cidrsubnet(aws_vpc.use1.cidr_block, 4, 8 + count.index)
  availability_zone = data.aws_availability_zones.use1.names[count.index]
  tags = {
    Name    = "${var.project_name}-private-use1-${count.index}"
    Tier    = "private"
    Project = var.project_name
  }
}

############################
# us-east-1 — Internet Gateway & Public Routing
############################
resource "aws_internet_gateway" "use1" {
  provider = aws.use1
  vpc_id   = aws_vpc.use1.id
  tags = {
    Name    = "${var.project_name}-igw-use1"
    Project = var.project_name
  }
}

resource "aws_route_table" "use1_public" {
  provider = aws.use1
  vpc_id   = aws_vpc.use1.id
  tags = {
    Name    = "${var.project_name}-public-rt-use1"
    Project = var.project_name
  }
}

resource "aws_route" "use1_public_inet" {
  provider               = aws.use1
  route_table_id         = aws_route_table.use1_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.use1.id
}

resource "aws_route_table_association" "use1_public" {
  count          = 2
  provider       = aws.use1
  subnet_id      = aws_subnet.use1_public[count.index].id
  route_table_id = aws_route_table.use1_public.id
}

############################
# us-east-1 — NAT Gateway & Private Routing
############################
resource "aws_eip" "use1_nat" {
  provider   = aws.use1
  domain     = "vpc"
  depends_on = [aws_internet_gateway.use1]
  tags = {
    Name    = "${var.project_name}-nat-eip-use1"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "use1" {
  provider      = aws.use1
  allocation_id = aws_eip.use1_nat.id
  subnet_id     = aws_subnet.use1_public[0].id
  depends_on    = [aws_internet_gateway.use1]
  tags = {
    Name    = "${var.project_name}-ngw-use1"
    Project = var.project_name
  }
}

resource "aws_route_table" "use1_private" {
  count    = 2
  provider = aws.use1
  vpc_id   = aws_vpc.use1.id
  tags = {
    Name    = "${var.project_name}-private-rt-use1-${count.index}"
    Project = var.project_name
  }
}

resource "aws_route" "use1_private_nat" {
  count                  = 2
  provider               = aws.use1
  route_table_id         = aws_route_table.use1_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.use1.id
}

resource "aws_route_table_association" "use1_private" {
  count          = 2
  provider       = aws.use1
  subnet_id      = aws_subnet.use1_private[count.index].id
  route_table_id = aws_route_table.use1_private[count.index].id
}

############################
# us-east-1 — Security Groups
############################
resource "aws_security_group" "use1_public" {
  provider    = aws.use1
  name        = "${var.project_name}-public-sg-use1"
  description = "SSH from allowed IP only"
  vpc_id      = aws_vpc.use1.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name    = "${var.project_name}-public-sg-use1"
    Project = var.project_name
  }
}

resource "aws_security_group" "use1_private" {
  provider    = aws.use1
  name        = "${var.project_name}-private-sg-use1"
  description = "No inbound; egress only (SSM via NAT)"
  vpc_id      = aws_vpc.use1.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-private-sg-use1"
    Project = var.project_name
  }
}

############################
# us-east-1 — AMI (Ubuntu 22.04 LTS)
############################
data "aws_ami" "use1_ubuntu" {
  provider    = aws.use1
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
# us-east-1 — EC2 Instances
############################

# Public instances — two, one per AZ
resource "aws_instance" "use1_public" {
  count                       = 2
  provider                    = aws.use1
  ami                         = data.aws_ami.use1_ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.use1_public[count.index].id
  vpc_security_group_ids      = [aws_security_group.use1_public.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.use1.key_name
  user_data                   = local.public_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-public-use1-${count.index}"
    Tier        = "public"
    Project     = var.project_name
    Environment = "dev"
  }
}

# Private instances — two, one per AZ, SSM access only
resource "aws_instance" "use1_private" {
  count                       = 2
  provider                    = aws.use1
  ami                         = data.aws_ami.use1_ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.use1_private[count.index].id
  vpc_security_group_ids      = [aws_security_group.use1_private.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-private-use1-${count.index}"
    Tier        = "private"
    Project     = var.project_name
    Environment = "dev"
  }
}
