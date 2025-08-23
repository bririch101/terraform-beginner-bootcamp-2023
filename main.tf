terraform {
  backend "remote" {
    organization = "Brian-TF-Gitpod"

    workspaces {
      name = "Brian-TF-Git-space"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

