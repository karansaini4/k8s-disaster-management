data "aws_region" "current" {}

resource "aws_security_group" "dr_sg" {
    name = "${var.name}-dr-sg"
    description = "DR security group"
    vpc_id = var.vpc_id

    tags = merge(var.tags, {Name = "${var.name}-dr-sg"})
}

resource "aws_vpc_security_group_ingress_rule" "dr_sg_http" {
  security_group_id = aws_security_group.dr_sg.id
  description = "HTTP"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dr_sg_k8s_api" {
  security_group_id = aws_security_group.dr_sg.id
  description = "kube api"
  from_port = 30080
  to_port = 30080
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dr_sg_ssh" {
  security_group_id = aws_security_group.dr_sg.id
  description = "SSH"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dr_sg_k8s" {
  security_group_id = aws_security_group.dr_sg.id
  description = "kubernets API"
  from_port = 6443
  to_port = 6443
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dr_sg_outbound" {
  security_group_id = aws_security_group.dr_sg.id
 ip_protocol = "-1"
 cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_s3_bucket" "example" {
  bucket = "my-kube-join-command-0987"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_iam_role" "kube_master_role" {
  name = "KubeMasterS3Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AmazonS3FullAccess to the role
resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.kube_master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "kube_master_profile" {
  name = "KubeMasterS3Profile"
  role = aws_iam_role.kube_master_role.name
}

resource "aws_instance" "master" {
  ami = var.ami_id
  instance_type = var.master_instance_type
  subnet_id = var.master_subnet_id
  vpc_security_group_ids = [aws_security_group.dr_sg.id]
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.kube_master_profile.name

user_data = file("${path.module}/../../scripts/install_k8s_master.sh")
}




resource "aws_iam_role" "worker_role" {
   name="${var.name}-dr-worker-role"
   assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com"}
    }]
   })

   tags = merge(var.tags, {Name = "${var.name}-dr-worker-role"})
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name = "${var.name}-cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Action = [
                "autoscalling:DescribeAutoScalingGroups",
                "autoscalling:DescribeAutoScallingInstances",
                "autoscalling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeTags"
            ]
            Resource = "*"
        }
    ]
  })
}

resource "aws_iam_policy" "s3_access_policy_worker" {
  name = "${var.name}-s3-access-policy-worker"
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-kube-join-command-0987/*"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach_worker" {
  role = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.s3_access_policy_worker.arn
}

resource "aws_iam_role_policy_attachment" "ca_attach" {
  role = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.name}-dr-worker-profile"
  role = aws_iam_role.worker_role.name
}

resource "aws_launch_template" "worker_lt" {
  name_prefix = "${var.name}-dr-worker-"
  image_id = var.ami_id
  instance_type = var.worker_instance_type
  key_name = var.key_name

vpc_security_group_ids = [aws_security_group.dr_sg.id]
iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
}

user_data = base64encode(templatefile("${path.module}/../../scripts/install_k8s_worker.sh",{}))

 tag_specifications {
   resource_type = "instance"
   tags = merge(var.tags, {Name = "${var.name}-dr-worker"})
 }

}


resource "aws_autoscaling_group" "worker_asg" {
  name = "${var.name}-dr-worker-asg"
  max_size = var.max_size
  min_size = var.min_size
  desired_capacity = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids
  health_check_type = "EC2"


  launch_template {
    id = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  tag{
    key = "Name"
    value = "${var.name}-dr-worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_policy" "scale_up" {
   name = "${var.name}-dr-scale-up"
   autoscaling_group_name = aws_autoscaling_group.worker_asg.name
   adjustment_type = "ChangeInCapacity"
   scaling_adjustment = 1
   cooldown = 60
}

resource "aws_autoscaling_policy" "scale_down" {
   name = "${var.name}-dr-scale-down"
   autoscaling_group_name = aws_autoscaling_group.worker_asg.name
   adjustment_type = "ChangeInCapacity"
   scaling_adjustment = -1
   cooldown = 60
}

