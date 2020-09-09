#!/bin/bash

# functions

function installJoinMarket() {
  version="v0.7.0"
  cd /home/joinmarket
  # PySide2 for armf: https://packages.debian.org/buster/python3-pyside2.qtcore
  echo "# installing ARM specific dependencies to run the QT GUI"
  sudo apt install -y python3-pyside2.qtcore python3-pyside2.qtgui python3-pyside2.qtwidgets zlib1g-dev libjpeg-dev
  echo "# installing JoinMarket"
  sudo -u joinmarket git clone https://github.com/Joinmarket-Org/joinmarket-clientserver
  cd joinmarket-clientserver
  sudo -u joinmarket git reset --hard $version
  # make install.sh set up jmvenv with -- system-site-packages
  # and import the PySide2 armf package from the system
  sudo -u joinmarket sed -i "s#^    virtualenv -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1#\
  virtualenv --system-site-packages -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1 ;\
  /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c \'import PySide2\'\
  #g" install.sh
  # don't install PySide2 - using the system-site-package instead 
  sudo -u joinmarket sed -i "s#^PySide2##g" requirements/gui.txt
  # don't install PyQt5 - using the system package instead 
  sudo -u joinmarket sed -i "s#^PyQt5==5.14.2##g" requirements/gui.txt
  sudo apt-get install -y python3-pyqt5
  sudo -u joinmarket ./install.sh --with-qt
  echo "# installed JoinMarket $version"
}

source /home/joinmarket/joinin.conf

if [ "$1" = "install" ]; then
  # install joinmarket
  if [ ! -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
    installJoinMarket
  else
    echo "# JoinMarket is already installed"
    echo ""
  fi
  exit 0
fi

if [ "$1" = "config" ]; then
  # generate joinmarket.cfg
  if [ ! -f "/home/joinmarket/.joinmarket/joinmarket.cfg" ] ; then
    echo "# generating the joinmarket.cfg"
    echo ""
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

if [ "$1" = "update" ]; then
  source /home/joinmarket/menu.functions.sh
  stopYG
  echo "# deleting the joinmarket-clientserver directory"
  sudo rm -rf /home/joinmarket/joinmarket-clientserver
  installJoinMarket
  exit 0
fi
