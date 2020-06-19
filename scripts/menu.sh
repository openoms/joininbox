#!/bin/bash

if [ $(dialog | grep -c "ComeOn Dialog!") -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f joinin.conf ]; then
  touch /home/joinmarket/joinin.conf
fi

# add default value to joinin config if needed
if ! grep -Eq "^RPCoverTor=" joinin.conf; then
  echo "RPCoverTor=off" >> joinin.conf
fi

if grep -Eq "^rpc_host = .*.onion" /home/joinmarket/.joinmarket/joinmarket.cfg; then 
  echo "RPC over Tor is on"
  sudo sed -i "s/^RPCoverTor=.*/RPCoverTor=on/g" joinin.conf
else
  echo "RPC over Tor is off"
  sudo sed -i "s/^RPCoverTor=.*/RPCoverTor=off/g" joinin.conf
fi

source /home/joinmarket/joinin.conf

# cd ~/bin/joinmarket-clientserver && source jmvenv/bin/activate && cd scripts

# BASIC MENU INFO
HEIGHT=22
WIDTH=56
CHOICE_HEIGHT=20
BACKTITLE="JoininBox GUI"
TITLE="JoininBox"
MENU="Choose from the options:"
OPTIONS=()

# Basic Options
OPTIONS+=(\
  INFO "Show the address list and balances" \
  QTGUI "Show how to open the JoinMarketQT GUI" \
  "" ""
  WALLET "Wallet management options" \
  MAKER "Yield Generator options" \
  "" ""
  PAY "Pay to an address with/without a coinjoin" \
  CONTROL "Freeze/unfreeze UTXO-s in a mixdepth" \
  "" ""
  OFFERS "Watch the offer book locally" \
  "" "" 
  CONFIG "Edit the joinmarket.cfg" \
  UPDATE "Update the JoininBox scripts and menu" \
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
            /home/joinmarket/start.script.sh wallet-tool
            echo ""
            echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
            echo "Type: 'menu' and press ENTER to return to the menu"
            ;;
        WALLET)
            /home/joinmarket//menu.wallet.sh
            /home/joinmarket//menu.sh          
            ;;
        QTGUI)
            /home/joinmarket/info.qtgui.sh
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.sh
            ;;
        MAKER)
            /home/joinmarket/menu.yg.sh
            /home/joinmarket/menu.sh           
            ;;
        PAY)
            /home/joinmarket/menu.pay.sh
            echo ""
            echo "Type: 'menu' and press ENTER to return to the menu"
            ;;
        CONTROL)
            /home/joinmarket/menu.control.sh
            ;;
        OFFERS)
            #TODO show hidden service only if already running
            /home/joinmarket/start.ob-watcher.sh
            errorOnInstall=$?
            if [ ${errorOnInstall} -eq 0 ]; then
              TOR_ADDRESS=$(sudo cat $HiddenServiceDir/ob-watcher/hostname)
              whiptail --title "Started the ob-watcher service" \
                --msgbox "\nVisit the address in the Tor Browser:\n$TOR_ADDRESS" 9 66
            else 
              DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
                --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
            fi
            echo ""
            echo "Started watching the Offer Book in the background"
            echo ""
            echo "Showing the systemd status ..."
            sleep 3
            dialog \
            --title "Monitoring the ob-watcher - press CTRL+C to exit"  \
            --prgbox "sudo journalctl -fn20 -u ob-watcher" 30 140
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.sh
            ;;
        CONFIG)
            /home/joinmarket/install.joinmarket.sh
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
            /home/joinmarket/update.joininbox.sh
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.sh
            ;;
        X)
            clear
            echo "
***********************************
* JoinMarket command line
***********************************
Notes on usage:
https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md

To open JoininBox menu use: menu
To exit to the RaspiBlitz menu use: exit
"
            exit 0;
            ;;            
esac
