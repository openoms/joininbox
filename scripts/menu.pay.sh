#!/bin/bash

# wallet
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
       --title "Choose a wallet by typing the full name of the file" \
       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet

# mixdepth
mixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth" \
--inputbox "Type a number between 0 to 4 to choose the mixdepth" 8 60 2> $mixdepth

# makercount
makercount=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the makercount" \
--inputbox "Choose the number of makers to coinjoin with (0-9)
Type 0 to send without a coinjoin." 9 60 2> $makercount

# amount
amount=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the amount" \
--inputbox "Type the amount to send in satoshis
Use 0 to sweep the mixdepth without a change output" 9 60 2> $amount

# address
address=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the address" \
--inputbox "Paste the destination address" 8 60 2> $address

# check command
dialog --backtitle "Confirm the selections" \
--yesno "Confirm the details:

Send: $(cat $amount) sats

to the address:
$(cat $address)

from the mixdepth: $(cat $mixdepth)

coinjoined with $(cat $makercount) makers." 15 60

# make decison
pressed=$?
case $pressed in
  0)
    # run command
    /home/joinmarket/start.script.sh sendpayment $(cat $wallet) nooption \
    $(cat $mixdepth) $(cat $makercount) $(cat $amount) $(cat $address)
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