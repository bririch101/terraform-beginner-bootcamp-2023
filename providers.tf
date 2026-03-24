############################
# Terraform & Providers
############################
terraform {
  backend "remote" {
    organization = "Brian-TF-Gitpod"
    workspaces {
      name = "Brian-TF-Git-space"
    }
  }

  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}
