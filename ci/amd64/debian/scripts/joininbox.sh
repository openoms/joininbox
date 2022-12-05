#!/bin/sh -eux

echo 'Download the build_joininbox.sh script ...'
wget https://raw.githubusercontent.com/openoms/joininbox/master/build_joininbox.sh

echo 'Build Joininbox ...'
sudo bash build_joininbox.sh "${github_user}" "${branch}"

echo 'Delete SSH keys (will be recreated on the first boot)'
sudo rm /etc/ssh/ssh_host_*
echo 'OK'
