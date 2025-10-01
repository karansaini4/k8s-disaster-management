resource "aws_route53_health_check" "primary" {
  ip_address        = var.primary_ip
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = var.request_interval
  failure_threshold = var.failure_threshold

  tags = merge(var.tags, { Name = "${var.record_name}-primary-hc" })
}

resource "aws_route53_record" "primary" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  ttl     = var.ttl
  records = [var.primary_ip]

  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "secondary" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "A"

  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  ttl     = var.ttl
  records = [var.dr_ip]
}
