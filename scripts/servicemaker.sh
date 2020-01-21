#!/bin/bash

SCRIPT="$1"
WALLET="$2"

echo "
[Unit]
Description=$SCRIPT

[Service]
ExecStart=python /home/joinin/joininbox/scripts/scriptstarter.py $SCRIPT.py $WALLET.jmdat
User=joinin
Group=joinin
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