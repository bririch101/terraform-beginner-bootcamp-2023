############################
# Transit Gateway
#
# Architecture:
#   - One TGW in us-east-1 (home region)
#   - One TGW in us-west-1
#   - Inter-region peering attachment connects the two TGWs
#   - Each VPC (public + private subnets) is attached to its local TGW
#   - Route tables in both VPCs forward cross-region CIDR to the TGW
#
# CIDRs:
#   us-east-1 VPC: 10.0.0.0/16
#   us-west-1 VPC: 10.1.0.0/16
############################

############################
# TGW — us-east-1
############################
resource "aws_ec2_transit_gateway" "use1" {
  provider                        = aws.use1
  description                     = "${var.project_name} TGW us-east-1"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "${var.project_name}-tgw-use1"
    Project = var.project_name
  }
}

# Attach us-east-1 VPC (all subnets) to the TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "use1" {
  provider           = aws.use1
  transit_gateway_id = aws_ec2_transit_gateway.use1.id
  vpc_id             = aws_vpc.use1.id
  subnet_ids         = concat(aws_subnet.use1_public[*].id, aws_subnet.use1_private[*].id)

  tags = {
    Name    = "${var.project_name}-tgw-attach-use1"
    Project = var.project_name
  }
}

############################
# TGW — us-west-1
############################
resource "aws_ec2_transit_gateway" "usw1" {
  provider                        = aws.usw1
  description                     = "${var.project_name} TGW us-west-1"
  amazon_side_asn                 = 64513
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "${var.project_name}-tgw-usw1"
    Project = var.project_name
  }
}

# Attach us-west-1 VPC (all subnets) to the TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "usw1" {
  provider           = aws.usw1
  transit_gateway_id = aws_ec2_transit_gateway.usw1.id
  vpc_id             = aws_vpc.usw1.id
  subnet_ids         = concat(aws_subnet.usw1_public[*].id, aws_subnet.usw1_private[*].id)

  tags = {
    Name    = "${var.project_name}-tgw-attach-usw1"
    Project = var.project_name
  }
}

############################
# TGW Inter-Region Peering
# Initiated from us-east-1, accepted in us-west-1
############################
resource "aws_ec2_transit_gateway_peering_attachment" "use1_to_usw1" {
  provider                = aws.use1
  transit_gateway_id      = aws_ec2_transit_gateway.use1.id
  peer_transit_gateway_id = aws_ec2_transit_gateway.usw1.id
  peer_region             = "us-west-1"

  tags = {
    Name    = "${var.project_name}-tgw-peer-use1-to-usw1"
    Project = var.project_name
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "usw1_accept" {
  provider                      = aws.usw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.use1_to_usw1.id

  tags = {
    Name    = "${var.project_name}-tgw-peer-accept-usw1"
    Project = var.project_name
  }
}

############################
# TGW Route Tables — cross-region static routes
# Each TGW needs a static route pointing the remote CIDR at the peering attachment
############################

# us-east-1 TGW default route table: send 10.1.0.0/16 (usw1) via peering
resource "aws_ec2_transit_gateway_route" "use1_to_usw1" {
  provider                       = aws.use1
  transit_gateway_route_table_id = aws_ec2_transit_gateway.use1.association_default_route_table_id
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.use1_to_usw1.id
}

# us-west-1 TGW default route table: send 10.0.0.0/16 (use1) via peering
resource "aws_ec2_transit_gateway_route" "usw1_to_use1" {
  provider                       = aws.usw1
  transit_gateway_route_table_id = aws_ec2_transit_gateway.usw1.association_default_route_table_id
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw1_accept.id
}

############################
# VPC Route Table Updates
# Add TGW as next-hop for the remote VPC CIDR in each VPC's route tables
############################

# us-east-1 public route table → remote VPC via TGW
resource "aws_route" "use1_public_to_usw1" {
  provider               = aws.use1
  route_table_id         = aws_route_table.use1_public.id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.use1.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.use1]
}

# us-east-1 private route tables → remote VPC via TGW
resource "aws_route" "use1_private_to_usw1" {
  count                  = 2
  provider               = aws.use1
  route_table_id         = aws_route_table.use1_private[count.index].id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.use1.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.use1]
}

# us-west-1 public route table → remote VPC via TGW
resource "aws_route" "usw1_public_to_use1" {
  provider               = aws.usw1
  route_table_id         = aws_route_table.usw1_public.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.usw1.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.usw1]
}

# us-west-1 private route tables → remote VPC via TGW
resource "aws_route" "usw1_private_to_use1" {
  count                  = 2
  provider               = aws.usw1
  route_table_id         = aws_route_table.usw1_private[count.index].id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.usw1.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.usw1]
}

############################
# Security Group Rules — allow cross-region traffic via TGW
############################

# Allow all traffic from usw1 VPC CIDR into use1 public instances
resource "aws_vpc_security_group_ingress_rule" "use1_public_from_usw1" {
  provider          = aws.use1
  security_group_id = aws_security_group.use1_public.id
  cidr_ipv4         = "10.1.0.0/16"
  ip_protocol       = "-1"
  description       = "All traffic from usw1 VPC via TGW"
}

# Allow all traffic from usw1 VPC CIDR into use1 private instances
resource "aws_vpc_security_group_ingress_rule" "use1_private_from_usw1" {
  provider          = aws.use1
  security_group_id = aws_security_group.use1_private.id
  cidr_ipv4         = "10.1.0.0/16"
  ip_protocol       = "-1"
  description       = "All traffic from usw1 VPC via TGW"
}

# Allow all traffic from use1 VPC CIDR into usw1 public instances
resource "aws_vpc_security_group_ingress_rule" "usw1_public_from_use1" {
  provider          = aws.usw1
  security_group_id = aws_security_group.usw1_public.id
  cidr_ipv4         = "10.0.0.0/16"
  ip_protocol       = "-1"
  description       = "All traffic from use1 VPC via TGW"
}

# Allow all traffic from use1 VPC CIDR into usw1 private instances
resource "aws_vpc_security_group_ingress_rule" "usw1_private_from_use1" {
  provider          = aws.usw1
  security_group_id = aws_security_group.usw1_private.id
  cidr_ipv4         = "10.0.0.0/16"
  ip_protocol       = "-1"
  description       = "All traffic from use1 VPC via TGW"
}
