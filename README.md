🪨 **rock-3a-ubuntu-22.04.5-k8s-cluster-setup**

A sanitized, interactive, and colorized script setup for deploying a Kubernetes cluster on Rock 3A ARM boards.

⚠️ **Note:** This is a personal setup guide. Not all edge cases are handled. Follow prompts carefully and do one node at a time.

🧩 **Overview**

This project includes:

* **Master Node Setup Script:** Initializes the Kubernetes master node.
* **Worker Node Setup Script:** Prepares a worker node and joins it to the cluster.

**The scripts:**

* Set hostnames interactively
* Disable swap and configure kernel modules/sysctl
* Install containerd v1.7.28 consistently across all nodes
* Install kubeadm, kubelet, and kubectl
* Join worker nodes to the master automatically

🚀 **Getting Started**

**1️⃣ Download the Base Image**

Rock 3A Ubuntu Jammy CLI image:

* GitHub Releases: https://github.com/radxa-build/rock-3a/releases/tag/b25
* Direct Download: https://github.com/radxa-build/rock-3a/releases/download/b25/rock-3a_ubuntu_jammy_cli_b25.img.xz

Make your scripts executable:

```bash
chmod +x master-setup.sh
chmod +x worker-setup.sh
```

**2️⃣ Master Node Setup**

Run the master setup script first:

```bash
sudo ./master-setup.sh
```

It will:

* Prompt for the master node hostname
* Disable swap
* Configure kernel modules and sysctl
* Install containerd and Kubernetes components
* Initialize the master node
* Provide the kubeadm join command for workers

**3️⃣ Worker Node Setup**

On each worker node, run:

```bash
sudo ./worker-setup.sh
```

The script will:

* Prompt for the worker node hostname
* Disable swap and configure kernel modules/sysctl
* Install containerd and Kubernetes components
* Join the node to the cluster

⚡ Ensure the master is ready and reachable before running this script.

4️⃣ Network Add-On (Flannel)

After the master node is ready:

kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

📝 **Notes**

* The scripts are interactive and colorized. Pay attention to prompts.
* Do one node at a time to prevent conflicts.
* This setup assumes all nodes are on the same local network.
* Containerd version is pinned to 1.7.28 for consistency across nodes.
* Yes, you COULD ssh directly from the master into the workers and use a different set of scripts, so why didn't I do that? It was just simpler for me to do it this way and with this number of nodes.
