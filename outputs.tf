############################
# Outputs
############################

# SSH private key — retrieve with: terraform output -raw private_key_pem
output "private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "vpc_id" {
  value = aws_vpc.use1.id
}

output "public_instance_ids" {
  value = [for i in aws_instance.use1_public : i.id]
}

output "public_instance_ips" {
  value = [for i in aws_instance.use1_public : i.public_ip]
}

output "private_instance_ids" {
  value = [for i in aws_instance.use1_private : i.id]
}
