#!/bin/bash

source joinin.conf

script="$1"
wallet="$2"

sudo systemctl stop $script
sudo systemctl disable $script

if [ $script == "yg-privacyenhanced" ]; then 
  rm -f ~/.joinmarket/wallets/$wallet.jmdat.lock
fi

if [ ${RPCoverTor} = on ];then 
  startScript="cat /home/joinmarket/.pw | torify python $script.py $wallet.jmdat --wallet-password-stdin"
else
  startScript="cat /home/joinmarket/.pw | python $script.py $wallet.jmdat --wallet-password-stdin"
fi

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

sudo systemctl enable $script
sudo systemctl start $script

