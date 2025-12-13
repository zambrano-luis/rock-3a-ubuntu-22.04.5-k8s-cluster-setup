#!/bin/bash
set -euo pipefail

# ==========================================
# Ubuntu 22.04 ARM64 Kubernetes Worker Setup
# Idempotent: safe to run multiple times
# ==========================================

# ---- Configuration ----
# Users must replace this with the join command from their master:
KUBEADM_JOIN_CMD="kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"

# ---- Helper functions ----
info() { echo -e "\n==> $1"; }

# ---- 1. Remove old/bad Kubernetes or Radxa repos ----
info "Removing old or conflicting APT repositories..."
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/sources.list.d/*kubernetes*
sudo rm -f /etc/apt/sources.list.d/radxa*.list
sudo apt clean
sudo apt update

# ---- 2. Update OS and install prerequisites ----
info "Updating OS and installing prerequisites..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg2 software-properties-common apt-transport-https lsb-release

# ---- 3. Disable swap ----
info "Disabling swap..."
sudo swapoff -a
sudo sed -i.bak '/ swap /s/^\(.*\)$/#\1/g' /etc/fstab

# ---- 4. Load kernel modules and sysctl ----
info "Loading kernel modules and applying sysctl settings..."
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/99-k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# ---- 5. Install containerd ----
info "Installing containerd..."
if ! command -v containerd >/dev/null 2>&1; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y containerd.io
fi

# Configure default containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# ---- 6. Install Kubernetes components ----
info "Installing Kubernetes (ARM64 v1.29)..."
sudo rm -f /usr/share/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo apt clean
sudo apt update

sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet

# ---- 7. Join the Kubernetes cluster ----
info "Joining the Kubernetes cluster..."
$KUBEADM_JOIN_CMD

info "Worker node setup complete!"
