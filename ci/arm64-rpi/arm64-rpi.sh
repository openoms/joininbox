#!/bin/bash -e

cp ../../build_joininbox.sh ./

# Build the image in docker
echo -e "\nBuild Packer image..."
# from https://hub.docker.com/r/mkaczanowski/packer-builder-arm/tags
docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build \
 mkaczanowski/packer-builder-arm:master@sha256:1c5b6a23bf7e5a02413bd2bb094422ce6bb3ea94f6873a70aacdad25c767df54 \
 build arm64-rpi.pkr.hcl