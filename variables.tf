variable "domain" {
  default     = "example.com"
  description = "Top-Level Domain"
  type        = string
}

variable "subdomain1" {
  default     = "demo"
  description = "Subdomain 1"
  type        = string
}

variable "subdomain2" {
  default     = "omed"
  description = "Subdomain 2"
  type        = string
}

data "aws_regions" "all" {
  all_regions = true
  filter {
    name   = "opt-in-status"
    values = ["opted-in", "opt-in-not-required"]
  }
}

variable "region" {
  default     = "us-west-2"
  description = "AWS Region"
  type        = string
  validation {
    condition = contains(
      # we can't use derived value in condition
      # data.aws_regions.all.names
      #
      # instead we use cli output
      # aws ec2 describe-regions --all-regions --output json \
      # --filter Name="opt-in-status",Values="opted-in","opt-in-not-required" \
      # --query "Regions[].RegionName|sort(@)" | jq --compact-output
      ["af-south-1", "ap-east-1", "ap-northeast-1", "ap-northeast-2", "ap-northeast-3", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ap-southeast-3", "ca-central-1", "eu-central-1", "eu-central-2", "eu-north-1", "eu-south-1", "eu-west-1", "eu-west-2", "eu-west-3", "me-central-1", "me-south-1", "sa-east-1", "us-east-1", "us-east-2", "us-west-1", "us-west-2"]
    , var.region)
    error_message = "You can't deploy in region ${var.region}."
  }
}

variable "access_key" {
  type = map(string)
  default = {
    acct1 = null
    acct2 = null
  }
}

variable "secret_key" {
  type = map(string)
  default = {
    acct1 = null
    acct2 = null
  }
}
