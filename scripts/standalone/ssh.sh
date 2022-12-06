#!/usr/bin/env bash

# using: https://github.com/rootzoll/raspiblitz/blob/v1.8/home.admin/config.scripts/blitz.ssh.sh

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ]; then
  echo "Joininbox SSH tools"
  echo
  echo "## SSHD SERVICE #######"
  echo "blitz.ssh.sh checkrepair --> check sshd & repair just in case"
  echo
  exit 1
fi

# check if started with sudo
if [ "$EUID" -ne 0 ]; then
  echo "error='missing sudo'"
  exit 1
fi

###################
# CHECK & REPAIR
###################
if [ "$1" = "checkrepair" ]; then
  echo "# *** $0 $1"

  # check if sshd host keys are missing / need generation
  countKeyFiles=$(ls -la /etc/ssh/ssh_host_* 2>/dev/null | grep -c "/etc/ssh/ssh_host")
  echo "# countKeyFiles(${countKeyFiles})"
  if [ ${countKeyFiles} -lt 8 ]; then

    echo "# DETECTED: MISSING SSHD KEYFILES --> Generating new ones"
    systemctl stop ssh
    echo "# ssh-keygen1"
    cd /etc/ssh
    ssh-keygen -A
    systemctl start sshd
    sleep 3

    countKeyFiles=$(ls -la /etc/ssh/ssh_host_* 2>/dev/null | grep -c "/etc/ssh/ssh_host")
    echo "# countKeyFiles(${countKeyFiles})"
    if [ ${countKeyFiles} -lt 8 ]; then
      echo "# FAIL: Was not able to generate new sshd host keys"
    else
      echo "# OK: New sshd host keys generated"
    fi

  fi

  # check if SSHD service is NOT running & active
  sshdRunning=$(sudo systemctl status sshd | grep -c "active (running)")
  if [ ${sshdRunning} -eq 0 ]; then
    echo "# DETECTED: SSHD NOT RUNNING --> Try reconfigure & kickstart again"
    sudo dpkg-reconfigure openssh-server
    sudo systemctl restart sshd
    sleep 3
  fi

  # check that SSHD service is running & active
  sshdRunning=$(sudo systemctl status sshd | grep -c "active (running)")
  if [ ${sshdRunning} -eq 1 ]; then
    echo "# OK: SSHD RUNNING"
  fi

  exit 0
fi
