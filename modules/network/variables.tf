variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
}

variable "public_subnet_cidrs" {
    description = "List of public subnet CIDR blocks"
    type = list(string)
}

variable "enable_public_ip" {
  description = "Whether to auto-assign public IPs on launch in public subnets"
  type = bool
  default = true
}

variable "tags" {
    description = "A map of tags to add to resources"
    type = map(string)
    default = {}
}

