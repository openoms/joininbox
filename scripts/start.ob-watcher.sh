#!/bin/bash

#install dependency
. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate

echo "installing matplotlib"
pip install matplotlib

SCRIPT="ob-watcher"

sudo systemctl stop $SCRIPT
sudo systemctl disable $SCRIPT 2>/dev/null

source joinin.conf

if [ ${RPCoverTor} = on ];then 
  tor="torify"
else
  tor=""
fi

echo "
[Unit]
Description=$SCRIPT

[Service]
WorkingDirectory=/home/joinmarket/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c '. /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&\
 $tor python /home/joinmarket/joinmarket-clientserver/scripts/obwatch/ob-watcher.py'
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

#create Hidden Service
./install.hiddenservice.sh ob-watcher 80 62601