#!/bin/bash
set -e

# =====================================================
# Kubernetes Worker Node Setup Script (Debian 11 ARM)
# Fully idempotent version
# =====================================================

echo "==> Removing problematic Radxa repo (if exists)..."
sudo rm -f /etc/apt/sources.list.d/radxa*.list || true
sudo apt update || true

# -----------------------------
# 1. Update OS and install prerequisites
# -----------------------------
echo "==> Updating OS and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https

# -----------------------------
# 2. Install containerd
# -----------------------------
if ! command -v containerd &>/dev/null; then
    echo "==> Installing containerd from Docker repository..."

    # Add Docker GPG key and repo
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y containerd.io
else
    echo "==> containerd already installed, skipping..."
fi

# -----------------------------
# 3. Configure containerd
# -----------------------------
if [ ! -f /etc/containerd/config.toml ]; then
    echo "==> Configuring containerd..."
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
fi
sudo systemctl restart containerd
sudo systemctl enable containerd

# -----------------------------
# 4. Disable swap
# -----------------------------
echo "==> Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab || true

# -----------------------------
# 5. Load kernel modules
# -----------------------------
echo "==> Loading kernel modules..."
for module in overlay br_netfilter; do
    if ! lsmod | grep -q "$module"; then
        sudo modprobe $module
    fi
done
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# -----------------------------
# 6. Apply sysctl settings
# -----------------------------
echo "==> Applying sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# -----------------------------
# 7. Install Kubernetes components
# -----------------------------
if ! dpkg -l | grep -q kubelet; then
    echo "==> Installing Kubernetes components..."
    if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    fi
    sudo apt update
    sudo apt install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
else
    echo "==> Kubernetes components already installed, skipping..."
fi

# -----------------------------
# 8. Join the cluster
# -----------------------------
if ! sudo kubeadm config view 2>/dev/null | grep -q "kind: JoinConfiguration"; then
    echo "==> Please enter the kubeadm join command from the master:"
    read -r JOIN_CMD
    echo "==> Joining cluster..."
    sudo $JOIN_CMD
else
    echo "==> Node has already joined the cluster, skipping kubeadm join."
fi

# -----------------------------
# 9. Done
# -----------------------------
echo "==> Worker node setup completed!"
echo "You can check node status from the master with:"
echo "kubectl get nodes"
