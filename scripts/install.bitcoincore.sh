#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# check connectedRemoteNode var in joinin.conf
if ! grep -Eq "^connectedRemoteNode=" $joininConfPath; then
  echo "connectedRemoteNode=off" >> $joininConfPath
fi

if [ "$1" = "signetOn" ]; then
  installBitcoinCore
  installSignet
  if [ $connectedRemoteNode = "on" ];then
    backupJMconf
  fi
  generateJMconfig 
  setJMconfigToSignet
elif [ "$1" = "signetOff" ]; then
  removeSignetdService
  isSignet=$(grep -c "network = signet" < $JMcfgPath)
  if [ $isSignet -gt 0 ];then
    echo "# Removing the joinmarket.cfg with signet settings"
    rm -f $JMcfgPath
  else
    echo "# Signet is not set in joinmarket.cfg, leaving settings in place"
  fi
  generateJMconfig
elif [ "$1" = "downloadCoreOnly" ]; then
  downloadBitcoinCore
fi
