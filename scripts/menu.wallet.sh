#!/bin/bash

# WALLET menu options

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

if [ ${RPCoverTor} = "on" ]; then
  tor="torsocks"
else
  tor=""
fi

checkRPCwallet

# BASIC MENU INFO
HEIGHT=19
WIDTH=53
CHOICE_HEIGHT=13
TITLE="Wallet management options"
BACKTITLE="Wallet management options"
MENU=""
OPTIONS=()

# Basic Options
OPTIONS+=(
  DISPLAY "Show the contents of all mixdepths"
  LABEL "Add or edit a label to an address"
  UTXOS "Show all the coins in the wallet"
  HISTORY "Show all past transactions"
  XPUBS "Show the master public keys"
  PSBT "Sign a Base64 format PSBT"
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
  LABEL)
    # wallet
    chooseWallet
    # address
    trap 'rm -f "$address"' EXIT
    address=$(mktemp -p /dev/shm/)
    dialog --backtitle "Choose the address" \
     --title "Choose the address" \
     --inputbox "
Paste the address to be labeled
from the wallet: $walletFileName
    " 11 69 2> "$address"
    openMenuIfCancelled $?
    # label
    trap 'rm -f "$label"' EXIT
    label=$(mktemp -p /dev/shm/)
    dialog --backtitle "Choose the label" \
     --title "Choose the label" \
     --inputbox "
Type or paste the label for the address:
$(cat "$address")
from the wallet: $walletFileName
    " 12 69 2> "$label"
    openMenuIfCancelled $?
    # display
    clear
    echo
    echo "Running the command:
$tor python wallet-tool.py \
$(cat "$wallet") setlabel $(cat "$address") $(cat "$label")
    "
    # run
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate &&
    $tor python ~/joinmarket-clientserver/scripts/wallet-tool.py \
     $(cat $wallet) "setlabel" "$(cat "$address")" "$(cat "$label")"
    echo
    echo "Press ENTER to return to the menu"
    read key;;
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
    trap 'rm -f "$gaplimit"' EXIT
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
    echo
    echo "# Starting the rescan from the block $blockheight ..."
    echo "# Can exit this screen with CTRL+C, the rescan will continue in the background"
    echo "# Monitor the progress in the logs of the connected bitcoind"
    echo
    customRPC "# Rescan wallet in bitcoind" "rescanblockchain" "$blockheight"
    echo
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
    echo "Import the master public keys to Specter Desktop or Electrum to create watch-only wallets."
    echo
    echo "Press ENTER to return to the menu..."
    read key
    /home/joinmarket/menu.sh;;
  PSBT)
    signPSBT;;
esac