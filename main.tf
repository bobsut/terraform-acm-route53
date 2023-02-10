# DS for all HZs in main account
resource "aws_route53_delegation_set" "ds1" {
  provider       = aws.acct1
  reference_name = "acct1"
}

data "dns_a_record_set" "ds1" {
  count = length(aws_route53_delegation_set.ds1.name_servers)
  host  = aws_route53_delegation_set.ds1.name_servers[count.index]
}

data "dns_aaaa_record_set" "ds1" {
  count = length(aws_route53_delegation_set.ds1.name_servers)
  host  = aws_route53_delegation_set.ds1.name_servers[count.index]
}

# HZ for TLD in main account
resource "aws_route53_zone" "zone" {
  provider          = aws.acct1
  delegation_set_id = aws_route53_delegation_set.ds1.id
  name              = var.domain
  comment           = var.domain
  force_destroy     = true
}

resource "aws_route53_record" "hello" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.zone.zone_id
  name     = ""
  type     = "TXT"
  ttl      = 60
  records = [
    "hello from ${aws_route53_zone.zone.name}"
  ]
  allow_overwrite = true
}

resource "aws_route53_record" "ds1_ns" {
  count    = length(aws_route53_delegation_set.ds1.name_servers)
  provider = aws.acct1
  zone_id  = aws_route53_zone.zone.zone_id
  name     = join("", ["NS", count.index])
  type     = "NS"
  ttl      = 60
  records = [
    aws_route53_delegation_set.ds1.name_servers[count.index]
  ]
  allow_overwrite = true
}

# HZ for subdomain1 in main account
resource "aws_route53_zone" "subzone1" {
  provider          = aws.acct1
  delegation_set_id = aws_route53_delegation_set.ds1.id
  name              = join(".", [var.subdomain1, var.domain])
  comment           = join(".", [var.subdomain1, var.domain])
  force_destroy     = true
}

resource "aws_route53_record" "glue1" {
  provider        = aws.acct1
  zone_id         = aws_route53_zone.zone.zone_id
  name            = aws_route53_zone.subzone1.name
  type            = "NS"
  ttl             = 60
  records         = aws_route53_delegation_set.ds1.name_servers
  allow_overwrite = true
}

resource "aws_route53_record" "subhello1" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.subzone1.zone_id
  name     = ""
  type     = "TXT"
  ttl      = 60
  records = [
    "hello from ${aws_route53_zone.subzone1.name}"
  ]
  allow_overwrite = true
}

# DS for all HZs in secondary account
resource "aws_route53_delegation_set" "ds2" {
  provider       = aws.acct2
  reference_name = "acct2"
}

# HZ for subdomain2 in secondary account
resource "aws_route53_zone" "subzone2" {
  provider          = aws.acct2
  delegation_set_id = aws_route53_delegation_set.ds2.id
  name              = join(".", [var.subdomain2, var.domain])
  comment           = join(".", [var.subdomain2, var.domain])
  force_destroy     = true
}

data "dns_ns_record_set" "ds2" {
  host = join(".", [var.subdomain2, var.domain])
}

data "dns_a_record_set" "ds2" {
  count = length(data.dns_ns_record_set.ds2.nameservers)
  host  = data.dns_ns_record_set.ds2.nameservers[count.index]
}

data "dns_aaaa_record_set" "ds2" {
  count = length(data.dns_ns_record_set.ds2.nameservers)
  host  = data.dns_ns_record_set.ds2.nameservers[count.index]
}

resource "aws_route53_record" "glue2" {
  provider        = aws.acct1
  zone_id         = aws_route53_zone.zone.zone_id
  name            = aws_route53_zone.subzone2.name
  type            = "NS"
  ttl             = 60
  records         = data.dns_ns_record_set.ds2.nameservers
  allow_overwrite = true
}

#
# unrelated demo stuff
# 

module "stardotfqdn" {
  providers = {
    aws = aws.acct1
  }
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 4, >= 4.3.2"
  domain_name = aws_route53_zone.zone.name
  subject_alternative_names = [
    join(".", ["*", aws_route53_zone.zone.name]),
    # join(".", ["*", aws_route53_zone.subzone.name])
  ]
  zone_id = aws_route53_zone.zone.zone_id
  depends_on = [
    aws_route53_zone.zone,
    # aws_route53_zone.subzone
  ]
  wait_for_validation = true
}

data "aws_vpc" "default" {
  provider = aws.acct1
  default  = true
}

data "aws_subnets" "subnets" {
  provider = aws.acct1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "demo" {
  provider = aws.acct1
  name     = "demo-${aws_route53_zone.zone.name}"
  vpc_id   = data.aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
  provider          = aws.acct1
  description       = "TLS from everywhere"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.demo.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_lb" "lb" {
  provider        = aws.acct1
  name            = replace(var.domain, ".", "-")
  subnets         = data.aws_subnets.subnets.ids
  security_groups = [aws_security_group.demo.id]
  # ip_address_type = "dualstack"
}

resource "aws_lb_listener" "lb_listener" {
  provider          = aws.acct1
  load_balancer_arn = aws_lb.lb.arn
  certificate_arn   = module.stardotfqdn.acm_certificate_arn
  port              = "443"
  protocol          = "HTTPS"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "hello from ${aws_route53_zone.zone.name}"
      status_code  = "200"
    }
  }
}

resource "aws_route53_record" "lb4" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.zone.zone_id
  name     = ""
  type     = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "lb6" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.zone.zone_id
  name     = ""
  type     = "AAAA"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "sub-lb4" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.subzone1.zone_id
  name     = ""
  type     = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "sub-lb6" {
  provider = aws.acct1
  zone_id  = aws_route53_zone.subzone2.zone_id
  name     = ""
  type     = "AAAA"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}
