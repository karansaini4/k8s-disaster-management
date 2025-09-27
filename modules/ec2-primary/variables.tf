variable "vpc_id" {
    description = "VPC ID where EC2 gonna deploy"
    type = string
}

variable "subnet_id" {
    description = "Subnet ID for the EC2 instance"
    type = string
}

variable "instance_type" {
    description = "EC2 instance type for primary website"
    type = string
    default = "t3.medium"
}

variable "ami_id"{
    description = "AMI ID for the EC2 instance"
    type = string
}

variable "key_name" {
    description = "SSH key pair name"
    type = string
}

variable "tags" {
    description = "Tags to apply to resources"
    type = map(string)
    default = {}
}