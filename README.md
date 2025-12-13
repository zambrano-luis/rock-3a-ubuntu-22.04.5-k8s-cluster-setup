# rock-3a-ubuntu-22.04.5-k8s-cluster-setup

This is the sanitized version of all the scripts I ran (but in a single script) to get the master node of my k8s cluster going

Few things:

1. Image
- I got my image from here: https://github.com/radxa-build/rock-3a/releases/tag/b25
- Or more specifically https://github.com/radxa-build/rock-3a/releases/download/b25/rock-3a_ubuntu_jammy_cli_b25.img.xz

2. When you download your file remember to "chmod +x whatever-you-call-the-file-setup.sh"

4. One script is the setup for the master node - this does not set up or help the worker nodes join that you would have to do separately

5. The second script is for the worker node which actually does the joinining. Do this after setting up master node.

Notes: 
- I am NOT a kubernetes expert (yet) I know what it is, I know why it exists, but I can't explain everything that goes on hence me creating this.
- Also the scripts are colored and interactive take note on what you are filling in I would also do one node at the time
