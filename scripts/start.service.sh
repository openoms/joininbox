#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

script="$1"
wallet="$2"

echo
echo "# Making sure $script not running"
sudo systemctl stop $script
sudo systemctl disable $script

if [ $script == "yg-privacyenhanced" ]; then 
  # shut down the process gracefully
  pkill -sigint -f "python yg-privacyenhanced.py $wallet --wallet-password-stdin"
  # make sure the lock file is deleted 
  rm -f ~/.joinmarket/wallets/.$wallet.lock
  # for old version <v0.6.3
  rm -f ~/.joinmarket/wallets/$wallet.lock
fi

if [ ${RPCoverTor} = "on" ];then 
  tor="torify"
else
  tor=""
fi

startScript="cat /dev/shm/.pw | $tor python $script.py $wallet \
--wallet-password-stdin"
# display
walletFileName="${wallet//$walletPath/ }"
echo
echo "# Running the command with systemd:"
echo " $tor python $script.py $walletFileName"

echo "
[Unit]
Description=$script

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c \
'. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate && $startScript'
User=joinmarket
Group=joinmarket
Type=simple
KillMode=process
TimeoutSec=infinity
Restart=no

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/$script.service 1>/dev/null

echo
echo "# Starting the systemd service: $script"
echo

sudo systemctl enable $script
sudo systemctl start $script

echo
echo "# Shredding the password once used..."
echo

sleep 5
# delete password once used
shred -uvz /dev/shm/.pw
