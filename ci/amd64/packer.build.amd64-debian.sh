#!/bin/bash -e

# install packer
if ! packer version 2>/dev/null; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update
  echo -e "\nInstalling packer..."
  sudo apt-get install -y packer
else
  echo "# Packer is installed"
fi

# install qemu
echo "# Install qemu ..."
sudo apt-get update
sudo apt-get install -y qemu-system

# install qemu plugin
packer plugins install github.com/hashicorp/qemu

if [ $# -gt 0 ]; then
  github_user=$1
else
  github_user=openoms
fi

if [ $# -gt 1 ]; then
  branch=$2
else
  branch=master
fi

# Build the image
echo "# Building image ..."
cd debian
PACKER_LOG=1 packer build \
 -var github_user=${github_user} -var branch=${branch} \
 -only=qemu joininbox-amd64-debian.json
