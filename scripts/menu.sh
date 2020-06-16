#!/bin/bash

if [ $(dialog | grep -c "ComeOn Dialog!") -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f joinin.conf ]; then
  touch joinin.conf
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
            ./menu.wallet.sh
            ./menu.sh          
            ;;
        QTGUI)
            /home/joinmarket/info.qtgui.sh
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh
            ;;
        MAKER)
            ./menu.yg.sh
            ./menu.sh           
            ;;
        PAY)
            ./menu.pay.sh
            echo ""
            echo "Type: 'menu' and press ENTER to return to the menu"
            ;;
        CONTROL)
            wallet=$(tempfile 2>/dev/null)
            dialog --backtitle "Choose a wallet" \
            --title "Choose a wallet by typing the full name of the file" \
            --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
            mixdepth=$(tempfile 2>/dev/null)
            dialog --backtitle "Choose a mixdepth" \
            --inputbox "Type a number between 0 to 4 to choose the mixdepth" 8 60 2> $mixdepth
            echo "Run the following command manually to use the freeze method:

python ~/joinmarket-clientserver/scripts/wallet-tool.py -m$(cat $mixdepth) $(cat $wallet) freeze

type 'menu' and press ENTER to return to the menu
"     
            # unlocking through stdin does not work with the freeze method:
            # https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/598
            # /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) freeze $(cat $mixdepth)
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
            sleep 2
            ./menu.sh
            ;;
        CONFIG)
            /home/joinmarket/install.joinmarket.sh
            errorOnInstall=$?
            if [ ${errorOnInstall} -gt 0 ]; then
              DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
                --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
            fi
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh
            ;;
        CONNECT) 
            ;;
        UPDATE)
            ./update.joininbox.sh
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh
            ;;
        X)
            clear
            echo "***********************************"
            echo "* JoininBox Commandline"
            echo "***********************************"
            echo "Refer to the documentation about how to get started and much more:"
            echo "https://github.com/openoms/bitcoin-tutorials/tree/master/joinmarket"
            echo ""
            echo "To return to main menu use the command: menu"
            echo ""
            exit 1;
            ;;            
esac
