#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

checkRPCwallet

function receivePayJoin() {

# wallet
chooseWallet

# mixdepth
trap 'rm -f "$mixdepth"' EXIT
mixdepth=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose a mixdepth to receive to" \
--title "Choose a mixdepth to receive to" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth
(make sure there is at least one UTXO there already)" 10 60 2> $mixdepth
openMenuIfCancelled $?

# amount
trap 'rm -f "$amount"' EXIT
amount=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the amount" \
--title "Choose the amount" \
--inputbox "
Enter the amount to receive in satoshis" 9 60 2> $amount
openMenuIfCancelled $?

if [ ${RPCoverTor} = "on" ];then 
  tor="torify"
else
  tor=""
fi

# check command
dialog --backtitle "Confirm the details" \
--title "Confirm the details" \
--yesno "
Receive: $(cat $amount) sats

To the wallet:
$(echo $(cat $wallet) | sed "s#$walletPath##g")

mixdepth: $(cat $mixdepth)
" 12 55

# make decison
pressed=$?
case $pressed in
  0)
    clear
    # display
    echo "Running the command:
$tor python receive-payjoin.py -m$(cat $mixdepth) \
$(echo $(cat $wallet) | sed "s#$walletPath##g") $(cat $amount)
"
    echo "Will wait for the ephemeral Tor Hidden Service to be created.
Can cancel the process by pressing CTRL+C .
" 
    # run
    $tor python ~/joinmarket-clientserver/scripts/receive-payjoin.py \
    -m$(cat $mixdepth) $(cat $wallet) $(cat $amount)
    ;;
  1)
    echo "Cancelled"
    exit 1
    ;;
  255)
    echo "ESC pressed."
    exit 1
    ;;
esac
}

function sendPayJoin() {

# wallet
chooseWallet

# mixdepth
trap 'rm -f "$mixdepth"' EXIT
mixdepth=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose a mixdepth to send from" \
--title "Choose a mixdepth to send from" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth" 9 60 2> $mixdepth
openMenuIfCancelled $?

# receiveURI
trap 'rm -f "$receiveURI"' EXIT
receiveURI=$(mktemp -p /dev/shm/)
dialog --backtitle "Receive URI" \
--title "Receive URI" \
--inputbox "
Paste the Receive URI to send to" 9 60 2> $receiveURI
openMenuIfCancelled $?

# txfee
trap 'rm -f "$txfee"' EXIT
txfee=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the miner fee" \
--title "Choose the miner fee" \
--inputbox "
Enter the miner fee to be used for the transaction in sat/byte
Leave empty to use the default fee (set in the joinmarket.cfg)" 10 67 2> "$txfee"
openMenuIfCancelled $?
varTxfee=$(cat "$txfee")
if [ ${#varTxfee} -eq 0 ]; then
  txfeeMessage="default (set in the joinmarket.cfg)"
  txfeeOption=""
else
  txfeeMessage="$varTxfee sat/byte"
  if [ ${#varTxfee} -eq 1 ]; then
    # https://github.com/openoms/joininbox/issues/64
    txfeeOption="--txfee=1001"
  else
    txfeeOption="--txfee=$((varTxfee * 1000))"
  fi
fi

if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

# check command
dialog --backtitle "Confirm the selections" \
--title "Confirm the details" \
--yesno "
Send to: 
$(cat $receiveURI)

from the wallet:
$(sed "s#$walletPath##g" < "$wallet")

mixdepth: $(cat "$mixdepth")

Miner fee: $txfeeMessage
" 16 55
# make decison
pressed=$?
case $pressed in
  0)
    # display
    echo "Running the command:
$tor python sendpayment.py -m$(cat "$mixdepth") \
$(sed "s#$walletPath##g" < "$wallet") \
$(cat "$receiveURI") $txfeeOption
"
    # run
    $tor python ~/joinmarket-clientserver/scripts/sendpayment.py \
    -m"$(cat "$mixdepth")" "$(cat "$wallet")" "$(cat "$receiveURI")" $txfeeOption
    ;;
  1)
    echo "Cancelled"
    exit 1
    ;;
  255)
    echo "ESC pressed."
    exit 1
    ;;
esac
}

# BASIC MENU INFO
HEIGHT=8
WIDTH=48
CHOICE_HEIGHT=20
TITLE="PayJoin options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  SEND "Send a payment with PayJoin" \
  RECEIVE "Receive a payment with PayJoin" \
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Back" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  RECEIVE)
      receivePayJoin
      echo ""
      echo "Press ENTER to return to the menu..."
      read key
      ;;
  SEND)
      sendPayJoin
      echo ""
      echo "Press ENTER to return to the menu..."
      read key
      ;;              
esac
