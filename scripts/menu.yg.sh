#!/bin/bash

# YG menu options

source /home/joinmarket/joinin.conf

# cd ~/bin/joinmarket-clientserver && source jmvenv/bin/activate && cd scripts

# BASIC MENU INFO
HEIGHT=13
WIDTH=52
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="Yield Generator options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  MAKER "Run the Yield Generator" \
  YGCONF "Configure the Yield Generator" \
  MONITOR "Monitor the YG service" \
  YGLIST "List the past YG activity"\
  LOGS "View the last YG logfile"
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
            /home/joinmarket/get.password.sh
            source /home/joinmarket/joinin.conf
            echo "Using wallet: $wallet"
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
            sleep 1
            ./menu.sh
            ;;
        YGCONF)
            /home/joinmarket/set.conf.sh /home/joinmarket/joinmarket-clientserver/scripts/yg-privacyenhanced.py
            echo "Returning to the menu..."
            
            ./menu.sh        
            ;;
        MONITOR)
            dialog \
            --title "Monitoring the Yield Generator"  \
            --msgbox "
Will show the logs using:

sudo journalctl -fn40 -u yg-privacyenhanced

Press CTRL+C to exit and return to the menu." 10 50

            sudo journalctl -fn40 -u yg-privacyenhanced
            echo "Press ENTER to return to menu"
            read key
            ./menu.sh
            ;;            
        YGLIST)
            dialog \
            --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
            --prgbox "column $HOME/.joinmarket/logs/yigen-statement.csv -t -s ","" 100 140
            echo "Returning to the menu..."
            sleep 1
            ./menu.sh
            ;;
        LOGS)
            dialog \
            --title "Monitoring the Yield Generator"  \
            --msgbox "
Will tail the latest YG logfile from:

/home/joinmarket/.joinmarket/logs/

Press CTRL+C to exit and return to the menu." 10 50

            ls -t /home/joinmarket/.joinmarket/logs | grep J5 | head -n 1 | xargs tail -fn1000
            echo "Press ENTER to return to menu"
            read key
            ./menu.sh
            ;;            
        STOP)
            # stop the background process (equivalent to CTRL+C)
            # use wallet from joinin.conf
            pkill -sigint -f "python yg-privacyenhanced.py $wallet --wallet-password-stdin"
            # remove the service
            sudo systemctl stop yg-privacyenhanced
            sudo systemctl disable yg-privacyenhanced
            # check for failed services
            # sudo systemctl list-units --type=service
            sudo systemctl reset-failed
            echo "Stopped the Yield Generator background service"
            echo "Returning to the menu..."
            sleep 1
            ./menu.sh
            ;;
esac