#!/bin/bash

# source aliases from /home/joinmarket/_aliases.sh
if [ -f /home/joinmarket/_aliases.sh ]; then
  source /home/joinmarket/_aliases.sh
fi

# SHORTCUT COMMANDS for the user 'joinmarket'

# command: menu
# calls directly the main menu
function menu() {
  /home/joinmarket/menu.sh
}

# command: newnym
function newnym() {
  if [ "$(cat /home/joinmarket/joinin.conf 2>/dev/null | grep -c "runBehindTor=on")" -eq 1 ]; then
    echo "# Changing Tor circuits..."
    echo "# Savind old ID..."
    oldID=$(curl --connect-timeout 15 --socks5-hostname 127.0.0.1:9050 ifconfig.me 2>/dev/null)
    echo "# Requesting new identity ..."
    sudo -u debian-tor python3 /home/joinmarket/tor.newnym.py
    sleep 3
    echo "# Savind new ID..."
    newID=$(curl --connect-timeout 15 --socks5-hostname 127.0.0.1:9050 ifconfig.me 2>/dev/null)
    echo
    if [ ${oldID} = ${newID} ]; then
      echo "# FAIL: Identity did not change. Read error message above."
      echo "# Exiting for precaution."
      exit 0
    else
      echo "# SUCCESS"
      echo "# Old id: " ${oldID}
      echo "# New id: " ${newID}
    fi
  else
    echo "# Not running behind Tor"
  fi
}

# command: torthistx
function torthistx() {
  if [ "$(cat /home/joinmarket/joinin.conf 2>/dev/null | grep -c "runBehindTor=on")" -eq 1 ]; then
    echo
    if [ "$(cat /home/joinmarket/joinin.conf 2>/dev/null | grep -c "network=signet")" -eq 1 ]; then
      newnym
      echo
      echo "# Broadcasts a transaction through Tor to Blockstream's API and into the network..."
      echo
      echo "# Transaction ID:"
      curl --socks5-hostname localhost:9050 -d "$1" -X POST https://mempool.space/signet/api/tx
    else
      echo "# Broadcasts a transaction through Tor to Blockstream's API and into the network..."
      echo
      echo "# Transaction ID:"
      curl --socks5-hostname localhost:9050 -d "$1" -X POST http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/tx
    fi
  else
    echo "# Not running behind Tor"
  fi
}

# command: stats
# shows the uptime and the fees earned as a Maker
function stats() {
  /home/joinmarket/info.stats.sh showAllEarned
}

# command: qtgui
# starts the JoinMarket-QT GUI
function qtgui() {
  if grep -Eq "RPCoverTor=on" /home/joinmarket/joinin.conf; then
    tor="torsocks"
  else
    tor=""
  fi

  echo "# Opening the JoinMarket-QT GUI with the command: '(jmvenv) $tor python joinmarket-qt.py'"
  $tor /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python /home/joinmarket/joinmarket-clientserver/scripts/joinmarket-qt.py
}

# command: qr [string]
# shows a QR code from the string
function qr() {
  if [ ${#1} -eq 0 ]; then
    echo "# Error='missing string'"
  fi
  echo
  echo "Displaying the text:"
  echo "$1"
  echo
  qrencode -t ANSIUTF8 "${1}"
  echo "(To shrink QR code: MacOS press CMD- / Linux press CTRL-)"
  echo
}

alias signet-cli="/home/joinmarket/bitcoin/bitcoin-cli -signet"
alias signetd="/home/joinmarket/bitcoin/bitcoind -signet"
