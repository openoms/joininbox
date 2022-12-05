#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

echo -e "Installing Go..."
export PATH=$PATH:/usr/local/go/bin

wget --progress=bar:force https://go.dev/dl/go1.18.8.linux-amd64.tar.gz
echo "4d854c7bad52d53470cf32f1b287a5c0c441dc6b98306dea27358e099698142a go1.18.8.linux-amd64.tar.gz" | sha256sum -c -
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.8.linux-amd64.tar.gz
sudo rm -rf go1.18.8.linux-amd64.tar.gz


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

# Build the image in docker
echo -e "\nBuilding packer image..."
docker run --rm --privileged -v /dev:/dev -v \
 ${PWD}:/build mkaczanowski/packer-builder-arm build \
 -var "github_user=${github_user}" -var "branch=${branch}" \
 amd64-rpi.pkr.hcl