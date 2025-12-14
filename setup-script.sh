#!/bin/bash
# Kubernetes MASTER Node Bootstrap Script for Ubuntu 22.04 ARM
# Compatible with Rock Pi boards
# Tested with Kubernetes v1.29 and containerd 1.7.28

set -e

# Helper for colored output
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${GREEN}==> Kubernetes MASTER node bootstrap starting...${NC}"

# Ask for hostname
read -rp $'\033[1;33mEnter desired hostname for this master: \033[0m' MASTER_HOSTNAME
echo -e "${GREEN}==> Setting hostname to ${MASTER_HOSTNAME}${NC}"
sudo hostnamectl set-hostname "$MASTER_HOSTNAME"
sudo sed -i.bak "/127.0.1.1/c\127.0.1.1 $MASTER_HOSTNAME" /etc/hosts

# Disable swap
echo -e "${GREEN}==> Disabling swap...${NC}"
sudo swapoff -a
sudo sed -i.bak '/swap/d' /etc/fstab

# Kernel modules
echo -e "${GREEN}==> Loading kernel modules...${NC}"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params
echo -e "${GREEN}==> Configuring sysctl for Kubernetes...${NC}"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Clean old Radxa or other conflicting repos
echo -e "${GREEN}==> Cleaning up conflicting APT repositories...${NC}"
sudo rm -f /etc/apt/sources.list.d/radxa*.list
sudo rm -f /usr/share/keyrings/radxa-archive-keyring.gpg
sudo rm -f /etc/apt/trusted.gpg.d/radxa*.gpg
sudo apt clean

# Base prerequisites
echo -e "${GREEN}==> Installing base prerequisites...${NC}"
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# Install containerd 1.7.28
echo -e "${GREEN}==> Installing containerd 1.7.28...${NC}"
sudo apt install -y containerd runc

# Enable and start containerd
sudo systemctl enable containerd
sudo systemctl restart containerd

# Add Kubernetes repo
echo -e "${GREEN}==> Adding Kubernetes APT repository...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

# Install kubeadm, kubelet, kubectl
echo -e "${GREEN}==> Installing Kubernetes components...${NC}"
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet

# Initialize Kubernetes master
echo -e "${GREEN}==> Initializing Kubernetes master...${NC}"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo -e "${GREEN}==> Master node setup complete!${NC}"
echo -e "${YELLOW}==> To install a Pod network (Flannel):${NC}"
echo "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
echo -e "${YELLOW}==> Use 'kubeadm token create --print-join-command' to join worker nodes.${NC}"
