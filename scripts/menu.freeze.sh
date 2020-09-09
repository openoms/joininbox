#!/bin/bash

source /home/joinmarket/joinin.conf
source /home/joinmarket/menu.functions.sh

chooseWallet

# get mixdepth
mixdepth=$(mktemp 2>/dev/null)
dialog --backtitle "Choose a mixdepth" \
--inputbox "Enter a number between 0 to 4 to choose the mixdepth" 8 60 2> "$mixdepth"
openMenuIfCancelled $?

if [ "${RPCoverTor}" = "on" ]; then 
  tor="torify"
else
  tor=""
fi

clear
# display
echo "Running the command:
$tor python wallet-tool.py -m$(cat "$mixdepth") \
$(sed "s#$walletPath##g" < "$wallet") freeze
"
# run
$tor python ~/joinmarket-clientserver/scripts/wallet-tool.py \
-m"$(cat "$mixdepth")" "$(cat "$wallet")" freeze
