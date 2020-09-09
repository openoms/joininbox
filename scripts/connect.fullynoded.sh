#!/bin/bash
clear

# extract RPC credentials from bitcoin.conf - store only in var
RPC_USER=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
PASSWORD_B=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
hiddenService=$(sudo cat /mnt/hdd/tor/bitcoin8332/hostname)

# btcstandup://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>/?label=<optional node label> 
quickConnect="btcstandup://$RPC_USER:$PASSWORD_B@$hiddenService:8332/?label=$hostname"
echo ""
echo "scan the QR Code with Fully Noded to connect to your node:"

###################
# QR
###################

qrencode -l L -o /home/admin/qr.png "${quickConnect}" > /dev/null
sudo fbi -a -T 1 -d /dev/fb1 --noverbose /home/admin/qr.png 2> /dev/null
exit 0

qrencode -t ANSI256 $quickConnect
echo ""
echo "Press ENTER to return to the menu"
read key

###################
# HIDE
###################

sudo killall -3 fbi
shred /home/admin/qr.png 2> /dev/null
rm -f /home/admin/qr.png 2> /dev/null

clear