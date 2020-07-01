#!/bin/bash

source /home/joinmarket/joinin.conf

script="$1"
wallet="$2"

echo ""
echo "Making sure $script not running"
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

startScript="cat /home/joinmarket/.pw | $tor python $script.py $wallet \
--wallet-password-stdin"
# display
echo "
Running the command with systemd:
$tor python $script.py $wallet"

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

echo "
Starting the systemd service: $script
"

sudo systemctl enable $script
sudo systemctl start $script

echo "
Shredding the password once used...
"

sleep 5
# delete password once used
shred -uvz /home/joinmarket/.pw
