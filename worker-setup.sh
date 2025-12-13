#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Kubernetes Worker Bootstrap
# Ubuntu 22.04 (Jammy) ARM64
# Idempotent, safe on re-run
# ==============================

# ---- Colors (if terminal supports it) ----
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log() { echo -e "${BLUE}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
err() { echo -e "${RED}ERROR:${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
  err "Run this script with sudo or as root"
  exit 1
fi

# ---- Interactive hostname ----
read -rp "Enter desired hostname for this worker: " WORKER_HOSTNAME
if [[ -n "$WORKER_HOSTNAME" ]]; then
  log "Setting hostname to $WORKER_HOSTNAME"
  hostnamectl set-hostname "$WORKER_HOSTNAME"
  if grep -q '^127.0.1.1' /etc/hosts; then
    sed -i "s/^127.0.1.1.*/127.0.1.1 $WORKER_HOSTNAME/" /etc/hosts
  else
    echo "127.0.1.1 $WORKER_HOSTNAME" >> /etc/hosts
  fi
fi

# ---- Disable swap (required by kubelet) ----
log "Disabling swap"
swapoff -a || true
sed -i.bak '/swap/d' /etc/fstab
systemctl disable --now zramswap.service 2>/dev/null || true

# ---- Kernel modules & sysctl ----
log "Configuring kernel modules and sysctl"
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true

cat >/etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# ---- Remove known-bad / legacy repos (Radxa, old k8s, docker debian) ----
log "Cleaning up conflicting APT repositories"
rm -f /etc/apt/sources.list.d/radxa*.list
rm -f /usr/share/keyrings/radxa-archive-keyring.gpg
rm -f /etc/apt/trusted.gpg.d/radxa*.gpg
rm -f /etc/apt/sources.list.d/*kubernetes-xenial*.list

# ---- Base packages ----
log "Installing base prerequisites"
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gpg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# ---- containerd (Ubuntu repo, NOT Docker repo) ----
log "Installing containerd"
apt-get install -y containerd

mkdir -p /etc/containerd
if [[ ! -f /etc/containerd/config.toml ]]; then
  containerd config default >/etc/containerd/config.toml
fi

# Ensure systemd cgroups (required by kubelet)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl daemon-reexec
systemctl enable --now containerd

# ---- Kubernetes repo (pkgs.k8s.io – modern & supported) ----
log "Setting up Kubernetes APT repository"
mkdir -p /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ---- kubeadm join (interactive) ----
read -rp "Enter the full kubeadm join command for this worker: " JOIN_CMD
if [[ -n "$JOIN_CMD" ]]; then
  log "Joining the Kubernetes cluster"
  $JOIN_CMD
else
  warn "Join command not provided. You can join later using kubeadm join"
fi

log "Worker node bootstrap complete"
