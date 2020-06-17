#!/bin/bash

# unlocking through stdin does not work with the freeze method:
# https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/598
# /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) freeze $(cat $mixdepth)

source joinin.conf
source menu.functions.sh

# get wallet
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
--title "Choose a wallet by typing the full name of the file" \
--fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
openMenuIfCancelled $?

# get mixdepth
mixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth" \
--inputbox "Type a number between 0 to 4 to choose the mixdepth" 8 60 2> $mixdepth
openMenuIfCancelled $?

echo "Run the following command manually to use the freeze method"
echo ""
if [ ${RPCoverTor} == on ];then 
  echo "torify python ~/joinmarket-clientserver/scripts/wallet-tool.py -m$(cat $mixdepth) $(cat $wallet) freeze"
else
  echo "python ~/joinmarket-clientserver/scripts/wallet-tool.py -m$(cat $mixdepth) $(cat $wallet) freeze"
fi
echo "
type 'menu' and press ENTER to return to the menu
"