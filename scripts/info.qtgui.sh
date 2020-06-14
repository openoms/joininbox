#!/bin/bash

source /home/joinmarket/joinin.conf

# Basic Options
OPTIONS=(LINUX "Running Linux" \
        MAC "Running MacOS" \
        WINDOWS "Running Windows" \
        )

CHOICE=$(dialog --clear --title "Choose a desktop OS" --menu "" 9 45 3 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        LINUX) echo "Showing intructions for Linux";;
        MAC) echo "Showing intructions for MacOS";;
        WINDOWS) echo "Showing intructions for Windows";;
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

# get local ip
localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')

echo "
************************************************************************************
Instructions to open the JoinMarket-QT GUI on the desktop
************************************************************************************
"

if [ "${CHOICE}" = "LINUX" ]; then
  echo "
Use the line in the desktop terminal to connect:

ssh -X joinmarket@$localip joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the PASSWORD_B (rpc_password in the bitcoin.conf) to open the JoinMarket-QT GUI"

elif [ "${CHOICE}" = "MAC" ]; then
  echo "
Install the XQuartz application from https://www.xquartz.org/

Use the line in the desktop terminal to connect:

ssh -X joinmarket@$localip joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the PASSWORD_B (rpc_password in the bitcoin.conf) to open the JoinMarket-QT GUI"

elif [ "${CHOICE}" = "WINDOWS" ]; then
  echo "
Download, install and run XMing with the default settings - https://xming.en.softonic.com/

Open Putty and fill in:
    Host Name: $localip
    Port: 22

Under Connection:
    Data -> Auto-login username: joinmarket

Under SSH
    X11 -> [x] Enable X11 forwarding

These settings can be saved in Session -> Load. save or delete stored session -> Save
Open the connection
Use the PASSWORD_B to log in
In the terminal type:

python joinmarket-qt.py

The QT GUI will appear on the Windows desktop running from your RaspiBlitz."
fi 

echo "

************************************************************************************

The graphical interface will run on the desktop relayed from the node via an encrypted ssh tunnel.

See the walkthrough for the JoinMarket-Qt GUI to send payments with coinjoin or run multiple coinjoins (tumbler): 
https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/JOINMARKET-QT-GUIDE.md

Video demonstration of using the JoinMarket-Qt GUI by Adam Gibson (waxwing): 
https://youtu.be/hwmvZVQ4C4M

See this review thread about the QT GUI: 
https://twitter.com/zndtoshi/status/1191799199119134720

************************************************************************************
PRESS ENTER if when done with the instructions to exit to the menu
"

sleep 2
read key