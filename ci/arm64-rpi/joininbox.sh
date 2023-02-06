#!/bin/sh -eux

#echo '# Fix sudo access on bookworm'
#echo "$(hostname -I | awk '{print $1}') $(hostname)" | sudo -h 127.0.0.1 tee -a /etc/hosts

echo '# Download the build_joininbox.sh script ...'
wget https://raw.githubusercontent.com/${github_user}/joininbox/${branch}/build_joininbox.sh

echo '# Build Joininbox ...'
sudo bash build_joininbox.sh "${github_user}" "${branch}" "commit"
