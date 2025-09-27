resource "aws_security_group" "primary_sg" {
    name = "primary-ec2-sg"
    description = "Allow HTTP and SSH traffic"
    vpc_id = var.vpc_id

    tags = {
    Name = "primary_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "primary_sg_ssh" {
    security_group_id = aws_security_group.primary_sg.id
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr_ipv4 = "0.0.0.0/0"
    
}

resource "aws_vpc_security_group_ingress_rule" "primary_sg_http" {
    security_group_id = aws_security_group.primary_sg.id
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "primary_sg_https" {
    security_group_id = aws_security_group.primary_sg.id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "primary_sg_https_ipv6" {
    security_group_id = aws_security_group.primary_sg.id
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    cidr_ipv6 = "::/0"
}

resource "aws_vpc_security_group_egress_rule" "primary_sg_i_traffic" {
    security_group_id = aws_security_group.primary_sg.id
    ip_protocol = "-1"
    cidr_ipv4 =  "0.0.0.0/0"
}

resource "aws_instance" "primary" {
ami = var.ami_id
instance_type = var.instance_type
subnet_id = var.subnet_id
vpc_security_group_ids = [aws_security_group.primary_sg.id]
key_name = var.key_name

 user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              echo "<h1>hello from Primary EC2" > /var/www/html/index.html
              EOF

  tags = merge(var.tags , { Name = "primary-ec2"})

}

