#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

echo -e "Installing Go..."
wget --progress=bar:force https://go.dev/dl/go1.18.4.linux-arm64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.4.linux-arm64.tar.gz
sudo rm -rf go1.18.4.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Packer Arm Plugin
echo -e "\nInstalling Packer Arm Plugin..."
git clone https://github.com/mkaczanowski/packer-builder-arm
cd packer-builder-arm
go mod download
go build

# Move json file to packer folder
echo -e "\nMoving json file and scripts to the packer folder..."
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/.github/scripts/joininbox-arm64.pkr.hcl
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/.github/scripts/packages.config
wget --progress=bar:force https://raw.githubusercontent.com/openoms/joininbox/packer/build_joininbox.sh

# Build the image in docker
echo -e "\nBuilding packer image..."
docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build mkaczanowski/packer-builder-arm build joininbox-arm64.pkr.hcl