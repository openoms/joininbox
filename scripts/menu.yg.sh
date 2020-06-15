#!/bin/bash

# YG menu options

source /home/joinmarket/joinin.conf

# cd ~/bin/joinmarket-clientserver && source jmvenv/bin/activate && cd scripts

# BASIC MENU INFO
HEIGHT=12
WIDTH=52
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="Choose from the options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  MAKER "Run the Yield Generator" \
  YGCONF "Configure the Yield Generator" \
  MONITOR "Monitor the YG service" \
  YGLIST "List the past YG activity"\
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
            ./menu.sh
            ;;
        YGCONF)
            /home/joinmarket/set.conf.sh /home/joinmarket/joinmarket-clientserver/scripts/yg-privacyenhanced.py
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh        
            ;;
        MONITOR)
            dialog \
            --title "Monitoring the Yield Generator - press CTRL+C to exit"  \
            --prgbox "sudo journalctl -fn40 -u yg-privacyenhanced" 40 140
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh
            ;;            
        YGLIST)
            dialog \
            --title "timestamp            cj amount/satoshi  my input count  my input value/satoshi  cjfee/satoshi  earned/satoshi  confirm time/min  notes"  \
            --prgbox "column $HOME/.joinmarket/logs/yigen-statement.csv -t -s ","" 100 140
            echo "Returning to the menu..."
            sleep 2
            ./menu.sh
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
            ./menu.sh
            ;;
esac