#!/bin/bash

script="$1"
if [ ${#script} -eq 0 ]; then
  echo "must specify a script to run"
  exit 1
fi

if [ ${#wallet} -eq 0 ] || [ ${wallet} == "" ]; then
  # wallet
  tempwallet=$(tempfile 2>/dev/null)
  dialog --backtitle "Choose a wallet" \
       --title "Choose a wallet by typing the full name of the file" \
       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $tempwallet
  wallet=$(cat $tempwallet)
fi

option="$3"
if [ ${#option} -eq 0 ] || [ ${option} == nooption ]; then
  option=""
fi

mixdepth="$4"
if [ ${#mixdepth} -eq 0 ]; then
  mixdepth=""
else
  mixdepth="-m$4"
fi

makercount="$5"
if [ ${#makercount} -eq 0 ]; then
  makercount=""
else
  makercount="-N$5"
fi

amount="$6"
if [ ${#amount} -eq 0 ]; then
  amount=""
fi

address="$7"
if [ ${#address} -eq 0 ]; then
  address=""
fi

if [ ${RPCoverTor} == on ];then 
  tor="torify"
else
  tor=""
fi

# get password
data=$(tempfile 2>/dev/null)

# trap it
trap "rm -f $data" 0 1 2 5 15

dialog --backtitle "Decrypting Wallet" \
       --insecure \
       --passwordbox "Type or paste the wallet decryption password" 8 52 2> $data

# make decison
pressed=$?
case $pressed in
  0)
    . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
    echo "running the command:
$tor python ~/joinmarket-clientserver/scripts/$script.py \
$makercount $mixdepth $wallet $option $amount $address"
    echo ""
    cat $data | $tor \
    python ~/joinmarket-clientserver/scripts/$script.py \
    $makercount $mixdepth $wallet $option $amount $address --wallet-password-stdin
    shred $data
    ;;
  1)
    shred $data
    rm -f .pw
    echo "Cancelled"
    exit 1
    ;;
  255)
    shred $data
    rm -f .pw
    [ -s $data ] &&  cat $data || echo "ESC pressed."
    exit 1
    ;;
esac
