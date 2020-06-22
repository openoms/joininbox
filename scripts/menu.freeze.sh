#!/bin/bash

# unlocking with stdin does not work with the freeze method:
# https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/598
# /home/joinmarket/start.script.sh wallet-tool $(cat $wallet) freeze $(cat $mixdepth)

source joinin.conf
source menu.functions.sh

chooseWallet

# get mixdepth
mixdepth=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a mixdepth" \
--inputbox "Enter a number between 0 to 4 to choose the mixdepth" 8 60 2> $mixdepth
openMenuIfCancelled $?

if [ ${RPCoverTor} = "on" ]; then 
  tor="torify"
else
  tor=""
fi

clear
# display
echo "Running the command:
$tor python wallet-tool.py -m$(cat $mixdepth) $(cat $wallet) freeze
"
# run
$tor python ~/joinmarket-clientserver/scripts/wallet-tool.py -m$(cat $mixdepth) $(cat $wallet) freeze
