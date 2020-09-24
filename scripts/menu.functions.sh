#!/bin/bash

walletPath="/home/joinmarket/.joinmarket/wallets/"

# openMenuIfCancelled
openMenuIfCancelled() {
pressed=$1
case $pressed in
  1)
    echo "Cancelled"
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
  255)
    echo "ESC pressed."
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
esac
}

# write password into a file (to be shredded)
passwordToFile() {
# get password
data=$(mktemp 2>/dev/null)
# trap it
trap 'rm -f $data' 0 1 2 5 15
dialog --backtitle "Enter password" \
       --title "Enter password" \
       --insecure \
       --passwordbox "Type or paste the wallet decryption password" 8 52 2> "$data"
# make decison
pressed=$?
case $pressed in
  0)
    touch /home/joinmarket/.pw
    chmod 600 /home/joinmarket/.pw
    tee /home/joinmarket/.pw 1>/dev/null < "$data"
    shred "$data"
    ;;
  1)
    shred "$data"
    shred "$wallet"
    rm -f .pw
    echo "Cancelled"
    exit 1
    ;;
  255)
    shred "$data"
    shred "$wallet"
    rm -f .pw
    [ -s "$data" ] &&  cat "$data" || echo "ESC pressed."
    exit 1
    ;;
esac
}

# chooseWallet
chooseWallet() {
source /home/joinmarket/joinin.conf
wallet=$(mktemp 2>/dev/null)
if [ "$defaultWallet" = "off" ]; then
  wallet=$(mktemp 2>/dev/null)
  dialog --backtitle "Choose a wallet by typing the full name of the file" \
  --title "Choose a wallet by typing the full name of the file" \
  --fselect "$walletPath" 10 60 2> "$wallet"
  openMenuIfCancelled $?
else
  echo "$defaultWallet" > "$wallet"
fi
}

function stopYG() {
# stop the background process (equivalent to CTRL+C)
# use wallet from joinin.conf
source /home/joinmarket/joinin.conf
pkill -sigint -f "python yg-privacyenhanced.py $YGwallet --wallet-password-stdin"
# pgrep python | xargs kill -sigint             
# remove the service
sudo systemctl stop yg-privacyenhanced
sudo systemctl disable yg-privacyenhanced
# check for failed services
# sudo systemctl list-units --type=service
sudo systemctl reset-failed
# make sure the lock file is deleted 
rm -f ~/.joinmarket/wallets/.$wallet.lock
# for old version <v0.6.3
rm -f ~/.joinmarket/wallets/$wallet.lock 2>/dev/null
echo "# stopped the Yield Generator background service"
}

function QRinTerminal() {
  datastring=$1
  if [ ${#datastring} -eq 0 ]; then
    echo "error='missing string'"
  fi
  qrencode -t ANSI256 "${datastring}"
  echo "(To shrink QR code: MacOS press CMD- / Linux press CTRL-)"
}
