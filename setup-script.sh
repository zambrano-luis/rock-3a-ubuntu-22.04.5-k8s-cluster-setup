#!/bin/bash
set -e

# Colored output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${GREEN}==> Updating OS and installing prerequisites...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release

echo -e "${GREEN}==> Removing any old or conflicting repositories...${NC}"
sudo rm -f /etc/apt/sources.list.d/radxa*.list
sudo rm -f /etc/apt/sources.list.d/*jammy*
sudo apt clean

echo -e "${GREEN}==> Setting up Docker repository for containerd...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update

echo -e "${GREEN}==> Installing containerd...${NC}"
sudo apt install -y containerd.io
sudo systemctl enable --now containerd

echo -e "${GREEN}==> Configuring containerd for Kubernetes...${NC}"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

echo -e "${GREEN}==> Disabling swap...${NC}"
sudo swapoff -a
sudo sed -i.bak '/swap/d' /etc/fstab

echo -e "${GREEN}==> Setting up Kubernetes repository...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

echo -e "${GREEN}==> Installing Kubernetes components...${NC}"
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet

if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo -e "${GREEN}==> Initializing Kubernetes master node...${NC}"
    read -p "$(echo -e ${YELLOW}Enter pod network CIDR (default 10.244.0.0/16):${NC} )" POD_CIDR
    POD_CIDR=${POD_CIDR:-10.244.0.0/16}
    sudo kubeadm init --pod-network-cidr=$POD_CIDR

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

echo -e "${GREEN}==> Applying Flannel CNI network...${NC}"
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo -e "${GREEN}==> Kubernetes master setup complete!${NC}"
echo -e "${YELLOW}Use 'kubeadm token create --print-join-command' to get the join command for worker nodes.${NC}"
kubectl get nodes -o wide
kubectl get pods -A
