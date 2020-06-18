#!/bin/bash

echo "Removing the joininbox directory.."
echo ""
sudo rm -rf /home/joinmarket/joininbox
echo ""
echo "Cloning the latest state from https://github.com/openoms/joininbox"
echo ""
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git
echo ""
echo "Copy the scripts in place"
echo ""
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
sudo -u joinmarket chmod +x /home/joinmarket/*.sh
