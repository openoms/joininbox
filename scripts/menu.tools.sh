#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

function installBoltzmann {
  if [ ! -f "/home/joinmarket/boltzmann/bvenv/bin/activate" ] ; then
    cd /home/joinmarket/
    git clone https://code.samourai.io/oxt/boltzmann.git
    cd boltzmann
    python3 -m venv bvenv
    source bvenv/bin/activate || exit 1
    python setup.py install
  fi
}

function getTXID {
  txid=$(mktemp 2>/dev/null)
  dialog --backtitle "Enter a TXID" \
  --title "Enter a TXID" \
  --inputbox "
  Paste a TXID to analyze" 9 71 2> "$txid"
  openMenuIfCancelled $?
}

# BASIC MENU INFO
HEIGHT=8
WIDTH=54
CHOICE_HEIGHT=20
TITLE="Tools"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  BOLTZMANN "Analyze the entropy of a transaction"\
  CUSTOMRPC "Run a custom bitcoin RPC with curl"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  BOLTZMANN)
    installBoltzmann
    getTXID
    python /home/joinmarket/start.boltzmann.py --txid=$(cat $txid)
    echo            
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  CUSTOMRPC)
    echo "***DANGER ZONE***"
    echo "# See the options at https://developer.bitcoin.org/reference/rpc/"
    echo
    getRPC
    echo
    echo "# Input which method (command) to use"
    read method
    echo "# Input the parameter(s) (optional)"
    read params
    customRPC "# custom RPC" "$method" "$params" 
    echo            
    echo "Press ENTER to return to the menu..."
    read key
esac