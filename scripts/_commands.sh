#!/bin/bash

# SHORTCUT COMMANDS for the user 'joinmarket'

# command: menu
# calls directly the main menu
function menu() {
  /home/joinmarket/menu.sh
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

# command: stats
# shows the uptime and the fees earned as a Maker
function stats() {
  /home/joinmarket/info.stats.sh
}

# command: qtgui
# starts the JoinMarket-QT GUI
function qtgui() {
  echo "# opening the JoinMarket-QT GUI with the command: '(jmvenv) python joinmarket-qt.py'"
  /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python /home/joinmarket/joinmarket-clientserver/scripts/joinmarket-qt.py
}

# command: qr [string]
# shows a QR code from the string
function qr() {
  if [ ${#$1} -eq 0 ]; then
    echo "# Error='missing string'"
  fi
  echo
  echo "Displaying the text:"
  echo "$1"
  echo
  qrencode -t ANSIUTF8 "${$1}"
  echo "(To shrink QR code: MacOS press CMD- / Linux press CTRL-)"
  echo
}

alias signet-cli="/home/joinmarket/bitcoin/bitcoin-cli -signet"
alias signetd="/home/joinmarket/bitcoin/bitcoind -signet"
