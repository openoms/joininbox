#!/bin/bash

# YG menu options
source /home/joinmarket/menu.functions.sh
source /home/joinmarket/joinin.conf

# BASIC MENU INFO
HEIGHT=15
WIDTH=52
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="
Yield Generator options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  MAKER "Run the Yield Generator" \
  YGCONF "Configure the Yield Generator" \
  YGLIST "List the past YG activity" \
  NICKNAME "Show the last used counterparty name" \
  SERVICE "Monitor the YG service (INFO)" \
  LOGS "View the last YG logfile (DEBUG)" \
  STOP "Stop the YG service" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in

        MAKER)
            # wallet
            chooseWallet
            # get password
            passwordToFile
            echo "Using the wallet: $(cat $wallet)"
            /home/joinmarket/start.service.sh yg-privacyenhanced $(cat $wallet)
            echo ""
            echo "Started the Yield Generator in the background"
            echo ""
            echo "Showing the systemd status ..."
            sleep 3
            dialog \
            --title "Monitoring the Yield Generator - press CTRL+C to exit"  \
            --prgbox "sudo journalctl -fn20 -u yg-privacyenhanced" 30 140
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.yg.sh
            ;;
        YGCONF)
            /home/joinmarket/set.conf.sh /home/joinmarket/joinmarket-clientserver/scripts/yg-privacyenhanced.py
            echo "Returning to the menu..."
            /home/joinmarket/menu.yg.sh        
            ;;
        YGLIST)
            dialog \
            --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
            --prgbox "column $HOME/.joinmarket/logs/yigen-statement.csv -t -s ","" 100 140
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.yg.sh
            ;;
        NICKNAME)
            name=$(ls -t /home/joinmarket/.joinmarket/logs | grep J5 | head -n 1 | cut -c -16)
            whiptail \
            --title "Counterparty name"  \
            --msgbox "The last used counterparty name for the offer book:\n
$name\n
Check if active in:
https://joinmarket.me/ob" 12 55
            echo "Returning to the menu..."
            sleep 1
            /home/joinmarket/menu.yg.sh
            ;;
        SERVICE)
            dialog \
            --title "Monitoring the Yield Generator"  \
            --msgbox "
Will show the INFO logs using:

sudo journalctl -fn40 -u yg-privacyenhanced

Press CTRL+C to exit to the command line.
Use: 'menu' for the JoininBox options." 11 50
            sudo journalctl -fn40 -u yg-privacyenhanced
            /home/joinmarket/menu.yg.sh
            ;;                      
        LOGS)
            dialog \
            --title "Monitoring the Yield Generator"  \
            --msgbox "
Will tail the latest YG logfile from:

/home/joinmarket/.joinmarket/logs/

Press CTRL+C to exit and return to the menu." 10 50
            cd /home/joinmarket/.joinmarket/logs 
            ls -t | grep J5 | head -n 1 | xargs tail -fn1000
            echo "Press ENTER to return to menu"
            read key
            cd /home/joinmarket/joinmarket-clientserver/scripts/
            /home/joinmarket/menu.yg.sh
            ;;            
        STOP)
            # stop the background process (equivalent to CTRL+C)
            # use wallet from joinin.conf
            pkill -sigint -f "python yg-privacyenhanced.py $wallet --wallet-password-stdin"
            # pgrep python | xargs kill -sigint 
            # remove the service
            sudo systemctl stop yg-privacyenhanced
            sudo systemctl disable yg-privacyenhanced
            # check for failed services
            # sudo systemctl list-units --type=service
            sudo systemctl reset-failed
            echo "Stopped the Yield Generator background service"
            echo "Press ENTER to return to the menu..."
            read key
            ;;
esac
