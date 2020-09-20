#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/menu.functions.sh

function stopOfferBook() {
echo "Stopping the ob-watcher background service"
pkill -sigint -f "python ob-watcher.py"
sudo systemctl stop ob-watcher
sudo systemctl disable ob-watcher 2>/dev/null
}

function showOfferBookAddress() {
running=$(ps $(pidof python) | grep -c "python ob-watcher.py")
if [ "$running" -gt 0 ]; then  
  TOR_ADDRESS=$(sudo cat "$HiddenServiceDir"/ob-watcher/hostname)
  clear
  echo ""
  echo "The local Offer book instance is running"
  echo ""
  echo "Visit the address in the Tor Browser:"
  echo "$TOR_ADDRESS"
else
  startOfferBook
fi 
}

function startOfferBook() {
echo "# Checking matplotlib"
. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
depend=$(pip show matplotlib | grep -c "matplotlib")
if [ "$depend" -lt 1 ]; then
  pip install matplotlib
else
  echo "matplotlib is installed"
fi

stopOfferBook

echo "
[Unit]
Description=ob-watcher

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/obwatch
ExecStart=/bin/sh -c \
'. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate && \
python ob-watcher.py'
User=joinmarket
Group=joinmarket
Type=simple
KillMode=process
TimeoutSec=600
Restart=no

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/ob-watcher.service 1>/dev/null
sudo systemctl enable ob-watcher 2>/dev/null
sudo systemctl start ob-watcher

# create the Hidden Service
/home/joinmarket/install.hiddenservice.sh ob-watcher 80 62601

echo ""
echo "Started watching the Offer Book in the background"
echo ""
echo "Showing the systemd status ..."
sleep 3
dialog \
--title "Monitoring the ob-watcher - press CTRL+C to exit"  \
--prgbox "sudo journalctl -fn20 -u ob-watcher" 30 140
}

# BASIC MENU INFO
HEIGHT=11
WIDTH=48
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="
Offer Book options:"
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  START "Start watching locally" \
  SHOW "Show the local Offer Book address" \
  STOP "Stop the background process"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  START)
      startOfferBook
      showOfferBookAddress
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;
  SHOW)
      showOfferBookAddress
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;              
  STOP)
      stopOfferBook
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;        
esac