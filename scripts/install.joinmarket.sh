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
  --textbox "/home/joinmarket/info.conf.txt" 45 101
  # edit joinmarket.cfg
  /home/joinmarket/set.conf.sh $JMcfgPath
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
    echo "# Check for optional dependencies: matplotlib and scipy"
    activateJMvenv
    if [ "$(pip list | grep -c matplotlib)" -eq 0 ];then
      pip install matplotlib
    fi
    if [ "$(pip list | grep -c scipy)" -eq 0 ];then
      pip install scipy
    fi
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