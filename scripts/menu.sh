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
HEIGHT=26
WIDTH=52
CHOICE_HEIGHT=20
BACKTITLE=""
TITLE="JoininBox"
MENU="Choose from the options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  INFO "Show the address list and balances" \
  GEN "Generate a new wallet" \
  QTGUI "Show how to open the JoinMarketQT GUI" \
  "" ""
  MAKER "Run the Yield Generator" \
  YGCONF "Configure the Yield Generator" \
  MONITOR "Monitor the YG service" \
  YGLIST "List the past YG activity"\
  STOP "Stop the YG service" \
  "" ""
  HISTORY "Show all past transactions" \
  OFFERS "Watch the offer book locally" \
  "" ""
  CONFIG "Edit the joinmarket.cfg" \
  #CONNECT "Connect to a remote bitcoind"
  IMPORT "Copy wallet(s) from a remote node"\
  RECOVER "Restore a wallet from the seed" \
  UPDATE "Update the JoininBox scripts and menu" \
  X "Exit to the Command Line" \
  #EMPTY "Empty a mixdepth" \
  #PAY "Pay to an address using coinjoin" \
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
        GEN)
            clear
            echo ""
            . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
            if [ ${RPCoverTor} = on ];then 
              torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
            else
              python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
            fi
            echo "Type: 'menu' and press ENTER to return to the menu"
            ;;
        QTGUI)
            /home/joinmarket/info.qtgui.sh
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        MAKER)
            /home/joinmarket/get.password.sh
            source /home/joinmarket/joinin.conf
            /home/joinmarket/start.service.sh yg-privacyenhanced $wallet
            echo ""
            echo "Started the Yield Generator in the background"
            echo ""
            echo "Showing the systemd status ..."
            sleep 3
            dialog \
            --title "Monitoring the Yield Generator - press CTRL+C to exit"  \
            --prgbox "sudo journalctl -fn20 -u yg-privacyenhanced" 30 140
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        YGCONF)
            /home/joinmarket/set.conf.sh /home/joinmarket/joinmarket-clientserver/scripts/yg-privacyenhanced.py
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh        
            ;;
        MONITOR)
            dialog \
            --title "Monitoring the Yield Generator - press CTRL+C to exit"  \
            --prgbox "sudo journalctl -fn40 -u yg-privacyenhanced" 40 140
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;            
        YGLIST)
            dialog \
            --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
            --prgbox "column $HOME/.joinmarket/logs/yigen-statement.csv -t -s ","" 100 140
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        STOP)
            sudo systemctl stop yg-privacyenhanced
            sudo systemctl disable yg-privacyenhanced
            # check for failed services
            # sudo systemctl list-units --type=service
            sudo systemctl reset-failed
            echo "Stopped the Yield Generator background service"
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        HISTORY)
            /home/joinmarket/start.script.sh wallet-tool history
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
            /home/joinmarket/menu.sh
            ;;
        CONFIG)
            /home/joinmarket/install.joinmarket.sh
            errorOnInstall=$?
            if [ ${errorOnInstall} -eq 0 ]; then
              dialog --title "Installed JoinMarket" \
                --msgbox "\n Saved the joinmarket.conf" 7 56
            else 
              DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
                --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
            fi
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        CONNECT) 
            ;;
        IMPORT) 
            /home/joinmarket/info.importwallet.sh
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        RECOVER)
            echo ""
            . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
            if [ ${RPCoverTor} = on ];then 
              torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
            else
              python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
            fi
            echo "Type: 'menu' and press ENTER to return to the menu"
            ;;
        UPDATE)
            ./update.joininbox.sh
            echo "Returning to the menu..."
            sleep 2
            /home/joinmarket/menu.sh
            ;;
        EMPTY)
            ;;
        PAY)
            ;;            
        TUMBLER)
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
