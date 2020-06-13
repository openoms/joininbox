#!/bin/bash

SCRIPT="$1"
WALLET="$2"

sudo systemctl stop $SCRIPT
sudo systemctl disable $SCRIPT 2>/dev/null

if [ $SCRIPT == "yg-privacyenhanced" ]; then 
  rm -f ~/.joinmarket/wallets/$WALLET.jmdat.lock
fi

source joinin.conf

if [ ${RPCoverTor} = on ];then 
  startScript="start.script.tor.py"
else
  startScript="start.script.py"
fi

echo "
[Unit]
Description=$SCRIPT

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c '. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
 python $HOME/$startScript $SCRIPT $WALLET'
User=joinmarket
Group=joinmarket
Type=simple
KillMode=process
TimeoutSec=600
Restart=no

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/$SCRIPT.service 1>/dev/null

sudo systemctl enable $SCRIPT 2>/dev/null
sudo systemctl start $SCRIPT