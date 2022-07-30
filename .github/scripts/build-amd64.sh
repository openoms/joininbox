#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

# Move json file to packer folder
echo -e "\nMoving json file and scripts to the packer folder..."
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/.github/scripts/joininbox-amd64.pkr.hcl
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/.github/scripts/packages.config
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/build_joininbox.sh

# Build the image in docker
echo -e "\nBuilding packer image..."
packer build joininbox-amd64.pkr.hcl