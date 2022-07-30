#!/bin/bash -e

# Install packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install virtualbox
wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg

sudo apt-get update

echo -e "\nInstalling packer..."
sudo apt-get install -y packer

echo -e "\nInstalling virtualbox..."
sudo apt-get install -y virtualbox-6.1

# Build the image in docker
echo -e "\nBuilding packer image..."
packer build joininbox-amd64.pkr.hcl