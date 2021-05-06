#!/bin/bash

# QUICKSTART menu options

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

function cacheAndShowQR() {
  # cache wallet data
  walletData=$(mktemp -p /dev/shm/)
  clear
  /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)" nomethod 0 2>&1 | tee $walletData
  firstNewAddress=$(cat "$walletData" | grep "0.00000000	new" | sed -n 1p | awk '{print $2}')
  echo
  if [ ${#firstNewAddress} -eq 0 ]; then
    echo "# Error: missing address data"
    echo
    echo "# Type 'menu' to return"
    echo
    exit 1
  fi
  # display data
  cat "$walletData"
  echo
  echo "Fund the wallet on the first 'new' address to get started (displayed as a QR code also):"
  echo "$firstNewAddress"
  echo
  qrencode -t ANSIUTF8 "${firstNewAddress}"
  echo
  shred $wallet $mixdepth $walletData
  sudo rm -f /dev/shm/*
}

# BASIC MENU INFO
HEIGHT=10
WIDTH=52
CHOICE_HEIGHT=4
TITLE="Quickstart options"
BACKTITLE="Quickstart options"
MENU=""
OPTIONS=()

# Basic Options
OPTIONS+=(
  GEN "Generate a new wallet"
  m0 "Show the first mixdepth to deposit to"
  MAKER "Run the Yield Generator"
  DOCS "Link to the documentation"
)

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

  GEN)
    menu_GEN;;
  m0)
    checkRPCwallet
    # wallet
    chooseWallet
    cacheAndShowQR
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  MAKER)
    menu_MAKER;;
  DOCS)
    datastring="https://github.com/openoms/joininbox#more-info"
    clear
    echo
    echo "Find a collection of written documentation and links to videos at:"
    echo "$datastring"
    echo
    qrencode -t ANSIUTF8 "${datastring}"
    echo            
    echo "Press ENTER to return to the menu..."
    read key;;
esac