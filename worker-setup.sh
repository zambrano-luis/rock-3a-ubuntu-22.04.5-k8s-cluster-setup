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
    echo "==> Installing containerd..."
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
# -------------
