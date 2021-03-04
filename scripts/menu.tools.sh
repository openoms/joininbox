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

function getQRstring {
  QRstring=$(mktemp 2>/dev/null)
  dialog --backtitle "Display a QR code from any text" \
  --title "Enter any text" \
  --inputbox "
  Enter the text to be shown as a QR code" 9 71 2> "$QRstring"
  openMenuIfCancelled $?
}

# BASIC MENU INFO
HEIGHT=11
WIDTH=55
CHOICE_HEIGHT=20
TITLE="Tools"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
if [ "${runningEnv}" = standalone ]; then
  OPTIONS+=(
    SPECTER "Specter Desktop options")
fi
OPTIONS+=(
    QR "Display a QR code from any text"
    CUSTOMRPC "Run a custom bitcoin RPC with curl"
    BOLTZMANN "Analyze the entropy of a transaction"
    LOGS "Show the bitcoind logs on $network")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Back" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  QR)
    getQRstring
    datastring=$(cat $QRstring)
    echo
    echo "Displaying the text:"
    echo "$datastring"
    echo
    if [ ${#datastring} -eq 0 ]; then
      echo "# Error='missing string'"
    fi
    qrencode -t ANSIUTF8 "${datastring}"
    echo "(To shrink QR code: MacOS press CMD- / Linux press CTRL-)"
    echo            
    echo "Press ENTER to return to the menu..."
    read key
    ;;
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
    echo "# Input which method (command) to use"
    read method
    echo "# Input the parameter(s) (optional)"
    read params
    customRPC "# custom RPC" "$method" "$params" 
    echo            
    echo "Press ENTER to return to the menu..."
    read key
    ;;
  SPECTER)
    /home/joinmarket/standalone/menu.specter.sh
    ;;
  LOGS)
    showBitcoinLogs
    ;;
esac