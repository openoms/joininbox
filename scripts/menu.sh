#!/bin/bash

if [ $(dialog | grep -c "ComeOn Dialog!") -eq 0 ]; then
  sudo apt install dialog
fi
if [ -f joinin.conf ]; then
  touch joinin.conf
fi
source joinin.conf

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
  INFO "Show the address list and balance" \
  #PAY "Pay to an address using coinjoin" \
  #TUMBLER "Run the Tumbler to mix quickly" \
  YG "Run the Yield Generator" \
  #MONITOR "Monitor the Yield Generator" \
  YG_LIST "List the past YG activity"
  "" ""
  #HISTORY "Show the past transactions" \
  OBWATCH "Watch the offer book locally" \
  #EMPTY "Empty a mixdepth" \
  "" ""
  YG_CONF "Configure the Yield Generator" \
  STOP "Stop the Yield Generator" \
  "" ""
  #GEN "Generate a new wallet" \
  IMPORT "Copy wallet(s) from a remote node"
  #RESTORE "Restore a wallet from the seed" \
  "" ""
  INSTALL "Install and configure JoinMarket" \
  UPDATE "Update the JoininBox scripts and menu" \
  X "Exit to the Command Line" \
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
            ./getpw.sh
            source joinin.conf
            clear
            echo "Decrypting the wallet $wallet.jmdat . . ."
            echo ""
            echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
            . /home/joinin/joinmarket-clientserver/jmvenv/bin/activate
            python /home/joinin/scriptstarter.py wallet-tool $wallet
            ./menu.sh
            ;;
        PAY)
            ;;            
        TUMBLER)
            ;;
        YG)
            ./getpw.sh
            source joinin.conf
            ./servicemaker.sh yg-privacyenhanced $wallet
            echo "Starting the Yield Generator in the background.."
            sleep 5
            echo ""
            echo "Exit to the command line by pressing CTRL+C"
            echo "" 
#            dialog \
#            --title "Monitoring the Yield Generator"  \
#            --prgbox "tail -f yg-privacyenhanced.log" 20 140
            ./menu.sh
            ;;
        MONITOR)
            # TODO check if active with ?systemctl
            dialog \
            --title "Monitoring the Yield Generator"  \
            --prgbox "tail -f yg-privacyenhanced.log" 20 140
            ./menu.sh
            ;;            
        YG_LIST)
            dialog \
            --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
            --prgbox "column $HOME/joinmarket-clientserver/scripts/logs/yigen-statement.csv -t -s ","" 20 140
            ./menu.sh
            ;;
        HISTORY)
            ;;
        OBWATCH)
            #TODO show hidden service only if already running
            ./start.ob-watcher.sh
            errorOnInstall=$?
            if [ ${errorOnInstall} -eq 0 ]; then
              TOR_ADDRESS=$(sudo cat /mnt/hdd/tor/ob-watcher/hostname)
              dialog --title "Started the ob-watcher service" \
                --msgbox "\nVisit the address in the Tor Browser:\n$TOR_ADDRESS" 8 56
            else 
              DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
                --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
            fi
            ./menu.sh
            ;;
        EMPTY)
            ;;
        YG_CONF)
            dialog \
            --title "Editing the yg-privacyenhanced.py" \
            --editbox  "/home/joinin/joinmarket-clientserver/scripts/yg-privacyenhanced.py" 200 200 2>_temp
            cat _temp > /home/joinin/joinmarket-clientserver/scripts/yg-privacyenhanced.py
            ./menu.sh            
            ;;
        STOP)
            sudo systemctl stop yg-privacyenhanced
            ./menu.sh
            ;;
        GEN)
            ;;
        IMPORT) 
            ./wallet.import.sh
            ./menu.sh
            ;;
        RESTORE)
            ;;
        INSTALL)
            ./install.joinmarket.sh
            errorOnInstall=$?
            if [ ${errorOnInstall} -eq 0 ]; then
              dialog --title "Installed JoinMarket" \
                --msgbox "\nContinue from the menu or the command line " 7 56
            else 
              DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
                --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
            fi
            ./menu.sh
            ;;
        UPDATE)
            ./update.joininbox.sh
            ./menu.sh
            ;;
        X)
            clear
            echo "***********************************"
            echo "* JoinBox Commandline"
            echo "***********************************"
            echo "Refer to the documentation about how to get started and much more:"
            echo "https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/README.md"
            echo ""
            echo "To return to main menu use the command: menu"
            echo ""
            exit 1;
            ;;            
esac
