#!/bin/bash

source menu.functions.sh

# get password
data=$(tempfile 2>/dev/null)

# trap it
trap "rm -f $data" 0 1 2 5 15

dialog --backtitle "Enter password" \
       --title "Enter password" \
       --insecure \
       --passwordbox "Type or paste the wallet decryption password" 8 52 2> $data

# make decison
pressed=$?
case $pressed in
  0)
    touch /home/joinmarket/.pw
    chmod 600 /home/joinmarket/.pw
    cat $data | tee /home/joinmarket/.pw 1>/dev/null
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