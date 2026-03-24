# Configuration has been split into focused files:
#   providers.tf  — terraform block, provider aliases
#   variables.tf  — variables and locals (user_data)
#   keys.tf       — TLS key pair, AWS key pairs, IAM SSM role
#   use1.tf       — us-east-1 VPC, subnets, IGW, NAT, SGs, AMI, EC2
#   usw1.tf       — us-west-1 VPC, subnets, IGW, NAT, SGs, AMI, EC2
#   alb.tf        — Application Load Balancer in us-east-1
#   tgw.tf        — Transit Gateway, peering, VPC route table updates
#   outputs.tf    — all outputs
