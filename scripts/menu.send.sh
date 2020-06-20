#!/bin/bash

source menu.functions.sh

# wallet
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
       --title "Choose a wallet by typing the full name of the file" \
       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
openMenuIfCancelled $?

# mixdepth
mixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth" \
--title "Choose a mixdepth" \
--inputbox "
Enter a number between 0 to 4 to choose the mixdepth" 9 60 2> $mixdepth
openMenuIfCancelled $?

# makercount
makercount=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the makercount" \
--title "Choose the makercount" \
--inputbox "
Enter the number of makers to coinjoin with (0-9)
Enter 0 to send without a coinjoin." 10 60 2> $makercount
openMenuIfCancelled $?

# amount
amount=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the amount" \
--title "Choose the amount" \
--inputbox "
Enter the amount to send in satoshis
Use 0 to sweep the mixdepth without a change output" 10 60 2> $amount
openMenuIfCancelled $?

# address
address=$(tempfile 2>/dev/null)
dialog --backtitle "Choose the address" \
--title "Choose the address" \
--inputbox "
Paste the destination address" 9 60 2> $address
openMenuIfCancelled $?

# check command
dialog --backtitle "Confirm the details" \
--title "Confirm the details" \
--yesno "
Send: $(cat $amount) sats

From the wallet:
$(cat $wallet)
mixdepth: $(cat $mixdepth)

to the address:
$(cat $address)

coinjoined with $(cat $makercount) makers." 16 60

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