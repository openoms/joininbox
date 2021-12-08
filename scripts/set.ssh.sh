#!/bin/bash

if [ ${#1} -eq 0 ]||[ $1 = "-h" ]||[ $1 = "--help" ];then
  echo "Enable or disable ssh access with the joinmarket user"
  echo "sudo set.ssh.sh [off|on]"
  echo
fi

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# add default value to config if needed
if ! grep -Eq "^joinmarketSSH=" /home/joinmarket/joinin.conf; then
  echo "joinmarketSSH=on" | tee -a /home/joinmarket/joinin.conf
fi

echo
if [ "$1" = "off" ];then
  echo "# Disable ssh access with the joinmarket user"
  if ! grep -Eq "^DenyUsers joinmarket" /etc/ssh/sshd_config; then
    echo "DenyUsers joinmarket" | tee -a /etc/ssh/sshd_config
    # set value in config
    sed -i "s/^joinmarketSSH=.*/joinmarketSSH=off/g" /home/joinmarket/joinin.conf
    service sshd restart
  fi
elif [ "$1" = "on" ]; then
  echo "# Enable ssh access with the joinmarket user"
  sed -i "s/^DenyUsers joinmarket//g" /etc/ssh/sshd_config
  # set value in config
  sed -i "s/^joinmarketSSH=.*/joinmarketSSH=on/g" /home/joinmarket/joinin.conf
  service sshd restart
else
  echo "# Invalid option $*"
  exit 1
fi