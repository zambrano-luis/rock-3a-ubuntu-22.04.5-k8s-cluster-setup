#!/bin/bash
set -e

# =====================================================
# Step 0 - Before anything - let's get whatever updates are available
# =====================================================

sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo reboot


# =====================================================
# Alright > Kubernetes Control Plane Setup Script (Debian 11 ARM)
# =====================================================

echo "==> Starting Kubernetes Control Plane Setup"

# -----------------------------
# 1 Configure containerd
# -----------------------------
echo "==> Configuring containerd..."
sudo mkdir -p /etc/containerd
if [ ! -f /etc/containerd/config.toml ]; then
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
fi
sudo systemctl restart containerd
sudo systemctl enable containerd

# -----------------------------
# 2 Disable swap (I don't think I needed this. But every other guide has you do this. There was no swap with my image maybe I took care of this I did this setup over many tries)
# -----------------------------
echo "==> Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# -----------------------------
# 3️ Load kernel modules
# -----------------------------
echo "==> Loading kernel modules..."
for module in overlay br_netfilter; do
    sudo modprobe $module
done
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# -----------------------------
# 4️ Apply sysctl settings
# -----------------------------
echo "==> Applying sysctl settings for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# -----------------------------
# 5️ Install Kubernetes components
# -----------------------------
echo "==> Installing Kubernetes components..."
sudo apt update
sudo apt install -y apt-transport-https curl

# Add Kubernetes APT repository if not already present
if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
fi

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet
sudo systemctl start kubelet

# -----------------------------
# 6️ Initialize Kubernetes control plane
# -----------------------------
KUBEADM_CONFIG="/etc/kubernetes/admin.conf"
if [ ! -f "$KUBEADM_CONFIG" ]; then
    echo "==> Initializing Kubernetes control plane..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
fi

# -----------------------------
# 7️ Configure kubeconfig for user
# -----------------------------
echo "==> Configuring kubeconfig for user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# -----------------------------
# 8️ Deploy Flannel Pod network
# -----------------------------
if ! kubectl get pods -n kube-flannel &>/dev/null; then
    echo "==> Deploying Flannel Pod network..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
fi

# -----------------------------
# 9️ Verify cluster status
# -----------------------------
echo "==> Verifying cluster status..."
kubectl get nodes
kubectl get pods -A

echo "==> Kubernetes Control Plane setup completed successfully!"
