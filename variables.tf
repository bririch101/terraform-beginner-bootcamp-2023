############################
# Variables & Locals
############################
variable "project_name" {
  type    = string
  default = "gitpod-vpc-demo"
}

# SSH and RDP access restricted to this IP only
variable "allowed_cidr" {
  type    = string
  default = "96.224.240.155/32"
}

locals {
  # User data runs on first boot of every public instance
  public_user_data = <<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y unattended-upgrades
    dpkg-reconfigure --priority=low unattended-upgrades
    apt-get install -y ubuntu-desktop
  EOF
}
