#!/bin/bash

# add option if not in conf
if ! grep -Eq "^wallet=" joinin.conf; then
  echo "wallet=nil" >> joinin.conf
fi

# choose wallet
dialog --backtitle "Choosing a wallet" \
       --inputbox "Type the filename of the wallet to be used.\nExample: wallet.jmdat" 10 60 2>_temp
sed -i "s/^wallet=.*/wallet=$(cat _temp)/g" joinin.conf

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
    touch pw
    chmod 600 pw
    cat $data | tee pw 1>/dev/null
    shred $data;;
  1)
    echo "Cancelled";;
  255)
    [ -s $data ] &&  cat $data || echo "ESC pressed.";;
esac