#!/bin/sh -eux

echo 'Download the build_joininbox.sh script ...'
wget https://raw.githubusercontent.com/${github_user}/joininbox/${branch}/build_joininbox.sh

echo 'Build Joininbox ...'
sudo env JOININBOX_PR_NUMBER="${pr_number}" bash build_joininbox.sh "${github_user}" "${branch}" "commit"

echo 'Delete SSH keys (will be recreated on the first boot)'
sudo rm /etc/ssh/ssh_host_*
echo 'OK'
