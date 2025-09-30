variable "name" {
    description = "Base name for resource"
    type = string
}

variable "vpc_id" {
    description ="VPC ID"
    type = string
}

variable "subnet_ids" {
    description = "List of subneet IDs to place ASG into"
    type = list(string)
}

variable "master_subnet_id" {
     description = "Subnet ID for the k3s master node"
     type = string
}

variable "ami_id" {
    description = "AMI ID to use for instances "
    type = string
}

variable "master_instance_type" {
   description = "Instance type for k3s control plane (master node)"
   type = string
   default = "t3.small"
}

variable "worker_instance_type" {
    description = "Instance type for k3s worker nodes (ASG launch template)"
    type = string
    default = "t3.micro"
}

variable "key_name" {
    description = "SSH key pair name"
    type = string
}

variable "k3s_token" {
  description = "pre-shared token for k3s cluster"
  type = string
}

variable "min_size" {
   description = "ASG min size"
   type = number
   default = 1
}

variable "max_size" {
   description = "ASG max size"
   type = number
   default = 3
}

variable "desired_capacity" {
   description = "ASG desired capacity"
   type = number
   default = 1
}

variable "tags" {
    description = "Tags map to add to resource"
    type = map(string)
    default = {}
}
