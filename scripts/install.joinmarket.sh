#!/bin/bash

# install joinmarket
if [ ! -f "/home/joinin/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
    cd /home/joinin
    sudo -u joinin git clone https://github.com/JoinMarket-Org/joinmarket-clientserver.git
    cd joinmarket-clientserver
    # latest release: https://github.com/JoinMarket-Orgjoinmarket-clientserver/releases
    git reset --hard v0.6.1
    sudo -u joinin ./install.sh --without-qt
else
    echo "JoinMarket is already installed"
    echo ""
fi    

# generate joinmarket.cfg
if [ ! -f "/home/joinin/joinmarket-clientserver/scripts/joinmarket.cfg" ] ; then
    echo "Generating the joinmarket.cfg"
    . /home/joinin/joinmarket-clientserver/jmvenv/bin/activate &&\
    cd /home/joinin/joinmarket-clientserver/scripts/
    python wallet-tool.py generate
else
    echo "the joinmarket.cfg is already present"
    echo ""
fi

sudo -u joinin chmod 600 /home/joinin/joinmarket-clientserver/scripts/joinmarket.cfg || exit 1

# TODO edit joinmarket.cfg if Tor is on

# temp conf
conf=$(tempfile 2>/dev/null)
# trap it
trap "rm -f $conf" 0 1 2 5 15
# Configure joinmarket
dialog \
    --title "Edit joinmarket.cfg" \
#    --exit-label " Continue to edit the joinmarket.conf" \
#    --textbox "info.conf.txt" 20 102 \
    --editbox "/home/joinin/joinmarket-clientserver/scripts/joinmarket.cfg" 200 200 2> $conf

# make decison
pressed=$?
case $pressed in
  0)
    cat $conf | sudo -u joinin tee /home/joinin/joinmarket-clientserver/scripts/joinmarket.cfg 1>/dev/null
    shred $conf;;
  1)
    shred $conf
    echo "Cancelled"
    exit 1;;
  255)
    shred $conf
    [ -s $conf ] &&  cat $conf || echo "ESC pressed."
    exit 1;;
esac