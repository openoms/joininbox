#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

function installBitcoinScripts {
  if [ ! -d "/home/joinmarket/bitcoin-scripts" ];then
    cd /home/bitcoin/ || exit 1
    sudo -u bitcoin git clone https://github.com/kristapsk/bitcoin-scripts.git
    cd bitcoin-scripts || exit 1
    # from https://github.com/kristapsk/bitcoin-scripts/commits/master
    sudo -u bitcoin git checkout 45642787d2f9a0ca4d3fd1b22b86863de83d8707
    sudo -u bitcoin chmod +x *.sh
  fi
}

function installBoltzmann {
  if [ ! -f "/home/joinmarket/boltzmann/bvenv/bin/activate" ] ; then
    cd /home/joinmarket/ || exit 1
    git clone https://code.samourai.io/oxt/boltzmann.git
    cd boltzmann || exit 1
    python3 -m venv bvenv
    source bvenv/bin/activate || exit 1
    python setup.py install
  fi
}

function getTXID {
  title=$1
  text=$2
  txid=$(mktemp -p /dev/shm/)
  dialog --backtitle "$title" \
  --title "$title" \
  --inputbox "
  $text" 9 71 2> "$txid"
  openMenuIfCancelled $?
}

function getQRstring {
  QRstring=$(mktemp -p /dev/shm/)
  dialog --backtitle "Display a QR code from any text" \
  --title "Enter any text" \
  --inputbox "
  Enter the text to be shown as a QR code" 9 71 2> "$QRstring"
  openMenuIfCancelled $?
}

# BASIC MENU INFO
HEIGHT=12
WIDTH=55
CHOICE_HEIGHT=6
TITLE="Tools"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
if [ "${runningEnv}" = standalone ]; then
  OPTIONS+=(
    SPECTER "Specter Desktop options")
  HEIGHT=$((HEIGHT+1))
  CHOICE_HEIGHT=$((CHOICE_HEIGHT+1))
fi
OPTIONS+=(
    QR "Display a QR code from any text"
    CUSTOMRPC "Run a custom bitcoin RPC with curl"
    CHECKTXN "CLI transaction explorer"    
    BOLTZMANN "Analyze the entropy of a transaction")
if [ "${runningEnv}" != mynode ]; then
  OPTIONS+=(
    PASSWORD "Change the ssh password")
fi
OPTIONS+=(
    LOGS "Show the bitcoind logs on $network")

CHOICE=$(dialog \
          --clear \
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
    clear
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
    read key;;
  BOLTZMANN)
    installBoltzmann
    getTXID "Enter a TXID" "Paste a TXID to analyze"
    python /home/joinmarket/start.boltzmann.py --txid=$(cat $txid)
    echo            
    echo "Press ENTER to return to the menu..."
    read key;;
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
    read key;;
  SPECTER)
    /home/joinmarket/standalone/menu.specter.sh;;
  PASSWORD)
    sudo /home/joinmarket/set.password.sh;;
  LOGS)
    showBitcoinLogs;;
  CHECKTXN)
    installBitcoinScripts
    getTXID "Enter a TXID" "Paste a TXID to check"
    getRPC
    cd /home/bitcoin/bitcoin-scripts || exit 1
    sudo -u bitcoin ./checktransaction.sh -rpcwallet=$rpc_wallet $(cat $txid)
    echo            
    echo "Press ENTER to return to the menu..."
    read key;;
esac