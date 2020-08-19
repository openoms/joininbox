#!/bin/bash
#########################################################################
# Build your SD card image based on:
# 
# Raspberry Pi OS (32-bit) with desktop (2020-05-27)
# https://www.raspberrypi.org/downloads/raspberry-pi-os/
# SHA256: b9a5c5321b3145e605b3bcd297ca9ffc350ecb1844880afd8fb75a7589b7bd04
##########################################################################
# setup fresh SD card with the image above
# login with SSH and run this script from the root user.
##########################################################################

# The JoininBox Build Script is partially based on:
# https://github.com/rootzoll/raspiblitz/blob/master/build_sdcard.sh

# command info
if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "JoininBox Build Script with optional Tor install"
 echo "sudo build_joininbox.sh [--with-tor]"
 exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit
fi

echo ""
echo "*******************************"
echo "* JOININBOX BUILD SCRIPT v0.1 *"
echo "*******************************"
echo ""

echo "Detect Base Image ..." 
baseImage="?"
isDietPi=$(uname -n | grep -c 'DietPi')
isRaspbian=$(cat /etc/os-release 2>/dev/null | grep -c 'Raspbian')
isArmbian=$(cat /etc/os-release 2>/dev/null | grep -c 'Debian')
isUbuntu=$(cat /etc/os-release 2>/dev/null | grep -c 'Ubuntu')
if [ ${isRaspbian} -gt 0 ]; then
  baseImage="raspbian"
fi
if [ ${isArmbian} -gt 0 ]; then
  baseImage="armbian"
fi 
if [ ${isUbuntu} -gt 0 ]; then
  baseImage="ubuntu"
fi
if [ ${isDietPi} -gt 0 ]; then
  baseImage="dietpi"
fi
if [ "${baseImage}" = "?" ]; then
  cat /etc/os-release 2>/dev/null
  echo "!!! FAIL !!!"
  echo "Base Image cannot be detected or is not supported."
  exit 1
else
  echo "OK running ${baseImage}"
fi

if [ "${baseImage}" = "raspbian" ] || [ "${baseImage}" = "dietpi" ] ; then
  # fixing locales for build
  # https://github.com/rootzoll/raspiblitz/issues/138
  # https://daker.me/2014/10/how-to-fix-perl-warning-setting-locale-failed-in-raspbian.html
  # https://stackoverflow.com/questions/38188762/generate-all-locales-in-a-docker-image
  echo ""
  echo "*** FIXING LOCALES FOR BUILD ***"

  sudo sed -i "s/^# en_US.UTF-8 UTF-8.*/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sudo sed -i "s/^# en_US ISO-8859-1.*/en_US ISO-8859-1/g" /etc/locale.gen
  sudo locale-gen
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8

  # https://github.com/rootzoll/raspiblitz/issues/684
  sudo sed -i "s/^    SendEnv LANG LC.*/#   SendEnv LANG LC_*/g" /etc/ssh/ssh_config
  
  # remove unneccesary files
  sudo rm -rf /home/pi/MagPi
fi

# remove some (big) packages that are not needed
sudo apt-get remove -y --purge libreoffice* oracle-java* chromium-browser \
nuscratch scratch sonic-pi minecraft-pi plymouth python2 vlc

if [ -f "/usr/bin/python3.7" ]; then
  # make sure /usr/bin/python exists (and calls Python3.7 in Debian Buster)
  sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
  echo "python calls python3.7"
elif [ -f "/usr/bin/python3.8" ]; then
  # use python 3.8 if available
  sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1
  echo "python calls python3.8"
else
  echo "!!! FAIL !!!"
  echo "There is no tested version of python present"
  exit 1
fi

# update debian
echo ""
echo "*** UPDATE DEBIAN ***"
sudo apt-get update -y
sudo apt-get upgrade -f -y

echo ""
echo "*** PREPARE ${baseImage} ***"

# special prepare when DietPi
if [ "${baseImage}" = "dietpi" ]; then
  echo "renaming dietpi user to pi"
  sudo usermod -l pi dietpi
fi

# special prepare when Raspbian
if [ "${baseImage}" = "raspbian" ]; then
  # do memory split (16MB)
  sudo raspi-config nonint do_memory_split 16
  # set to wait until network is available on boot (0 seems to yes)
  sudo raspi-config nonint do_boot_wait 0
  # set WIFI country so boot does not block
  sudo raspi-config nonint do_wifi_country US
  # see https://github.com/rootzoll/raspiblitz/issues/428#issuecomment-472822840
  echo "max_usb_current=1" | sudo tee -a /boot/config.txt
  # run fsck on sd boot partition on every startup to prevent "maintenance login" screen
  # see: https://github.com/rootzoll/raspiblitz/issues/782#issuecomment-564981630
  # use command to check last fsck check: sudo tune2fs -l /dev/mmcblk0p2
  sudo tune2fs -c 1 /dev/mmcblk0p2
  # see https://github.com/rootzoll/raspiblitz/issues/1053#issuecomment-600878695
  sudo sed -i 's/^/fsck.mode=force fsck.repair=yes /g' /boot/cmdline.txt
fi

# special prepare when Nvidia Jetson Nano
if [ ${isNvidia} -eq 1 ] ; then
  # disable GUI on boot
  sudo systemctl set-default multi-user.target
fi

echo ""
echo "*** CONFIG ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#raspi-config

# change log rotates
# see https://github.com/rootzoll/raspiblitz/issues/394#issuecomment-471535483
echo "/var/log/syslog" >> ./rsyslog
echo "{" >> ./rsyslog
echo "	rotate 7" >> ./rsyslog
echo "	daily" >> ./rsyslog
echo "	missingok" >> ./rsyslog
echo "	notifempty" >> ./rsyslog
echo "	delaycompress" >> ./rsyslog
echo "	compress" >> ./rsyslog
echo "	postrotate" >> ./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "	endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/mail.info" >> ./rsyslog
echo "/var/log/mail.warn" >> ./rsyslog
echo "/var/log/mail.err" >> ./rsyslog
echo "/var/log/mail.log" >> ./rsyslog
echo "/var/log/daemon.log" >> ./rsyslog
echo "{" >> ./rsyslog
echo "        rotate 4" >> ./rsyslog
echo "        size=100M" >> ./rsyslog
echo "        missingok" >> ./rsyslog
echo "        notifempty" >> ./rsyslog
echo "        compress" >> ./rsyslog
echo "        delaycompress" >> ./rsyslog
echo "        sharedscripts" >> ./rsyslog
echo "        postrotate" >> ./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "        endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/kern.log" >> ./rsyslog
echo "/var/log/auth.log" >> ./rsyslog
echo "{" >> ./rsyslog
echo "        rotate 4" >> ./rsyslog
echo "        size=100M" >> ./rsyslog
echo "        missingok" >> ./rsyslog
echo "        notifempty" >> ./rsyslog
echo "        compress" >> ./rsyslog
echo "        delaycompress" >> ./rsyslog
echo "        sharedscripts" >> ./rsyslog
echo "        postrotate" >> ./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "        endscript" >> ./rsyslog
echo "}" >> ./rsyslog
echo "" >> ./rsyslog
echo "/var/log/user.log" >> ./rsyslog
echo "/var/log/lpr.log" >> ./rsyslog
echo "/var/log/cron.log" >> ./rsyslog
echo "/var/log/debug" >> ./rsyslog
echo "/var/log/messages" >> ./rsyslog
echo "{" >> ./rsyslog
echo "	rotate 4" >> ./rsyslog
echo "	weekly" >> ./rsyslog
echo "	missingok" >> ./rsyslog
echo "	notifempty" >> ./rsyslog
echo "	compress" >> ./rsyslog
echo "	delaycompress" >> ./rsyslog
echo "	sharedscripts" >> ./rsyslog
echo "	postrotate" >> ./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >> ./rsyslog
echo "	endscript" >> ./rsyslog
echo "}" >> ./rsyslog
sudo mv ./rsyslog /etc/logrotate.d/rsyslog
sudo chown root:root /etc/logrotate.d/rsyslog
sudo service rsyslog restart

echo ""
echo "*** SOFTWARE UPDATE ***"
# based on https://github.com/Stadicus/guides/blob/master/raspibolt/raspibolt_20_pi.md#software-update

# installs like on RaspiBolt
sudo apt-get install -y htop git curl bash-completion vim jq dphys-swapfile bsdmainutils

# installs bandwidth monitoring for future statistics
sudo apt-get install -y vnstat

# prepare for BTRFS data drive raid
sudo apt-get install -y btrfs-progs btrfs-tools

# network tools
sudo apt-get install -y autossh telnet

# prepare for display graphics mode
# see https://github.com/rootzoll/raspiblitz/pull/334
sudo apt-get install -y fbi

# prepare for powertest
sudo apt install -y sysbench

# check for dependencies on DietPi, Ubuntu, Armbian
sudo apt install -y build-essential

# add armbian-config
if [ "${baseImage}" = "armbian" ]; then
  # add armbian config
  sudo apt install armbian-config -y
fi

# dependencies for python
sudo apt install -y python3-venv python3-dev python3-wheel python3-jinja2 python3-pip

# make sure /usr/bin/pip exists (and calls pip3 in Debian Buster)
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# rsync is needed to copy from HDD
sudo apt install -y rsync
# install ifconfig
sudo apt install -y net-tools
#to display hex codes
sudo apt install -y xxd
# setuptools needed for Nyx
sudo pip install setuptools
# netcat for 00infoBlitz.sh
sudo apt install -y netcat
# install OpenSSH client + server
sudo apt install -y openssh-client
sudo apt install -y openssh-sftp-server
# install killall, fuser
sudo apt-get install -y psmisc

sudo apt-get clean
sudo apt-get -y autoremove

echo ""
echo "*** Add the 'joinmarket' user ***"
adduser --disabled-password --gecos "" joinmarket

echo "*** Clone the joininbox repo and copy the scripts ***"
cd /home/joinmarket
sudo -u joinmarket git clone https://github.com/openoms/joininbox.git
sudo -u joinmarket cp ./joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp ./joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
chmod +x /home/joinmarket/*.sh

echo "*** Setting the password for the users 'joinmarket' and 'root' ***"
apt install -y dialog
/home/joinmarket/set.password.sh
adduser joinmarket sudo
# chsh joinmarket -s /bin/bash
# configure sudo for usage without password entry for the joinmarket user
# https://www.tecmint.com/run-sudo-command-without-password-linux/
echo 'joinmarket ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo

# create config file
sudo -u joinmarket touch /home/joinmarket/joinin.conf

if [ "$1" = "--with-tor" ] || [ "$1" = "tor" ]; then

  # add default value to joinin config if needed
  checkTorEntry=$(sudo -u joinmarket cat /home/joinmarket/joinin.conf | grep -c "runBehindTor")
  if [ ${checkTorEntry} -eq 0 ]; then
    echo "runBehindTor=off" | sudo tee -a /home/joinmarket/joinin.conf
  fi

  echo "*** INSTALL TOR REPO ***"
  echo ""
  echo "*** Install dirmngr ***"
  apt install -y dirmngr apt-transport-https
  echo ""
  echo "*** Adding KEYS deb.torproject.org ***"
  torKeyAvailable=$(sudo gpg --list-keys | grep -c "A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89")
  echo "torKeyAvailable=${torKeyAvailable}"
  if [ ${torKeyAvailable} -eq 0 ]; then
    curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | sudo gpg --import
    sudo gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add -
    echo "OK"
  else
    echo "TOR key is available"
  fi
  echo ""
  echo "*** Adding Tor Sources to sources.list ***"
  torSourceListAvailable=$(sudo cat /etc/apt/sources.list | grep -c 'https://deb.torproject.org/torproject.org')
  echo "torSourceListAvailable=${torSourceListAvailable}"  
  if [ ${torSourceListAvailable} -eq 0 ]; then
    echo "Adding TOR sources ..."
    if [ "${baseImage}" = "raspbian" ] || [ "${baseImage}" = "armbian" ] || [ "${baseImage}" = "dietpi" ]; then
      echo "deb https://deb.torproject.org/torproject.org buster main" | sudo tee -a /etc/apt/sources.list
      echo "deb-src https://deb.torproject.org/torproject.org buster main" | sudo tee -a /etc/apt/sources.list
    elif [ "${baseImage}" = "ubuntu" ]; then
      echo "deb https://deb.torproject.org/torproject.org bionic main" | sudo tee -a /etc/apt/sources.list
      echo "deb-src https://deb.torproject.org/torproject.org bionic main" | sudo tee -a /etc/apt/sources.list    
    fi
    echo "OK"
  else
    echo "TOR sources are available"
  fi
  echo ""
  echo "*** INSTALL TOR ***"
  apt update
  apt install -y tor torsocks

  if ! grep -Eq "^DataDirectory" /etc/tor/torrc; then
    echo "
DataDirectory /var/lib/tor
ControlPort 9051
CookieAuthentication 1" | sudo tee -a /etc/tor/torrc
  fi
  echo "
AllowOutboundLocalhost 1" | sudo tee -a /etc/tor/torsocks.conf

  # setting value in joinin config
  sed -i "s/^runBehindTor=.*/runBehindTor=on/g" /home/joinmarket/joinin.conf
fi

# update and upgrade packages
apt update

### Hardening
echo "*** HARDENING ***"
# install packages
apt install -y virtualenv fail2ban ufw
# autostart fail2ban
systemctl enable fail2ban

# set up the firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22    comment 'allow SSH'

old_kernel=$(uname -a | grep -c "4.14.165")
if [ $old_kernel -gt 0 ]; then
  # due to the old kernel iptables needs to be configured 
  # https://superuser.com/questions/1480986/iptables-1-8-2-failed-to-initialize-nft-protocol-not-supported
  echo "switching to iptables-legacy"
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
fi
echo "enabling firewall"
sudo ufw --force enable
systemctl enable ufw
ufw status

# make folder for authorized keys 
sudo -u joinmarket mkdir -p /home/joinmarket/.ssh
sudo chmod -R 700 /home/joinmarket/.ssh

# install a command-line fuzzy finder (https://github.com/junegunn/fzf)
sudo apt -y install fzf
sudo bash -c "echo 'source /usr/share/doc/fzf/examples/key-bindings.bash' >> /home/joinmarket/.bashrc"

# install tmux
sudo apt -y install tmux

# autostart for joininbox
echo "
if [ -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
  . /home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate
  /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c \"import PySide2\"
  cd /home/joinmarket/joinmarket-clientserver/scripts/
fi
# shortcut commands
source /home/joinmarket/_commands.sh
# automatically start main menu for joinmarket unless
# when running in a tmux session
if [ -z \"\$TMUX\" ]; then
  /home/joinmarket/menu.sh
fi
" | sudo -u joinmarket tee -a /home/joinmarket/.bashrc

echo "*** READY ***"
echo ""
echo "Look through the output and press ENTER to proceed to the menu"
echo "Press CTRL + C to abort"
read key
sudo su joinmarket