#!/bin/bash

source joinin.conf

script="$1"
wallet="$2"

echo ""
echo "Making sure $script not running"
echo ""
sudo systemctl stop $script
sudo systemctl disable $script

if [ $script == "yg-privacyenhanced" ]; then 
  rm -f ~/.joinmarket/wallets/$wallet.jmdat.lock
fi

if [ ${RPCoverTor} = on ];then 
  tor="torify"
else
  tor=""
fi

startScript="cat /home/joinmarket/.pw | $tor python $script.py $wallet.jmdat --wallet-password-stdin"

echo "
[Unit]
Description=$script

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c '. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate && $startScript'
User=joinmarket
Group=joinmarket
Type=simple
KillMode=process
TimeoutSec=600
Restart=no

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/$script.service 1>/dev/null

echo ""
echo "Starting the systemd service: $script"
echo ""

sudo systemctl enable $script
sudo systemctl start $script

echo ""
echo "Shredding the password once used..."
echo ""

sleep 5
# delete password once used
shred -uvz /home/joinmarket/.pw