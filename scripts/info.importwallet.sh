#!/bin/bash

source /home/joinmarket/joinin.conf

# Basic Options
OPTIONS=(LAN "Computers on the same network" \
        TOR "Copy from a Tor enabled remote node"
        )

CHOICE=$(dialog --clear --title "Would you like to copy over LAN or Tor?" --menu "" 8 50 6 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        LAN) echo "Copying over LAN";;
        TOR) echo "Copying over Tor";;
        *) exit 1;;
esac



if [ "${CHOICE}" = "TOR" ]; then
  # set up a Hidden Service for ssh
  /home/joinmarket/install.hiddenservice.sh ssh 22 22
  TOR_ADDRESS=$(sudo cat "$HiddenServiceDir"/ssh/hostname)
fi

echo "
************************************************************************************
Instructions to COPY wallets from another computer
************************************************************************************

You can use the wallets from another JoinMarket instance
"
if [ "${CHOICE}" = "LAN" ]; then
  if [ -f "/mnt/hdd/raspiblitz.conf" ] ; then
    echo "Both computers (the RaspiBlitz and the source computer with the wallet(s))" 
  else
    echo "Both computers (the JoininBox and the source computer with the wallet(s))"
  fi
echo "need to be connected to the same local network."
elif [ "${CHOICE}" = "TOR" ]; then
  echo "The remote node needs to have Tor activated to be able to use torsocks"
fi 
echo "
Open a terminal connected to the source computer and change into
the directory containing the wallets. 

By default the path is: '~/.joinmarket/wallets' or 
in older versions: '~/joinmarket-clientserver/scripts/wallets'

You should see files called '.jmdat'

COPY, PASTE & EXECUTE the following command in the terminal of the source computer:
"
if [ "${CHOICE}" = "LAN" ]; then
  echo "scp ./*.jmdat joinmarket@${localip}:~/.joinmarket/wallets"
elif [ "${CHOICE}" = "TOR" ]; then
  echo "torsocks scp ./*.jmdat joinmarket@${TOR_ADDRESS}:~/.joinmarket/wallets"
fi
echo "" 
if [ -f "/mnt/hdd/raspiblitz.conf" ] ; then
  echo "Use the PASSWORD_B to authorize the file transfer
(same as the rpcpassword in the /mnt/hdd/bitcoin/bitcoin.conf)."
else
  echo "This command will ask for the SSH PASSWORD of the JoininBox."
fi
echo "************************************************************************************
PRESS ENTER if the transfer is done OR if you want to choose another option.
"
sleep 2
read key