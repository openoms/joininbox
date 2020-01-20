#!/bin/bash

SCRIPT="$1"
WALLET="$2"

echo "
[Unit]
Description=$SCRIPT

[Service]
ExecStart=python /home/jm/joinmarket-clientserver/scripts/t2.py $SCRIPT.py $WALLET.jmdat
User=jm
Group=jm
Type=simple
KillMode=process
TimeoutSec=60
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/$SCRIPT.service
    sudo systemctl enable $SCRIPT
    sudo systemctl start $SCRIPT