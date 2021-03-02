#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

if [ "${runningEnv}" = standalone ]; then
  source /home/joinmarket/standalone/_functions.standalone.sh
  network=mainnet
elif [ "${runningEnv}" = raspiblitz ];then
  source /mnt/hdd/raspiblitz.conf
  if [ $network = bitcoin ];then
    network=${chain}net
  else
    network=unsupported
  fi
fi

# BASIC MENU INFO
HEIGHT=12
WIDTH=64
CHOICE_HEIGHT=20
TITLE="Configuration options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(
  JMCONF "Edit the joinmarket.cfg manually"
  CONNECT "Connect to a remote bitcoin node on mainnet"
  SIGNET "Switch to signet with a local Bitcoin Core")
if [ "${runningEnv}" = standalone ]; then
  OPTIONS+=(PRUNED "Start a pruned node locally from prunednode.today")
fi
if [ -f /home/bitcoin/.bitcoin/bitcoin.conf ];then
  OPTIONS+=(LOCAL "Connect to the local Bitcoin Core on $network")
fi

OPTIONS+=(RESET "Reset the joinmarket.cfg to the defaults")

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
  RESET)
    echo "# Removing the joinmarket.cfg"
    rm -f $JMcfgPath
    generateJMconfig
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  CONNECT)
    /home/joinmarket/install.bitcoincore.sh signetOff
    /home/joinmarket/menu.bitcoinrpc.sh
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  SIGNET)
    /home/joinmarket/install.bitcoincore.sh signetOn
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  PRUNED)
    /home/joinmarket/install.bitcoincore.sh signetOff
    installBitcoinCoreStandalone
    echo
    downloadSnapShot
    installMainnet
    connectLocalNode
    showBitcoinLogs
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  LOCAL)
    connectLocalNode $network
    sudo systemctl start bitcoind
    showBitcoinLogs
    echo         
    echo "Press ENTER to return to the menu..."
    read key
    ;;
esac