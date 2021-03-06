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

# get local ip
localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')

joinmarketSSHchanged=0
if grep -Eq "^joinmarketSSH=off" /home/joinmarket/joinin.conf; then
  sudo /home/joinmarket/set.ssh.sh on
  joinmarketSSHchanged=1
fi

echo "
************************************************************************************
Instructions to open the JoinMarket-QT GUI on the desktop
************************************************************************************
"

if [ "${CHOICE}" = "LINUX" ]; then
  echo "
Use the following line in a new desktop terminal to connect:

ssh -X joinmarket@$localip joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the PASSWORD_B (rpcpassword in the bitcoin.conf) to open the JoinMarket-QT GUI"

elif [ "${CHOICE}" = "MAC" ]; then
  echo "
Install the XQuartz application from https://www.xquartz.org/

Use the following line in a new desktop terminal to connect:

ssh -X joinmarket@$localip joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the PASSWORD_B (rpcpassword in the bitcoin.conf) to open the JoinMarket-QT GUI"

elif [ "${CHOICE}" = "WINDOWS" ]; then
  echo "
Download, install and run XMing with the default settings - https://xming.en.softonic.com/

Open Putty and fill in:
    Host Name: $localip
    Port: 22

Under Connection set:
    Data -> Auto-login username: joinmarket
    SSH -> X11 -> [x] Enable X11 forwarding

The settings can be saved in Session -> type a name under Saved session -> Save
Make sure that Xming is running (the icon is present on the taskbar)

Open the connection
Use the PASSWORD_B to log in
In the terminal Exit to the Command Line and type:

qtgui

The QT GUI will appear on the Windows desktop running from your RaspiBlitz.

"
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
Press ENTER when done with the instructions to exit to the menu
"

sleep 2
read key

if [ $joinmarketSSHchanged = 1 ];then
  sudo /home/joinmarket/set.ssh.sh off
fi