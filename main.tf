resource "aws_route53_zone" "zone" {
  name          = var.domain
  force_destroy = true
}

resource "aws_route53_record" "hello" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 60
  records = [
    "hello from ${aws_route53_zone.zone.name}"
  ]
  allow_overwrite = true
}

resource "aws_route53_zone" "subzone" {
  name          = join(".", [var.subdomain, var.domain])
  force_destroy = true
}

resource "aws_route53_record" "glue" {
  zone_id         = aws_route53_zone.zone.zone_id
  name            = aws_route53_zone.subzone.name
  type            = "NS"
  ttl             = 900
  records         = aws_route53_zone.subzone.name_servers
  allow_overwrite = true
}

resource "aws_route53_record" "subhello" {
  zone_id = aws_route53_zone.subzone.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 60
  records = [
    "hello from ${aws_route53_zone.subzone.name}"
  ]
  allow_overwrite = true
}

module "stardotfqdn" {
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 4, >= 4.3"
  domain_name = aws_route53_zone.zone.name
  subject_alternative_names = [
    join(".", ["*", aws_route53_zone.zone.name]),
    # join(".", ["*", aws_route53_zone.subzone.name])
  ]
  zone_id = aws_route53_zone.zone.zone_id
  depends_on = [
    aws_route53_zone.zone,
    aws_route53_zone.subzone
  ]
  wait_for_validation = true
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "subnets" {
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
  name   = "demo-${aws_route53_zone.zone.name}"
  vpc_id = data.aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
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
  name            = replace(var.domain, ".", "-")
  subnets         = data.aws_subnets.subnets.ids
  security_groups = [aws_security_group.demo.id]
  # ip_address_type = "dualstack"
}

resource "aws_lb_listener" "lb_listener" {
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
  zone_id = aws_route53_zone.zone.zone_id
  name    = ""
  type    = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "lb6" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = ""
  type    = "AAAA"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "sub-lb4" {
  zone_id = aws_route53_zone.subzone.zone_id
  name    = ""
  type    = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}

resource "aws_route53_record" "sub-lb6" {
  zone_id = aws_route53_zone.subzone.zone_id
  name    = ""
  type    = "AAAA"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  allow_overwrite = true
}
