#!/bin/bash -e

sudo apt-get update

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

# install qemu and UEFI firmware
echo "# Install qemu ..."
sudo apt-get update
sudo apt-get install -y qemu-system ovmf

# set vars from positional arguments (for backward compatibility with CI)
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

vars="-var github_user=${github_user} -var branch=${branch}"

# Build the image
echo "# Build the image with: github_user=${github_user} branch=${branch}"
cd debian
packer init -upgrade .
PACKER_LOG=1 packer build ${vars} -only=qemu.debian build.amd64-debian.pkr.hcl || exit 1
