#!/bin/bash

sudo rm -rf /home/joinmarket/joininbox
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git

sudo rm -f /home/joinmarket/*.sh
sudo rm -f /home/joinmarket/*.py

sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
