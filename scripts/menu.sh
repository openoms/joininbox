#!/bin/bash

if [ $(dialog | grep -c "ComeOn Dialog!") -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f /home/joinmarket/joinin.conf ]; then
  touch /home/joinmarket/joinin.conf
fi

# add default value to joinin config if needed
if ! grep -Eq "^RPCoverTor=" /home/joinmarket/joinin.conf; then
  echo "RPCoverTor=off" >> /home/joinmarket/joinin.conf
fi

if grep -Eq "^rpc_host = .*.onion" /home/joinmarket/.joinmarket/joinmarket.cfg; then 
  echo "RPC over Tor is on"
  sudo sed -i "s/^RPCoverTor=.*/RPCoverTor=on/g" /home/joinmarket/joinin.conf
else
  echo "RPC over Tor is off"
  sudo sed -i "s/^RPCoverTor=.*/RPCoverTor=off/g" /home/joinmarket/joinin.conf
fi

source /home/joinmarket/joinin.conf
source /home/joinmarket/menu.functions.sh

# BASIC MENU INFO
HEIGHT=24
WIDTH=57
CHOICE_HEIGHT=20
BACKTITLE="JoininBox GUI"
TITLE="JoininBox"
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
  OFFERS "Watch the Offer Book locally" \
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
      mixdepth=$(tempfile 2>/dev/null)
      dialog --backtitle "Choose a mixdepth" \
      --title "Choose a mixdepth" \
      --inputbox "
Enter a number between 0 to 4 to limit the visible mixdepths
Leave the box empty to show the addresses in all five" 10 64 2> $mixdepth
      openMenuIfCancelled $?
      /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) nooption $(cat $mixdepth)
      echo ""
      echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
      echo ""
      echo "Type: 'menu' and press ENTER to return to the menu"
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
      /home/joinmarket/menu.offerbook.sh
      /home/joinmarket/menu.sh
      ;;
  CONFIG)
      /home/joinmarket/install.joinmarket.sh config
      errorOnInstall=$?
      if [ ${errorOnInstall} -gt 0 ]; then
        DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
          --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
      fi
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
            exit 0;
            ;;            
esac
