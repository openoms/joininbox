#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

function receivePayJoin() {

# wallet
chooseWallet

# mixdepth
mixdepth=$(mktemp 2>/dev/null)
dialog --backtitle "Choose a mixdepth to receive to" \
--title "Choose a mixdepth to receive to" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth
(make sure there is at least one UTXO there already)" 10 60 2> $mixdepth
openMenuIfCancelled $?

# amount
amount=$(mktemp 2>/dev/null)
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
mixdepth=$(mktemp 2>/dev/null)
dialog --backtitle "Choose a mixdepth to send from" \
--title "Choose a mixdepth to send from" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth" 9 60 2> $mixdepth
openMenuIfCancelled $?

# receiveURI
receiveURI=$(mktemp 2>/dev/null)
dialog --backtitle "Receive URI" \
--title "Receive URI" \
--inputbox "
Paste the Receive URI to send to" 9 60 2> $receiveURI
openMenuIfCancelled $?

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
" 13 55
# make decison
pressed=$?
case $pressed in
  0)
    # display
    echo "Running the command:
$tor python sendpayment.py -m$(cat "$mixdepth") \
$(sed "s#$walletPath##g" < "$wallet") \
$(cat "$receiveURI")
"
    # run
    $tor python ~/joinmarket-clientserver/scripts/sendpayment.py \
    -m"$(cat "$mixdepth")" "$(cat "$wallet")" "$(cat "$receiveURI")"
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
MENU="
"
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
