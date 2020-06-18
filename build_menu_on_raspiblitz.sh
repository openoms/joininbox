#!/bin/bash

# make sure joinmarket is installed
if [ -f /home/admin/config.scripts/bonus.joinmarket.sh ]; then 
  sudo /home/admin/config.scripts/bonus.joinmarket.sh on
else
  echo "The JoinMarket install script was not found"
  echo "Update RaspiBlitz to v1.5 first"
  exit 1
fi

# add the joininbox menu
sudo rm -rf /home/joinmarket/joininbox
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git /home/joinmarket/joininbox
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
sudo chmod +x /home/joinmarket/*.sh

# joinin.conf settings
sudo -u joinmarket touch /home/joinmarket/joinin.conf
# tor config
# add default value to joinin.conf if needed
checkTorEntry=$(sudo -u joinmarket cat /home/joinmarket/joinin.conf | grep -c "runBehindTor")
if [ ${checkTorEntry} -eq 0 ]; then
  echo "runBehindTor=off" | sudo -u joinmarket tee -a /home/joinmarket/joinin.conf
fi
checkAllowOutboundLocalhost=$(sudo cat /etc/tor/torsocks.conf | grep -c "AllowOutboundLocalhost 1")
if [ ${checkAllowOutboundLocalhost} -eq 0 ]; then
  echo "AllowOutboundLocalhost 1" | sudo tee -a /etc/tor/torsocks.conf
  sudo systemctl restart tor
fi

# setting value in joinin config
checkBlitzTorEntry=$(cat /mnt/hdd/raspiblitz.conf | grep -c "runBehindTor=on")
if [ ${checkBlitzTorEntry} -gt 0 ]; then
  sudo -u joinmarket sed -i "s/^runBehindTor=.*/runBehindTor=on/g" /home/joinmarket/joinin.conf
fi

# autostart for joininbox
echo "
if [ -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
  . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
  /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c \"import PySide2\"
  cd /home/joinmarket/joinmarket-clientserver/scripts/
fi
# shortcut commands
source /home/joinmarket/_commands.sh
# automatically start main menu for joinmarket unless
# when running in a tmux session
if [ -z \"\$TMUX\" ]; then
  /home/joinmarket/menu.sh
fi
clear

Welcome to the JoininBox command line!

Notes on usage:
https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md

To open JoininBox menu use: menu

To exit to the RaspiBlitz menu use: exit
" | sudo -u joinmarket tee -a /home/joinmarket/.bashrc
