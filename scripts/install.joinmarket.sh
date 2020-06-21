#!/bin/bash

source /home/joinmarket/joinin.conf

# install joinmarket
if [ ! -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
  # install joinmarket
  cd /home/joinmarket
  # PySide2 for armf: https://packages.debian.org/buster/python3-pyside2.qtcore
  sudo apt install -y python3-pyside2.qtcore python3-pyside2.qtgui python3-pyside2.qtwidgets zlib1g-dev libjpeg-dev
  # from https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/INSTALL.md 
  sudo apt install -y python3-dev python3-pip git build-essential automake pkg-config libtool libffi-dev libssl-dev libgmp-dev libsodium-dev
  sudo -u joinmarket git clone https://github.com/Joinmarket-Org/joinmarket-clientserver
  cd joinmarket-clientserver
  git reset --hard v0.6.2
  # set up jmvenv 
  sudo apt install -y virtualenv
  # use the PySide2 armf package from the system
  sudo -u joinmarket virtualenv --system-site-packages -p /usr/bin/python3.7 jmvenv
  source jmvenv/bin/activate || exit 1
  pip install -r requirements/base.txt
  # https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/requirements/gui.txt
  /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c 'import PySide2'
  pip install qrcode[pil]
  pip install https://github.com/sunu/qt5reactor/archive/58410aaead2185e9917ae9cac9c50fe7b70e4a60.zip#egg=qt5reactor
else
  echo "JoinMarket is already installed"
  echo ""
fi    

# generate joinmarket.cfg
if [ ! -f "/home/joinmarket/.joinmarket/joinmarket.cfg" ] ; then
  echo "Generating the joinmarket.cfg"
  echo ""
  . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
  cd /home/joinmarket/joinmarket-clientserver/scripts/
  python wallet-tool.py generate --datadir=/home/joinmarket/.joinmarket
  sudo chmod 600 /home/joinmarket/.joinmarket/joinmarket.cfg || exit 1
else
  echo "the joinmarket.cfg is already present"
  echo ""
fi

# make sure permission 600
sudo chmod 600 /home/joinmarket/.joinmarket/joinmarket.cfg || exit 1

if [ ${runBehindTor} = "on" ]; then
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
--exit-label "Continue to edit the joinmarket.cfg" \
--textbox "info.conf.txt" 20 102

# edit joinmarket.cfg
/home/joinmarket/set.conf.sh /home/joinmarket/.joinmarket/joinmarket.cfg
