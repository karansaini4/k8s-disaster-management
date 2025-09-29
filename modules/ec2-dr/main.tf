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

resource "aws_instance" "master" {
  ami = var.ami_id
  instance_type = var.master_instance_type
  subnet_id = var.master_subnet_id
  vpc_security_group_ids = [aws_security_group.dr_sg.id]
  key_name = var.key_name

user_data = <<-EOF
#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/' /etc/needrestart/needrestart.conf

echo "libapache2-mod-php7.4 libapache2-mod-php7.4/restart-services string" | debconf-set-selections
echo "libapache2-mod-php7.4 libapache2-mod-php7.4/restart-without-asking boolean true" | debconf-set-selections
echo 'shared/default-restart-services boolean true' | debconf-set-selections

alias apt-get='apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'

sudo apt-get update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl gnupg apt-transport-https ca-certificates

echo "Installing CRI-O version 1.28 on xUbuntu_22.04..."

sudo apt-get update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl gnupg apt-transport-https ca-certificates

sudo rm -f /etc/apt/sources.list.d/*.list
sudo rm -f /etc/apt/keyrings/libcontainers*.gpg
sudo rm -f /etc/apt/trusted.gpg.d/libcontainers*.gpg
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

sudo mkdir -p /etc/apt/keyrings

echo "Importing GPG key for libcontainers..."
curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/Release.key -o /tmp/libcontainers.key
if [ ! -s /tmp/libcontainers.key ]; then
  echo "Failed to download libcontainers key. Aborting."
  exit 1
fi
sudo gpg --dearmor -o /etc/apt/keyrings/libcontainers.gpg < /tmp/libcontainers.key

echo "Importing GPG key for CRI-O..."
curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.28/xUbuntu_22.04/Release.key -o /tmp/crio.key
if [ ! -s /tmp/crio.key ]; then
  echo "Warning: Failed to download CRI-O key. Falling back to libcontainers key."
  sudo cp /etc/apt/keyrings/libcontainers.gpg /etc/apt/keyrings/libcontainers-crio.gpg
else
  sudo gpg --dearmor -o /etc/apt/keyrings/libcontainers-crio.gpg < /tmp/crio.key
fi

sudo rm -f /etc/apt/sources.list.d/*.list
sudo rm -f /etc/apt/keyrings/libcontainers*.gpg
curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/Release.key | sudo apt-key add -
curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.28/xUbuntu_22.04/Release.key | sudo apt-key add -
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/libcontainers.list
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.28/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/crio.list

sudo apt-get update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" cri-o cri-o-runc

sudo systemctl daemon-reload

sudo systemctl enable crio
sudo systemctl start crio

echo "Starting CRI-O service..."
timeout=30
counter=0
while [ $counter -lt $timeout ]; do
  if sudo systemctl is-active --quiet crio; then
    echo "CRI-O is running successfully!"
    break
  fi
  echo "Waiting for CRI-O to start... ($((counter + 1))/$timeout)"
  sleep 1
  counter=$((counter + 1))
done

if [ $counter -eq $timeout ]; then
  echo "CRI-O failed to start within $timeout seconds. Check status with: sudo systemctl status crio"
  echo "View logs with: sudo journalctl -u crio -e"
  exit 1
fi

sudo systemctl status crio --no-pager

echo "CRI-O installation complete!"

rm -f /tmp/libcontainers.key /tmp/crio.key

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends kubeadm=1.31.0-1.1 kubelet=1.31.0-1.1 kubectl=1.31.0-1.1

sudo apt-mark hold kubeadm kubelet kubectl

sudo sysctl -w net.ipv4.ip_forward=1

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo kubeadm init --cri-socket unix:///var/run/crio/crio.sock --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > /tmp/kube-ca.crt
sudo cp /tmp/kube-ca.crt /usr/local/share/ca-certificates/kube-ca.crt
sudo update-ca-certificates

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml --validate=false

sleep 30
until kubectl get pods -n kube-system | grep calico | grep Running; do echo "Waiting for Calico to be ready..."; sleep 5; done

kubectl create deployment dr-app --image=nginx --replicas=1

kubectl expose deployment dr-app --type=NodePort --port=80 

cat << YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dr-app-service
  namespace: default
spec:
  selector:
    app: dr-app
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
YAML

CONTROL_PLANE_NODE=$(kubectl get nodes --show-labels | awk '/node-role.kubernetes.io\/control-plane/ {print $1}')
if [ -n "$CONTROL_PLANE_NODE" ]; then
    kubectl taint nodes $CONTROL_PLANE_NODE node-role.kubernetes.io/control-plane:NoSchedule- --overwrite
fi


mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config

 kubectl get services --all-namespaces
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

