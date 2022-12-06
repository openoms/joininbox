#!/bin/sh -eux

echo 'Download the build_joininbox.sh script ...'
wget https://raw.githubusercontent.com/${github_user}/joininbox/${branch}/build_joininbox.sh

echo 'Build Joininbox ...'
sudo bash build_joininbox.sh "${github_user}" "${branch}"