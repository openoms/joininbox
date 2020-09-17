#!/bin/bash

# SHORTCUT COMMANDS for the user 'joinmarket'

# command: menu
# calls directly the main menu
function menu() {
  $HOME/menu.sh
}

# command: torthistx
function torthistx() {
  if [ "$(cat /home/joinmarket/joinin.conf 2>/dev/null | grep -c "runBehindTor=on")" -eq 1 ]; then
    echo ""
    echo "Broadcasts a transaction through Tor to Blockstream's API and into the network..."
    echo ""
    echo "Transaction ID:"
    curl --socks5-hostname localhost:9050 -d "$1" -X POST http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/tx
  else
    echo "Not running behind Tor"
  fi
}
# command: fees
# shows the fees earned as a Maker
function fees() {
  $HOME/info.feereport.sh
}