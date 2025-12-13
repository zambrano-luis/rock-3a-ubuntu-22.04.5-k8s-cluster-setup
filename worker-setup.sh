#!/usr/bin/env bash

# ============================
# Worker Node Setup for K8s
# ============================

# Colors for terminal output
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

echo "${BLUE}==> Worker node bootstrap starting...${RESET}"

# ----------------------------
# 1. Ask for hostname
# ----------------------------
read -rp "$(echo -e ${YELLOW}Enter desired hostname for this worker: ${RESET})" WORKER_HOSTNAME
echo "${GREEN}Setting hostname to $WORKER_HOSTNAME${RESET}"
sudo hostnamectl set-hostname "$WORKER_HOSTNAME"
sudo sed -i.bak "/127.0.1.1/c\127.0.1.1 $WORKER_HOSTNAME" /etc/hosts || true

# ----------------------------
# 2. Disable swap
# ----------------------------
echo "${BLUE}==> Disabling swap...${RESET}"
sudo swapoff -a
sudo sed -i.bak '/swap/d' /etc/fstab
if systemctl list-unit-files | grep -q zramswap; then
    sudo systemctl disable --now zramswap.service
    sudo swapoff /dev/zram0 || true
fi

# ----------------------------
# 3. Update OS and install prerequisites
# ----------------------------
echo "${BLUE}==> Updating OS and installing prerequisites...${RESET}"
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https

# ----------------------------
# 4. Install containerd
# ----------------------------
echo "${BLUE}==> Installing containerd...${RESET}"
sudo apt remove -y containerd containerd.io || true
sudo apt update
sudo apt install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

# ----------------------------
# 5. Set up Kubernetes repo
# ----------------------------
echo "${BLUE}==> Setting up Kubernetes repository...${RESET}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

# ----------------------------
# 6. Install Kubernetes components
# ----------------------------
echo "${BLUE}==> Installing kubelet, kubeadm, kubectl...${RESET}"
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet

# ----------------------------
# 7. Join Kubernetes cluster
# ----------------------------
read -rp "$(echo -e ${YELLOW}Enter the full kubeadm join command for this worker: ${RESET})" KUBEADM_JOIN_CMD
echo "${GREEN}Joining the Kubernetes cluster...${RESET}"
sudo $KUBEADM_JOIN_CMD

echo "${GREEN}Worker node bootstrap complete!${RESET}"
