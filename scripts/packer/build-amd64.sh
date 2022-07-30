#!/bin/bash -e

# Install packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install virtualbox
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

sudo apt-get update

echo -e "\nInstalling packer..."
sudo apt-get install -y packer

echo -e "\nInstalling virtualbox..."
sudo apt-get install -y virtualbox-5.2

# Build the image
echo -e "\nBuilding packer image..."
packer build joininbox-amd64.pkr.hcl