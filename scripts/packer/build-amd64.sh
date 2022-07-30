#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

# Build the image in docker
echo -e "\nBuilding packer image..."
packer build \
 ${GITHUB_WORKSPACE}/.github/scripts/joininbox-amd64.pkr.hcl