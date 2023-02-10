terraform {
  required_version = "~> 1.3, >= 1.3.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0, >= 4.54"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.0, >= 3.2.4"
    }
  }
}

provider "aws" {
  alias      = "acct1"
  region     = var.region
  access_key = var.access_key.acct1
  secret_key = var.secret_key.acct1
}

provider "aws" {
  alias      = "acct2"
  region     = var.region
  access_key = var.access_key.acct2
  secret_key = var.secret_key.acct2
}
