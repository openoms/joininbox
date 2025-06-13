#!/bin/bash
# TUMBLER menu options
# https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/tumblerguide.md

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

if [ ${RPCoverTor} = "on" ]; then
  tor="torsocks"
else
  tor=""
fi

checkRPCwallet

# BASIC MENU INFO
HEIGHT=15
WIDTH=52
CHOICE_HEIGHT=22
TITLE="Tumbler options"
MENU=""
OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(
    TUMBLE "Start the Tumbler"
    SCHEDULE "Display and edit the schedule"
    LOGS "Display the Tumbler logs"
    RESTART "Restart an interrupted schedule"
)

CHOICE=$(dialog \
          --clear \
          --backtitle "$BACKTITLE" \
          --title "$TITLE" \
          --ok-label "Select" \
          --cancel-label "Back" \
          --menu "$MENU" \
            $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "${OPTIONS[@]}" \
            2>&1 >/dev/tty)

case $CHOICE in

SCHEDULE)
  # [mixdepth, amount-fraction, N-counterparties (requested), destination address, wait time in minutes, rounding, flag indicating incomplete/broadcast/completed (0/txid/1)]
  dialog \
   --title "Tumbler schedule"  \
   --prgbox "(echo 'mixdepth,amount-fraction,N-counterparties,destination address,wait time in minutes,rounding,flag (0/txid/1)' ;cat /home/joinmarket/.joinmarket/logs/TUMBLE.schedule) | column -t -s, 2>/dev/null" 30 120
   ;;

esac