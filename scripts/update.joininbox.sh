#!/bin/bash

sudo rm -rf /home/joinmarket/joininbox
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git

sudo -u joinmarket cp ./joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp ./joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
