#!/bin/bash

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

checkRPCwallet

# Basic Options
OPTIONS=(LINUX "Running Linux"
        MAC "Running MacOS"
        WINDOWS "Running Windows"
        localhost "Linux on the same desktop"
        )

CHOICE=$(dialog --clear --title "Choose a desktop OS" --menu "" 10 45 4 "${OPTIONS[@]}" 2>&1 >/dev/tty)

clear
case $CHOICE in
        LINUX) echo "Showing instructions for Linux";;
        MAC) echo "Showing intsructions for MacOS";;
        WINDOWS) echo "Showing instructions for Windows";;
        localhost) echo "Showing instructions for Linux on the same desktop";;
        *) exit 1;;
esac

joinmarketSSHchanged=0
if grep -Eq "^DenyUsers joinmarket" /etc/ssh/sshd_config; then
  sudo /home/joinmarket/set.ssh.sh on
  joinmarketSSHchanged=1
fi

# switch on X11 forwarding
if [ ! -f /home/joinmarket/.Xauthority ]; then
  sudo -u joinmarket touch /home/joinmarket/.Xauthority
fi
sudo sed -i "s/^X11Forwarding no/X11Forwarding yes/g" /etc/ssh/sshd_config
if ! grep -Eq "^X11Forwarding yes" /etc/ssh/sshd_config; then
  echo "X11Forwarding yes" | sudo tee -a /etc/ssh/sshd_config
fi
echo "# Set 'X11Forwarding yes' and restarting sshd"
sudo service sshd restart


if [ "$RPCoverTor" = "on" ];then
  tor="torsocks "
else
  tor=""
fi

echo "
************************************************************************************
Instructions to open the JoinMarket-QT GUI on the desktop
************************************************************************************
"

if [ "${runningEnv}" = standalone ]; then
  joinmarketUserPsw="ssh login password"
else
  joinmarketUserPsw="PASSWORD_B (rpcpassword in the bitcoin.conf)"
fi

if [ "${CHOICE}" = "LINUX" ]; then
  echo "
Use the following line in a new desktop terminal to connect:

ssh -X joinmarket@${localip} ${tor}joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the ${joinmarketUserPsw} to open the JoinMarket-QT GUI
"


elif [ "${CHOICE}" = "MAC" ]; then
  echo "
Install the XQuartz application from https://www.xquartz.org/

Use the following line in a new desktop terminal to connect:

ssh -X joinmarket@${localip} ${tor}joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the ${joinmarketUserPsw} to open the JoinMarket-QT GUI
"


elif [ "${CHOICE}" = "WINDOWS" ]; then
  echo "
Download, install and run XMing with the default settings - https://sourceforge.net/projects/xming/

Open Putty and fill in:
    Host Name: $localip
    Port: 22

Under Connection set:
    Data -> Auto-login username: joinmarket
    SSH -> X11 -> [x] Enable X11 forwarding

The settings can be saved in Session -> type a name under Saved session -> Save
Make sure that Xming is running (the icon is present on the taskbar)

Open the connection
Use the ${joinmarketUserPsw} to log in
In the terminal Exit to the Command Line and type:

qtgui

The QT GUI will appear on the Windows desktop running from your RaspiBlitz.
"

elif [ "${CHOICE}" = "localhost" ]; then
  echo "
Use the following line in a new desktop terminal to connect:

ssh -X joinmarket@localhost ${tor}joinmarket-clientserver/jmvenv/bin/python joinmarket-clientserver/scripts/joinmarket-qt.py

Use the ${joinmarketUserPsw} to open the JoinMarket-QT GUI


Alternatively disable the display access control of the xserver:
* Open a new terminal on the desktop
* type:
  xhost +
* use the shortcut in the JoininBox terminal to open the JoinMarket-QT GUI:
  qtgui
* re-enable the access control with:
  xhost -
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
Press ENTER when the QT GUI is opened to prevent further connections and exit to the menu.
"

sleep 2
read key

if grep -Eq "^X11Forwarding yes" /etc/ssh/sshd_config; then
  echo "# Setting 'X11Forwarding no' in the /etc/ssh/sshd_config"
  sudo sed -i "s/^X11Forwarding yes/X11Forwarding no/g" /etc/ssh/sshd_config
  echo "# Restarting sshd"
  sudo service sshd restart
fi

if [ $joinmarketSSHchanged = 1 ];then
  sudo /home/joinmarket/set.ssh.sh off
fi
