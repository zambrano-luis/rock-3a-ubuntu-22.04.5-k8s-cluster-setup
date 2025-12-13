# rock-3a-debian-11-k8s
This is the sanitized version of all the scripts I ran (but in a single script) to get the master node of my k8s cluster going

Few things:

1. Image
- I got my image from here: https://github.com/radxa-build/rock-3a/releases/tag/b25
- Or more specifically https://github.com/radxa-build/rock-3a/releases/download/b25/rock-3a_ubuntu_jammy_cli_b25.img.xz

2. When you download your file remember to "chmod +x whatever-you-call-the-file-setup.sh"

3. One script is the setup for the master node - this does not set up or help the worker nodes join that you would have to do separately
- Run the next script on the master to get the join command you need to run on the workers when the workers are set up and save it somewhere or run it again I guess!
- kubeadm token create --print-join-command

4. I am NOT a kubernetes expert (yet) I know what it is, I know why it exists, but I can't explain everything that goes on hence me creating this.

5. I am creating the script for the worker node setup later
