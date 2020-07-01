#!/bin/bash

# SHORTCUT COMMANDS for the user 'joinmarket' from terminal

# command: menu
# calls directly the main menu
function menu() {
  cd /home/joinmarket
  ./menu.sh
}

# command: torthistx
function torthistx() {
  if [ $(cat /home/joinmarket/joinin.conf 2>/dev/null | grep -c "runBehindTor=on") -eq 1 ]; then
    echo ""
    echo "Broadcasts a transaction through Tor to Blockstream's API and into the network..."
    echo ""
    echo "Transaction ID:"
    curl --socks5-hostname localhost:9050 -d $1 -X POST http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/tx
  else
    echo "Not running behind Tor"
  fi
}
