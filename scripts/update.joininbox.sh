#!/bin/bash
sudo rm -rf /home/joinmarket/joininbox
# sudo -u joinmarketgit clone https://github.com/openoms/joininbox.git
sudo -u joinmarket mkdir /home/joinmarket/joininbox
sudo -u joinmarket mkdir /home/joinin/joininbox/scripts/
sudo cp ./scripts/* /home/joinin/joininbox/scripts/
sudo chown -R joinmarket:joinmarket /home/joinmarket/joininbox/*

sudo rm -f /home/joinin/*.sh
sudo rm -f /home/joinin/*.py

sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
