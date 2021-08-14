#!/bin/bash

# WALLET menu options

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

checkRPCwallet

# BASIC MENU INFO
HEIGHT=18
WIDTH=52
CHOICE_HEIGHT=12
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
  SHOWSEED "Shows the wallet recovery seed"
  RECOVER "Restore a wallet from the seed"
  INCREASEGAP "Increase the gap limit"
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
    menu_GEN;;
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
  SHOWSEED)
    # wallet
    chooseWallet noLockFileCheck
    /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) "showseed"
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  RECOVER)
    echo
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    command="$tor python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py recover"
    echo "Running the command:"
    echo "$command"
    $command
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  INCREASEGAP)
    # wallet
    chooseWallet noLockFileCheck
    # gaplimit
    gaplimit=$(mktemp -p /dev/shm/)
    dialog --backtitle "Choose the new gap limit" \
    --title "Choose the new gap limit" \
    --inputbox "
The gap limit is the number of empty addresses after which the wallet stops looking for funds.
The default used is 6. 
Set a higher number if funds are missing after recovery.
The tradeoff is more time needed for the wallet to open with more addresses monitored.

Enter the new gap limit to be used" 16 60 2> "$gaplimit"
    openMenuIfCancelled $?
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    command="$tor python /home/joinmarket/joinmarket-clientserver/scripts/wallet-tool.py --recoversync -g $(cat $gaplimit) $(cat $wallet)"
    echo "Running the command:"
    echo "$command"
    $command
    echo
    echo "Check if the funds appeared now with DISPLAY."
    echo "You can set the gap limit as many times as needed."
    echo
    echo "Press ENTER to return to the menu"
    read key;;
  UNLOCK)
    echo "Removing the wallet lockfiles with the command:"
    echo "rm ~/.joinmarket/wallets/.*.lock"
    rm ~/.joinmarket/wallets/.*.lock
    # for old version <v0.6.3
    rm ~/.joinmarket/wallets/*.lock 2>/dev/null
    echo
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