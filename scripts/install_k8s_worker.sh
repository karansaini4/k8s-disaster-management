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

apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" awscli

aws s3 cp s3://my-kube-join-command-0987/joincluster.sh /home/ubuntu/joincluster.sh --region ap-south-2
sudo bash /home/ubuntu/joincluster.sh
