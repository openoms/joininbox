#!/bin/bash

source /home/joinmarket/joinin.conf

# add option if not in conf
if ! grep -Eq "^wallet=" joinin.conf; then
  echo "wallet=nil" >> joinin.conf
fi

script="$1"
if [ ${#script} -eq 0 ]; then
  echo "please specify a script to run"
fi

option="$2"
if [ ${#option} -eq 0 ]; then
  option=""
fi

# choose wallet
## exprimental
#dialog --backtitle "Choose a wallet" \
#       --title "Choose a wallet by starting to type " \
#       --fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2>_temp
#
#dialog --backtitle "Choose a wallet" \
#       --title "Choose a wallet" \
#       --inputbox "\nProceeding with $(cat _temp) unless edited below" 10 60 $(cat _temp) 2>_temp

# get password
wallet=$(tempfile 2>/dev/null)

dialog --backtitle "Choosing a wallet" \
       --inputbox "Type the name of the wallet to be used.\nExample: wallet1 for wallet1.jmdat" 10 60 2> $wallet

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
    if [ ${RPCoverTor} = on ];then
      echo "running the command:
'torify python ~/joinmarket-clientserver/scripts/$script.py \
$(cat $wallet).jmdat $option'"
      echo ""
      cat $data | torify \
      python ~/joinmarket-clientserver/scripts/$script.py \
      $(cat $wallet).jmdat $option --wallet-password-stdin
    else
      echo "running:
'python ~/joinmarket-clientserver/scripts/$script.py \
$(cat $wallet).jmdat $option'"
      echo ""
      cat $data | \
      python ~/joinmarket-clientserver/scripts/$script.py \
      $(cat $wallet).jmdat $option --wallet-password-stdin
    fi
    shred $data;;
  1)
    shred $data
    shred $wallet
    rm -f .pw
    echo "Cancelled"
    exit 1;;
  255)
    shred $data
    shred $wallet
    rm -f .pw
    [ -s $data ] &&  cat $data || echo "ESC pressed."
    exit 1;;
esac
