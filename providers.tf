terraform {
  required_version = "~> 1.3, >= 1.3.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0, >= 4.48"
    }
  }
}

provider "aws" {
  region = var.region
}
