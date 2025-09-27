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

resource "aws_instance" "master" {
  ami = var.ami_id
  instance_type = var.master_instance_type
  subnet_id = var.master_subnet_id
  vpc_security_group_ids = [aws_security_group.dr_sg.id]
  key_name = var.key_name

user_data = <<-EOF
#!/bin/bash
set -e
apt-get update -y
apt-get install -y curl gnupg apt-transport-https ca-certificates docker.io

systemctl enable docker
systemctl start docker

K3S_TOKEN="${var.k3s_token}"
curl -sfL https://get.k3s.io | sh -s - server --token "${var.k3s_token}" --tls-san 127.0.0.1

sleep 30

ln -s /usr/local/bin/kubectl /usr/bin/kubectl || true
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

/usr/local/bin/kubectl create deployment dr-app --image=nginx --replicas=1 || true
/usr/local/bin/kubectl expose deployment dr-app --type=NodePort --port=80 || true

EOF
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

 user_data = base64encode(<<-EOF
             #!/bin/bash
             set -e
             apt-get update -y
             apt-get install -y curl gnupg apt-transport-https ca-certificates
             apt-get install -y docker.io
             systemctl enable docker
             systemctl start docker

             K3S_TOKEN="${var.k3s_token}"
             K3S_URL="https://${aws_instance.master.private_ip}:6443"

             curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${var.k3s_token}" sh -s - agent
             EOF
)
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

