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
  # generate joinmarket.cfg
  if [ ! -f "/home/joinmarket/.joinmarket/joinmarket.cfg" ] ; then
    echo "# generating the joinmarket.cfg"
    echo
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
    cd /home/joinmarket/joinmarket-clientserver/scripts/
    python wallet-tool.py generate --datadir=/home/joinmarket/.joinmarket
  else
    echo "# the joinmarket.cfg is already present"
    echo ""
  fi
  # set strict permission to joinmarket.cfg
  sudo chmod 600 /home/joinmarket/.joinmarket/joinmarket.cfg || exit 1

  if [ "${runBehindTor}" = "on" ]; then
    #communicate with IRC servers via Tor
    sed -i "s/^host = irc.darkscience.net/#host = irc.darkscience.net/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#host = darksci3bfoka7tw.onion/host = darksci3bfoka7tw.onion/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^host = irc.hackint.org/#host = irc.hackint.org/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion/host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^socks5 = false/#socks5 = false/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#socks5 = true/socks5 = true/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#port = 6667/port = 6667/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    sed -i "s/^#usessl = false/usessl = false/g" /home/joinmarket/.joinmarket/joinmarket.cfg
    echo "Edited the joinmarket.cfg to communicate over Tor only."
  fi

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
    # run config after install
    /home/joinmarket/install.joinmarket.sh config
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