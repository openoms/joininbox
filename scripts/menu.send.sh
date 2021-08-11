#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/_functions.sh

checkRPCwallet

# wallet
chooseWallet

# mixdepth
mixdepth=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose a mixdepth to send from" \
--title "Choose a mixdepth to send from" \
--inputbox "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")

Enter a number between 0 to 4 to choose the mixdepth" 17 69 2> "$mixdepth"
openMenuIfCancelled $?

# amount
amount=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the amount" \
--title "Choose the amount" \
--inputbox "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")

Enter the amount to send in satoshis
Use 0 to sweep the mixdepth without a change output" 18 69 2> "$amount"
openMenuIfCancelled $?
amountsats="$(cat "$amount") sats"

# makercount
makercount=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the makercount" \
--title "Choose the makercount" \
--inputbox "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")

Enter the number of makers to coinjoin with (min 4)
Leave empty for the default 5-9 (randomized)
Enter 0 to send without a coinjoin." 19 69 2> "$makercount"
openMenuIfCancelled $?
varMakercount=$(cat "$makercount")
if [ ${#varMakercount} -eq 0 ]; then
  makercountMessage="with 5-9 (randomized) makers"
  makercountOption=""
elif [ "$varMakercount" = "0" ]; then
  makercountMessage="none"
  makercountOption="-N 0"
else
  makercountMessage="with $varMakercount makers"
  makercountOption="-N $varMakercount"
fi


# txfee
txfee=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the miner fee" \
--title "Choose the miner fee" \
--inputbox "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")

Enter the miner fee to be used for the transaction in sat/byte
Leave empty to use the default fee (set in the joinmarket.cfg)" 18 69 2> "$txfee"
openMenuIfCancelled $?
varTxfee=$(cat "$txfee")
if [ ${#varTxfee} -eq 0 ]; then
  txfeeMessage="default (set in the joinmarket.cfg)"
  txfeeOption=""
else
  txfeeMessage="$varTxfee sat/byte"
  txfeeOption="--txfee=$((varTxfee * 1000))"
fi

# address
address=$(mktemp -p /dev/shm/)
dialog --backtitle "Choose the address" \
--title "Choose the address" \
--inputbox "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")

Paste the destination address" 17 69 2> "$address"
openMenuIfCancelled $?

if [ "${RPCoverTor}" = "on" ]; then 
  tor="torify"
else
  tor=""
fi

# check command
dialog --backtitle "Confirm the details" \
--title "Confirm the details" \
--yesno "
From the wallet: $walletFileName
mixdepth: $(cat "$mixdepth")
send: $amountsats
coinjoin: $makercountMessage
miner fee: $txfeeMessage
destination address:
$(cat "$address")" 15 69

# make decison
pressed=$?
case $pressed in
  0)
    clear
    # display
    echo "Running the command:
$tor python sendpayment.py \
-m $(cat "$mixdepth") $makercountOption $(sed "s#$walletPath##g" < "$wallet" ) \
$(cat "$amount") $(cat "$address") $txfeeOption
"
    # run
    $tor python ~/joinmarket-clientserver/scripts/sendpayment.py \
    -m "$(cat "$mixdepth")" $makercountOption "$(cat "$wallet")" \
    "$(cat "$amount")" "$(cat "$address")" $txfeeOption
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