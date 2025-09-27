output "instance_id" {
    description = "ID of the primary EC2 instance"
    value = aws_instance.primary.id
}

output "public_ip" {
    description = "Public IP of the primary EC2 instance"
    value = aws_instance.primary.public_ip
}

output "public_dns" {
    description = "Public DNS of the ec2 instance"
    value = aws_instance.primary.public_dns
}

output "security_group_id"{
    description = "Security group ID of primary EC2"
    value = aws_security_group.primary_sg.id
}