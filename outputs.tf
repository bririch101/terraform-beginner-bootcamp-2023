############################
# Outputs
############################

# SSH private key — sensitive, retrieve with: terraform output -raw private_key_pem
output "private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

# us-east-1
output "use1_vpc_id" {
  value = aws_vpc.use1.id
}

output "use1_public_instance_id" {
  value = aws_instance.use1_public.id
}

output "use1_public_instance_ip" {
  value = aws_instance.use1_public.public_ip
}

output "use1_private_instance_id" {
  value = aws_instance.use1_private.id
}

output "alb_dns_name" {
  description = "DNS name of the us-east-1 Application Load Balancer"
  value       = aws_lb.use1.dns_name
}

# us-west-1
output "usw1_vpc_id" {
  value = aws_vpc.usw1.id
}

output "usw1_public_instance_id" {
  value = aws_instance.usw1_public.id
}

output "usw1_public_instance_ip" {
  value = aws_instance.usw1_public.public_ip
}

output "usw1_private_instance_id" {
  value = aws_instance.usw1_private.id
}

# Transit Gateway IDs
output "tgw_use1_id" {
  value = aws_ec2_transit_gateway.use1.id
}

output "tgw_usw1_id" {
  value = aws_ec2_transit_gateway.usw1.id
}
