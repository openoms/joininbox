#!/bin/bash

source joinin.conf
source menu.functions.sh

function receivePayJoin() {

# wallet
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
       --title "Choose a wallet by typing the full name of the file" \
       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
openMenuIfCancelled $?

# mixdepth
mixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth to receive to" \
--title "Choose a mixdepth to receive to" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth
(make sure there is at least one UTXO there already)" 10 60 2> $mixdepth
openMenuIfCancelled $?

# amount
amount=$(tempfile 2>/dev/null)
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
$(cat $wallet)
mixdepth: $(cat $mixdepth)
" 11 55
# make decison
pressed=$?
case $pressed in
  0)
    clear
    # display
    echo "Running the command:
$tor python receive-payjoin.py -m$(cat $mixdepth) $(cat $wallet) $(cat $amount)
"
    echo " Communicate the payer the:
- receiving address  (3...)
- expected amount in satoshis
- ephemeral nickname (J5...)
and press `y` to wait for the transaction.
" 
    # run
    $tor python ~/joinmarket-clientserver/scripts/receive-payjoin.py -m$(cat $mixdepth) $(cat $wallet) $(cat $amount)
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
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
       --title "Choose a wallet by typing the full name of the file" \
       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
openMenuIfCancelled $?

# mixdepth
tempmixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth to send from" \
--title "Choose a mixdepth to send from" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth" 9 60 2> $tempmixdepth
openMenuIfCancelled $?
mixdepth="-m$(cat $tempmixdepth)"

# address
address=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the address" \
--title "Choose the address" \
--inputbox "
Paste the destination address" 9 60 2> $address
openMenuIfCancelled $?

# amount
amount=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the amount" \
--title "Choose the amount" \
--inputbox "
Enter the amount to send in satoshis" 9 60 2> $amount
openMenuIfCancelled $?

# nickname
tempnickname=$(tempfile 2>/dev/null)
dialog --backtitle "Enter the counterparty" \
--title "Enter the counterparty" \
--inputbox "
Paste the ephemeral nickname of the receiver" 9 60 2> $tempnickname
openMenuIfCancelled $?
nickname="-T $(cat $tempnickname)"

if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

# check command
dialog --backtitle "Confirm the selections" \
--title "Confirm the details" \
--yesno "
Send: $(cat $amount) sats

from the wallet:
$(cat $wallet)
mixdepth: $(cat $tempmixdepth)

to the address:
$(cat $address)

PayJoin with the ephemeral nickname:
$(cat $tempnickname)
" 16 55
# make decison
pressed=$?
case $pressed in
  0)
    # display
    echo "Running the command:
$tor python sendpayment.py \
$mixdepth $(cat $wallet) $(cat $amount) $(cat $address) $nickname
"
    # run
    $tor python ~/joinmarket-clientserver/scripts/sendpayment.py \
    $mixdepth $(cat $wallet) $(cat $amount) $(cat $address) $nickname
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
HEIGHT=10
WIDTH=48
CHOICE_HEIGHT=20
TITLE="JoininBox"
MENU="
PayJoin options:"
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
      ;;
  SEND)
      sendPayJoin
      ;;              
esac
