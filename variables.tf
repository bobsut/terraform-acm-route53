variable "domain" {
  default     = "example.com"
  description = "Top-Level Domain"
  type        = string
}

variable "subdomain" {
  default     = "demo"
  description = "Subdomain"
  type        = string
}

variable "region" {
  default     = "us-west-2"
  description = "AWS Region"
  type        = string
  validation {
    condition = contains(
      # aws ec2 describe-regions --query "Regions[].RegionName|sort(@)"
      [
        "af-south-1",
        "ap-east-1",
        "ap-northeast-1",
        "ap-northeast-2",
        "ap-northeast-3",
        "ap-south-1",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-southeast-3",
        "ca-central-1",
        "eu-central-1",
        "eu-central-2",
        "eu-north-1",
        "eu-south-1",
        "eu-west-1",
        "eu-west-2",
        "eu-west-3",
        "me-central-1",
        "me-south-1",
        "sa-east-1",
        "us-east-1",
        "us-east-2",
        "us-west-1",
        "us-west-2"
      ]
    , var.region)
    error_message = "You can't deploy in region ${var.region}."
  }
}
