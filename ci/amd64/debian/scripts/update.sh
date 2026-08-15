#!/bin/sh -eux

arch="$(uname -r | sed 's/^.*[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\(-[0-9]\{1,2\}\)-//')"
debian_version="$(lsb_release -r | awk '{print $2}')"
major_version="$(echo $debian_version | awk -F. '{print $1}')"

# Disable systemd apt timers/services
systemctl stop apt-daily.timer
systemctl stop apt-daily-upgrade.timer
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl mask apt-daily.service
systemctl mask apt-daily-upgrade.service
systemctl daemon-reload

apt-get update

# no tty in the packer build: debconf must not prompt and dpkg conffile
# questions (eg initramfs.conf during kernel upgrades) resolve to the
# default action while keeping the existing config
export DEBIAN_FRONTEND=noninteractive
echo 'Dpkg::Options { "--force-confdef"; "--force-confold"; }' \
  > /etc/apt/apt.conf.d/90joininbox-noninteractive

apt-get -y upgrade linux-image-$arch
apt-get -y install linux-headers-$(uname -r)
