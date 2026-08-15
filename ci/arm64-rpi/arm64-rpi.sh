#!/bin/bash -e

if [ $# -gt 0 ]; then
  github_user=$1
else
  github_user=openoms
fi

if [ $# -gt 1 ] && [ -n "$2" ]; then
  branch=$2
else
  # an explicitly passed empty branch would break the raw.githubusercontent
  # fetch URL (404) - fall back to master
  branch=master
fi

# optional pull-request number: marks an unverified PR test build
if [ $# -gt 2 ]; then
  pr_number=$3
else
  pr_number=""
fi

# Build the image in docker
echo -e "\nBuild Packer image..."
# from https://hub.docker.com/r/mkaczanowski/packer-builder-arm/tags
docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build \
 mkaczanowski/packer-builder-arm:1.0.4@sha256:df09a8e249a292f10ca9b8cfd73420f5b987b6ac337d4ef28b6f4a8e61118822 \
 build -var "github_user=${github_user}" -var "branch=${branch}" -var "pr_number=${pr_number}" arm64-rpi.pkr.hcl
