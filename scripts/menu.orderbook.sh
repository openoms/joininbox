#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

function stopOrderBook() {
echo "# Stopping the ob-watcher background service"
pkill -sigint -f "python ob-watcher.py"
sudo systemctl stop ob-watcher
sudo systemctl disable ob-watcher 2>/dev/null
}

function showOrderBookAddress() {
running=$(ps $(pidof python) | grep -c "python ob-watcher.py")
if [ "$running" -gt 0 ]; then  
  TOR_ADDRESS=$(sudo cat "$HiddenServiceDir"/ob-watcher/hostname)
  clear
  echo ""
  echo "The local Order Book instance is running"
  echo ""
  echo "Visit the address in the Tor Browser:"
  echo "$TOR_ADDRESS"
else
  startOrderBook
fi 
}

function startOrderBook() {
stopOrderBook
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
echo "# Started watching the Order Book in the background"
echo ""
echo "# Showing the systemd status ..."
sleep 3
dialog \
--title "Monitoring the ob-watcher - press CTRL+C to exit"  \
--prgbox "sudo journalctl -fn20 -u ob-watcher" 30 200
}

# BASIC MENU INFO
HEIGHT=9
WIDTH=48
CHOICE_HEIGHT=20
TITLE="Order Book options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  START "Start watching locally" \
  SHOW "Show the local Order Book address" \
  STOP "Stop the background process"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Back" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  START)
      startOrderBook
      showOrderBookAddress
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;
  SHOW)
      showOrderBookAddress
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;              
  STOP)
      stopOrderBook
      echo ""            
      echo "Press ENTER to return to the menu..."
      read key
      ;;        
esac