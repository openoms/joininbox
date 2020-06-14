#!/bin/bash

source /home/joinmarket/joinin.conf

# Basic Options
OPTIONS=(LAN "Computers on the same network" \
        TOR "Copy from a Tor enabled remote node"
        )

CHOICE=$(dialog --clear --title "Would you like to copy over LAN or Tor?" --menu "" 11 60 6 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        LAN) echo "Copying over LAN";;
        TOR) echo "Copying over Tor";;
        *) exit 1;;
esac

if [ ! -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ]; then
  dialog --title "JoinMarket is not installed" --yesno "
Do you want to install Joinmarket now?" 7 42
  response=$?
  echo "response(${response})"
  if [ "${response}" = "0" ]; then
    echo "OK - starting JoinMarket installation"
    ./install.joinmarket.sh
    errorOnInstall=$?
    if [ ${errorOnInstall} -eq 0 ]; then
      dialog --title "Installed JoinMarket" \
        --msgbox "\nContinue from the menu or use the command line " 7 56
    else 
      DIALOGRC=.dialogrc.onerror dialog --title "Error during install" \
        --msgbox "\nPlease search or report at:\n https://github.com/openoms/joininbox/issues" 7 56
    fi
    menu
  fi
fi

if [ "${CHOICE}" = "LAN" ]; then
  # get local ip
  localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
elif [ "${CHOICE}" = "TOR" ]; then
  # set up a Hidden Service for ssh
  ./install.hiddenservice.sh ssh 22 22
  TOR_ADDRESS=$(sudo cat $HiddenServiceDir/ssh/hostname)
fi

echo ""
echo "************************************************************************************"
echo "Instructions to COPY wallets from another computer"
echo "************************************************************************************"
echo ""
echo "You can use the wallets from another JoinMarket instance"
echo ""
if [ "${CHOICE}" = "LAN" ]; then
  echo "Both computers (your JoininBox and the other computer with the wallets) need"
  echo "to be connected to the same local network."
elif [ "${CHOICE}" = "TOR" ]; then
  echo "The remote node needs to have Tor activated to be able to use torify"
fi 
echo ""
echo "Open a terminal on the source computer and change into the directory that contains the"
echo "wallets. Usually: ~/.joinmarket/wallets or ~/joinmarket-clientserver/scripts/wallets"
echo "You should see files called '.jmdat'"
echo ""
echo "COPY, PASTE & EXECUTE the following command in the terminal of the source computer:"
echo ""
if [ "${CHOICE}" = "LAN" ]; then
  echo "scp ./*.jmdat joinmarket@${localip}:~/.joinmarket/wallets"
elif [ "${CHOICE}" = "TOR" ]; then
  echo "torify scp ./*.jmdat joinmarket@${TOR_ADDRESS}:~/.joinmarket/wallets"
fi
echo "" 
echo "This command will ask for your SSH PASSWORD of your JoininBox."
echo "Use the PASSWORD_B on a RaspiBlitz (same as the rpcpassword in the bitcoin.conf)."
echo "************************************************************************************"
echo "PRESS ENTER if the transfer is done OR if you want to choose another option."
sleep 2
read key