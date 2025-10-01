variable "region" {
    description = "aws Region for deploy"
    type = string
    default = "ap-south-2"
}

variable "route53_zone_id" {
     type = string 
}

variable "record_name"    { 
    type = string
 } 
