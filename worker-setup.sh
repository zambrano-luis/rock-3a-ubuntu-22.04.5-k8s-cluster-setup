#!/usr/bin/env bash
set -e

# -------- Colors --------
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()    { echo -e "${BLUE}==> $*${NC}"; }
success() { echo -e "${GREEN}✔ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✖ $*${NC}"; }

# -------- Root check --------
if [ "$EUID" -ne 0 ]; then
  error "Run this script with sudo"
  exit 1
fi

echo
info "Kubernetes WORKER node bootstrap starting"
echo

# -------- Hostname --------
read -rp "Enter desired hostname for this worker: " WORKER_HOSTNAME
if [ -n "$WORKER_HOSTNAME" ]; then
  info "Setting hostname to $WORKER_HOSTNAME"
  hostnamectl set-hostname "$WORKER_HOSTNAME"
  sed -i "/127.0.1.1/d" /etc/hosts
  echo "127.0.1.1 $WORKER_HOSTNAME" >> /etc/hosts
fi

# -------- Remove Radxa repos (critical) --------
info "Removing Radxa repositories if present"
rm -f /etc/apt/sources.list.d/radxa*.list
rm -f /usr/share/keyrings/radxa-archive-keyring.gpg
rm -f /etc/apt/trusted.gpg.d/radxa*.gpg
success "Radxa repos cleaned"

# -------- Disable swap --------
info "Disabling swap"
swapoff -a || true
sed -i.bak '/swap/d' /etc/fstab || true
systemctl disable --now zramswap.service 2>/dev/null || true
success "Swap disabled"

# -------- Kernel modules --------
info "Configuring kernel modules"
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay || true
modprobe br_netfilter || true

# -------- Sysctl --------
info "Configuring sysctl for Kubernetes"
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system >/dev/null
success "Kernel networking configured"

# -------- Packages --------
info "Installing base packages"
apt update
apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# -------- containerd --------
info "Installing containerd (Ubuntu repo)"
apt install -y containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Use systemd cgroups
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
success "containerd installed and configured"

# -------- Kubernetes repo --------
info "Setting up Kubernetes repository"
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
EOF

apt update

# -------- Kubernetes packages --------
info "Installing Kubernetes components"
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
success "Kubernetes components installed"

# -------- Reset if needed --------
if [ -f /etc/kubernetes/kubelet.conf ]; then
  warn "Existing Kubernetes config found – resetting node"
  kubeadm reset -f
fi

# -------- Join cluster --------
echo
read -rp "Enter the FULL kubeadm join command: " JOIN_CMD
echo

info "Joining the Kubernetes cluster"
eval "$JOIN_CMD"

success "Worker node successfully joined"
echo
info "Reboot recommended"
