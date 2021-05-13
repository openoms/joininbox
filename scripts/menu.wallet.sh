#!/bin/bash

# WALLET menu options

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

checkRPCwallet

# BASIC MENU INFO
HEIGHT=16
WIDTH=52
CHOICE_HEIGHT=10
TITLE="Wallet management options"
BACKTITLE="Wallet management options"
MENU=""
OPTIONS=()

# Basic Options
OPTIONS+=(
  DISPLAY "Show the contents of all mixdepths"
  UTXOS "Show all the coins in the wallet"
  HISTORY "Show all past transactions"
  XPUBS "Show the master public keys"
  PSBT "Sign an externally prepared PSBT"
  GEN "Generate a new wallet"
  IMPORT "Copy wallet(s) from a remote node"
  RECOVER "Restore a wallet from the seed"
  RESCAN "Rescan the Bitcoin Core wallet"
  UNLOCK "Remove the lockfiles"
  )

CHOICE=$(dialog \
          --clear \
          --backtitle "$BACKTITLE" \
          --title "$TITLE" \
          --ok-label "Select" \
          --cancel-label "Back" \
          --menu "$MENU" \
            $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "${OPTIONS[@]}" \
            2>&1 >/dev/tty)

case $CHOICE in

  GEN)
    clear
    echo 
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    if [ "${RPCoverTor}" = "on" ]; then 
      torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
    else
      python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py generate
    fi
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  DISPLAY)
    menu_DISPLAY;;
  HISTORY)
    activateJMvenv
    if [ "$(pip list | grep -c scipy)" -eq 0 ];then
      echo "# Installing optional dependencies"
      pip install scipy
    fi
    # wallet
    chooseWallet noLockFileCheck
    /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) "history -v 4"
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  IMPORT) 
    /home/joinmarket/info.importwallet.sh
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh;;
  RECOVER)
    clear
    echo
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    if [ "${RPCoverTor}" = "on" ];then 
      torify python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
    else
      python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover
    fi
    echo ""
    echo "Press ENTER to return to the menu"
    read key;;
  UNLOCK)
    echo "Removing the wallet lockfiles with the command:"
    echo "rm ~/.joinmarket/wallets/.*.lock"
    rm ~/.joinmarket/wallets/.*.lock
    # for old version <v0.6.3
    rm ~/.joinmarket/wallets/*.lock 2>/dev/null
    echo ""
    echo "Press ENTER to return to the menu"
    read key;;
  RESCAN)
    checkRPCwallet
    echo
    echo "# Input the blockheight to scan from (first SegWit block: 481824):"
    read blockheight
    echo "# Can exit the command with CTRL+C, the rescan will continue in the background"
    customRPC "# Rescan wallet in bitcoind" "rescanblockchain" "$blockheight"
    echo
    echo "# Monitor the progress in the logs of the connected bitcoind"
    echo
    showBitcoinLogs 30
    echo "Press ENTER to return to the menu"
    read key;;
  UTXOS)
    # wallet
    chooseWallet noLockFileCheck
    /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) "showutxos"
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  XPUBS)
    # wallet
    chooseWallet noLockFileCheck
    clear
    echo
    echo "The 5 master public keys correspond to the 5 mixdepths (accounts) of the JoinMarket wallet."
    echo
    /home/joinmarket/start.script.sh wallet-tool "$(cat $wallet)"|grep mixdepth|sed -n '1~2p'|awk '{print $3}'
    echo
    echo "Import the master public keys to Specter Desktop or Electrum to create watch only wallets."
    echo
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/menu.sh;;
  PSBT)
    signPSBT;;
esac