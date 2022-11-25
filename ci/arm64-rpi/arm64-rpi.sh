#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

echo -e "Installing Go..."
# from https://go.dev/dl/
wget --progress=bar:force https://go.dev/dl/go1.19.3.linux-arm64.tar.gz
echo "99de2fe112a52ab748fb175edea64b313a0c8d51d6157dba683a6be163fd5eab go1.19.3.linux-arm64.tar.gz" | sha256sum -c -
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.19.3.linux-arm64.tar.gz
sudo rm -rf go1.19.3.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Packer Arm Plugin
# clean for reruns
sudo rm -rf packer-builder-arm
echo -e "\nInstalling Packer Arm Plugin..."
git clone https://github.com/mkaczanowski/packer-builder-arm
cd packer-builder-arm
# pin to commit hash https://github.com/mkaczanowski/packer-builder-arm/commits/master
git reset --hard 0eb143167ad45ce44a21b6848fea9ccf0e15aa8b
go mod download
go build

# copy the scripts to the packer-builder-arm directory
cp ../arm64-rpi.pkr.hcl ./
cp ../../../build_joininbox.sh ./

# Build the image in docker
echo -e "\nBuilding packer image..."
docker run --rm --privileged -v /dev:/dev -v \
 ${PWD}:/build mkaczanowski/packer-builder-arm:latest \
 build arm64-rpi.pkr.hcl