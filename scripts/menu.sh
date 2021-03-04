#!/bin/bash

/home/joinmarket/start.joininbox.sh
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=23
WIDTH=57
CHOICE_HEIGHT=21
BACKTITLE="JoininBox GUI $currentJBtag network:$network IP:$localip"
TITLE="JoininBox $currentJBtag $network"
MENU="
Choose from the options:"
OPTIONS=()

# Basic Options
OPTIONS+=(\
  INFO "Show the address list and balances" \
  QTGUI "Show how to open the JoinMarketQT GUI" \
  "" ""
  WALLET "Wallet management options" \
  MAKER "Yield Generator options" \
  "" ""
  SEND "Pay to an address with/without a coinjoin" \
  FREEZE "Exercise coin control within a mixdepth" \
  PAYJOIN "Send/Receive between JoinMarket wallets"
  "" ""
  OFFERS "Watch the Order Book locally" \
  "" "" 
  CONFIG "Connection and joinmarket.cfg settings" \
  TOOLS "Extra helper functions and services"
  UPDATE "Update JoininBox or JoinMarket" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Exit" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  INFO)
      checkRPCwallet
      # wallet
      chooseWallet
      # mixdepth
      mixdepth=$(mktemp -p /dev/shm/)
      dialog --backtitle "Choose a mixdepth" \
      --title "Choose a mixdepth" \
      --inputbox "
Enter a number between 0 to 4 to limit the visible mixdepths
Leave the box empty to show the addresses in all five" 10 64 2> $mixdepth
      openMenuIfCancelled $?
      /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)" nomethod "$(cat $mixdepth)"
      echo ""
      echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
      echo ""
      echo "Press ENTER to return to the menu..."
      read key
      /home/joinmarket/menu.sh
      ;;
  WALLET)
      /home/joinmarket/menu.wallet.sh
      /home/joinmarket/menu.sh          
      ;;
  QTGUI)
      /home/joinmarket/info.qtgui.sh
      /home/joinmarket/menu.sh
      ;;
  MAKER)
      /home/joinmarket/menu.yg.sh
      /home/joinmarket/menu.sh           
      ;;
  SEND)
      /home/joinmarket/menu.send.sh
      echo ""
      echo "Press ENTER to return to the menu..."
      read key
      /home/joinmarket/menu.sh
      ;;
  FREEZE)
      /home/joinmarket/menu.freeze.sh
      echo ""
      echo "Press ENTER to return to the menu..."
      read key
      /home/joinmarket/menu.sh
      ;;
  PAYJOIN)
      /home/joinmarket/menu.payjoin.sh
      /home/joinmarket/menu.sh
      ;;
  OFFERS)
      /home/joinmarket/menu.orderbook.sh
      /home/joinmarket/menu.sh
      ;;
  CONFIG)
      /home/joinmarket/menu.config.sh
      echo "Returning to the menu..."
      sleep 1
      /home/joinmarket/menu.sh
      ;;
  TOOLS)
      /home/joinmarket/menu.tools.sh
      /home/joinmarket/menu.sh
      ;;
  UPDATE)
      /home/joinmarket/menu.update.sh
      /home/joinmarket/menu.sh
      ;;            
    *)
      clear
      echo "
***************************
* JoinMarket command line *  
***************************
Notes on usage:
https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md

To open the JoininBox menu use: menu
To exit from the terminal type: exit
"
      esac
