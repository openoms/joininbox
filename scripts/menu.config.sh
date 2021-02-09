#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=9
WIDTH=58
CHOICE_HEIGHT=20
TITLE="Tools"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JMCONF "Edit the joinmarket.cfg manually" \
  CONNECT "Connect to a remote bitcoin node on mainnet"\
  SIGNET "Switch to signet with local Bitcoin Core"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  JMCONF)
    /home/joinmarket/install.joinmarket.sh config
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    ;;
  CONNECT)
    /home/joinmarket/install.signet.sh off
    /home/joinmarket/menu.bitcoinrpc.sh
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  SIGNET)
    /home/joinmarket/install.signet.sh on
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
esac