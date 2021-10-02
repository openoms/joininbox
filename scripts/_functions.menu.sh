#!/bin/bash

# repeatedly used menu items as functions

function menu_GEN() {
  clear
  echo 
  . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
  if [ "${RPCoverTor}" = "on" ]; then 
    torsocks python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
  else
    python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
  fi
  echo
  echo "Press ENTER to return to the menu"
  read key
}

function menu_MAKER() {
  # wallet
  chooseWallet noLockFileCheck
  # save wallet in conf
  sudo sed -i "s#^YGwallet=.*#YGwallet=$(cat $wallet)#g" $joininConfPath
  # get password
  passwordToFile
  echo "# Using the wallet: $(cat $wallet)"
  /home/joinmarket/start.service.sh yg-privacyenhanced $(cat $wallet)
  echo
  echo "# started the Yield Generator in the background"
  echo
  echo "# showing the systemd status ..."
  sleep 3
  dialog \
  --title "Monitoring the Yield Generator - press CTRL+C to exit"  \
  --prgbox "sudo journalctl -fn20 -u yg-privacyenhanced" 30 200
  echo "# returning to the menu..."
  sleep 1
  /home/joinmarket/menu.yg.sh
}

function menu_DISPLAY() {
  checkRPCwallet
  # wallet
  chooseWallet noLockFileCheck
  /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)"
  echo
  echo "Fund the wallet on addresses labeled 'new' to avoid address reuse."
  echo
  echo "Press ENTER to return to the menu..."
  read key
  /home/joinmarket/menu.sh
}