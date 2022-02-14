#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/v1.6/home.admin/XXprepareRelease.sh

# Run this script once after a fresh sd card build
# to prepare the image for release as a downloadable sd card image

# SSH authorized keys
echo
echo "# Deleting SSH authorized_keys ..."
sudo rm /root/.ssh/authorized_keys
echo "# OK"

# SSH Pubkeys (make unique for every sd card image install)
echo
echo "# Deleting SSH Pub keys ..."
echo "# Will be recreated on reboot"
sudo rm /etc/ssh/ssh_host_*
echo "# OK"

# https://github.com/rootzoll/raspiblitz/issues/1068#issuecomment-599267503
echo
echo "# Deleting local DNS confs ..."
sudo rm /etc/resolv.conf
echo "# OK"

# https://github.com/rootzoll/raspiblitz/issues/1371
echo
echo "# Deleting local WIFI conf ..."
sudo rm /boot/wpa_supplicant.conf 2>/dev/null
# reset entries
echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US" | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf  2>/dev/null
echo "# OK"

echo
echo "# Deleting the joinin.conf ..."
echo "# Will be recreated when the menu is next run."
sudo rm /home/joinmarket/joinin.conf 2>/dev/null
echo "# OK"

echo
echo "# Will shutdown now."
echo "# Wait until the SBC LEDs show no activity anymore."
echo "# Then remove SD card and make a release image from it."
sudo shutdown now
