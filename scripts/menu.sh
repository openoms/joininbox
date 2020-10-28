#!/bin/bash

/home/joinmarket/start.joininbox.sh
source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=24
WIDTH=57
CHOICE_HEIGHT=20
BACKTITLE="JoininBox GUI $currentJBtag"
TITLE="JoininBox $currentJBtag"
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
  CONFIG "Edit the joinmarket.cfg" \
  UPDATE "Update JoininBox or JoinMarket" \
  "" "" 
  X "Exit to the Command Line" \
  #CONNECT "Connect to a remote bitcoind"
  #TUMBLER "Run the Tumbler to mix quickly" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  INFO)
      # wallet
      chooseWallet
      # mixdepth
      mixdepth=$(mktemp 2>/dev/null)
      dialog --backtitle "Choose a mixdepth" \
      --title "Choose a mixdepth" \
      --inputbox "
Enter a number between 0 to 4 to limit the visible mixdepths
Leave the box empty to show the addresses in all five" 10 64 2> $mixdepth
      openMenuIfCancelled $?
      /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)" nooption "$(cat $mixdepth)"
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
      /home/joinmarket/install.joinmarket.sh config
      echo "Returning to the menu..."
      sleep 1
      /home/joinmarket/menu.sh
      ;;
  CONNECT) 
      ;;
  UPDATE)
      /home/joinmarket/menu.update.sh
      /home/joinmarket/menu.sh
      ;;
  X)
      clear
      echo "
***************************
* JoinMarket command line *  
***************************
Notes on usage:
https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md

To open JoininBox menu use: menu
To exit to the RaspiBlitz menu use: exit
"
      exit 0
      ;;            
esac
