#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/v1.6/home.admin/_bootstrap.sh
# used when running standalone

################################
# GENERATE UNIQUE SSH PUB KEYS
# on first boot up
################################

numberOfPubKeys=$(sudo ls /etc/ssh/ | grep -c 'ssh_host_')
if [ ${numberOfPubKeys} -eq 0 ]; then
  echo "*** Generating new SSH PubKeys" >> $logFile
  sudo dpkg-reconfigure openssh-server
  echo "OK" >> $logFile
fi