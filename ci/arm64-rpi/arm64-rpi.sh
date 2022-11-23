#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

echo -e "Installing Go..."
wget --progress=bar:force https://go.dev/dl/go1.18.4.linux-arm64.tar.gz
echo "35014d92b50d97da41dade965df7ebeb9a715da600206aa59ce1b2d05527421f go1.18.4.linux-arm64.tar.gz" | sha256sum -c -
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.4.linux-arm64.tar.gz
sudo rm -rf go1.18.4.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Packer Arm Plugin
# clean for reruns
rm -rf packer-builder-arm
echo -e "\nInstalling Packer Arm Plugin..."
git clone https://github.com/mkaczanowski/packer-builder-arm
cd packer-builder-arm
# pin to commit hash https://github.com/mkaczanowski/packer-builder-arm/commits/master
git reset --hard e5d1defe92f0672765d6ef57bd0e22b571797049
go mod download
go build

# copy the scripts to the packer-builder-arm directory
cp ../arm64-rpi.pkr.hcl ./
cp ../../../build_joininbox.sh ./

# Build the image in docker
echo -e "\nBuilding packer image..."
docker run --rm --privileged -v /dev:/dev -v \
 ${PWD}:/build mkaczanowski/packer-builder-arm \
 build arm64-rpi.pkr.hcl