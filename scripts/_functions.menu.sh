#!/bin/bash

# repeatedly used menu items as functions

# paths
walletPath="/home/joinmarket/.joinmarket/wallets/"
JMcfgPath="/home/joinmarket/.joinmarket/joinmarket.cfg"
joininConfPath="/home/joinmarket/joinin.conf"

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

function menu_resetJMconfig {
  dialog --backtitle "Reset the joinmarket.cfg" \
  --title "Reset the joinmarket.cfg" \
  --yesno "
A new JoinMarket version might introduce new options and changed defaults.
It is best to reset the joinmarket.cfg after every install.
(can be done any time from the menu CONFIG -> RESET)

Do you want to reset the joinmarket.cfg to the defaults now?
" 12 65
  # make decision
  pressed=$?
  case $pressed in
    0)
      echo "# Removing the joinmarket.cfg"
      rm -f $JMcfgPath
      generateJMconfig;;
    1)
      echo "Cancelled"
      exit 1;;
    255)
      echo "ESC pressed."
      exit 1;;
  esac
}

function menu_connectLocalCore {
dialog --backtitle "Connect to the local Bitcoin Core" \
--title "Connect to the local Bitcoin Core" \
--yesno "
Do you want to connect to the local Bitcoin Core on mainnet now?" 7 55
  # make decision
  pressed=$?
  case $pressed in
    0)
      connectLocalNode mainnet
      sudo systemctl start bitcoind
      showBitcoinLogs;;
    1)
      echo "Cancelled"
      exit 1;;
    255)
      echo "ESC pressed."
      exit 1;;
  esac
}