#!/bin/bash

#install dependency
. /home/joinin/joinmarket-clientserver/jmvenv/bin/activate
pip install matplotlib

SCRIPT="ob-watcher"

sudo systemctl stop $SCRIPT
sudo systemctl disable $SCRIPT 2>/dev/null

echo "
[Unit]
Description=$SCRIPT

[Service]
WorkingDirectory=/home/joinin/joinmarket-clientserver/scripts/
ExecStart=/bin/sh -c '. /home/joinin/joinmarket-clientserver/jmvenv/bin/activate &&\
python /home/joinin/joinmarket-clientserver/scripts/obwatch/ob-watcher.py'
User=joinin
Group=joinin
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