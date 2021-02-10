#!/bin/bash

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "a script to install, update or configure JoinMarket"
 echo "install.joinmarket.sh [install|config|update|testPR <PRnumber>]"
 exit 1
fi

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

if [ "$1" = "config" ]; then
  generateJMconfig
  # show info
  dialog \
  --title "Configure JoinMarket" \
  --exit-label "Continue to edit the joinmarket.cfg" \
  --textbox "info.conf.txt" 21 102
  # edit joinmarket.cfg
  /home/joinmarket/set.conf.sh /home/joinmarket/.joinmarket/joinmarket.cfg
  exit 0
fi

if [ "$1" = "install" ]; then
  # install joinmarket
  if [ ! -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
    echo
    echo "# JoinMarket is not yet installed - proceeding now"
    echo
    installJoinMarket  
    errorOnInstall $?
  else
    echo
    echo "# JoinMarket $currentJMversion is installed"
    echo
  fi
  exit 0
fi

if [ "$1" = "update" ]; then
  stopYG
  installJoinMarket update
  errorOnInstall $?
  exit 0
fi

if [ "$1" = "testPR" ]; then
  stopYG
  installJoinMarket testPR $2
  errorOnInstall $?
  exit 0
fi