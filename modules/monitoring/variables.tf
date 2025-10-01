variable "zone_id" {
  description = "Route53 hosted zone id (e.g. Z123...)"
  type = string
}

variable "record_name" {
  description = "Fully-qualified DNS name to create (e.g. app.example.com)"
  type = string
}

variable "primary_ip" {
  description = "Public IP address of the primary EC2"
  type= string
}

variable "dr_ip" {
  description = "Public IP address to fail over to (DR kube node public IP)"
  type = string
}

variable "ttl" {
  description = "DNS TTL for the record"
  type = number
  default = 60
}

variable "health_check_port" {
  description = "Port Route53 should check on the primary (usually 80)"
  type= number
  default = 80
}

variable "health_check_path" {
  description = "HTTP path used by the health check (must exist on primary)"
  type = string
  default = "/"
}

variable "request_interval" {
  description = "Health check request interval (seconds)"
  type= number
  default = 30
}

variable "failure_threshold" {
  description = "Failure threshold for the health check"
  type = number
  default = 3
}

variable "tags" {
  description = "Optional tags for resources"
  type = map(string)
  default= {}
}
