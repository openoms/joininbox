#!/bin/bash

########################################################################
# setup a Linux environment see: 
# https://github.com/openoms/joininbox#tested-environments-for-joininbox
# login with SSH or boot directly
# run this script as root or with sudo
# can specify donwloading from a branch or forked repo:
# bash build_joininbox.sh [branch] [github user]
########################################################################

# The JoininBox Build Script is partially based on:
# https://github.com/rootzoll/raspiblitz/blob/master/build_sdcard.sh

# command info
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "JoininBox Build Script" 
  echo "Usage: bash build_joininbox.sh [branch] [github user]"
  echo "Example: bash bash build_joininbox.sh dev openoms"
  exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  echo "Root access is needed to create the dedicated user to install system dependencies"
  exit 1
fi

echo 
echo "###############################"
echo "# JOININBOX BUILD SCRIPT v0.2 #"
echo "###############################"
echo 

echo "# Check the command options"
wantedBranch="$1"
if [ ${#wantedBranch} -eq 0 ]; then
  wantedBranch="master"
fi

githubUser="$2"
if [ ${#githubUser} -eq 0 ]; then
  githubUser="openoms"
fi

echo "
# Installing JoininBox from: 
# https://github.com/${githubUser}/joininbox/tree/${wantedBranch}

# Press ENTER to confirm or CTRL+C to exit"
read key

echo 
echo "###################################"
echo "# Identify the CPU and base image #"
echo "###################################"
echo 
cpu=$(uname -m)
echo "# CPU: ${cpu}"
baseImage="?"
isBuster=$(grep -c 'buster' < /etc/os-release)
isBionic=$(grep -c 'bionic' < /etc/os-release)
isFocal=$(grep -c 'focal' < /etc/os-release)
isDietPi=$(uname -n | grep -c 'DietPi')
isRaspbian=$(grep -c 'Raspbian' < /etc/os-release)
if [ ${isBuster} -gt 0 ]; then
  baseImage="buster"
fi 
if [ ${isBionic} -gt 0 ]; then
  baseImage="bionic"
fi
if [ ${isFocal} -gt 0 ]; then
  baseImage="focal"
fi
if [ ${isDietPi} -gt 0 ]; then
  baseImage="dietpi"
fi
if [ ${isRaspbian} -gt 0 ]; then
  baseImage="raspbian"
fi
if [ "${baseImage}" = "?" ]; then
  cat /etc/os-release 2>/dev/null
  echo "# !!! FAIL !!!"
  echo "# Base image cannot be detected or is not supported."
  exit 1
else
  echo "# Base image: ${baseImage}"
fi

echo 
echo "############################"
echo "# Preparing the base image #"
echo "############################"
echo 
if [ "${baseImage}" = "raspbian" ]||[ "${baseImage}" = "dietpi" ]||\
   [ "${baseImage}" = "buster" ]; then
  # fixing locales for build
  # https://github.com/rootzoll/raspiblitz/issues/138
  # https://daker.me/2014/10/how-to-fix-perl-warning-setting-locale-failed-in-raspbian.html
  # https://stackoverflow.com/questions/38188762/generate-all-locales-in-a-docker-image
  echo
  echo "# FIXING LOCALES FOR BUILD "
  apt install -y locales
  sed -i "s/^# en_US.UTF-8 UTF-8.*/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/^# en_US ISO-8859-1.*/en_US ISO-8859-1/g" /etc/locale.gen
  locale-gen
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  # https://github.com/rootzoll/raspiblitz/issues/684
  sed -i "s/^    SendEnv LANG LC.*/#   SendEnv LANG LC_*/g" /etc/ssh/ssh_config
  # only on RaspberryOS
  # remove unnecessary files
  rm -rf /home/pi/MagPi
  # https://www.reddit.com/r/linux/comments/lbu0t1/microsoft_repo_installed_on_all_raspberry_pis/
  rm -f /etc/apt/sources.list.d/vscode.list 
  rm -f /etc/apt/trusted.gpg.d/microsoft.gpg
fi

if [ -f "/usr/bin/python3.7" ]; then
  # make sure /usr/bin/python exists (and calls Python3.7 in Debian Buster)
  update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
  echo "# python calls python3.7"
elif [ -f "/usr/bin/python3.8" ]; then
  # use python 3.8 if available
  update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1
  echo "# python calls python3.8"
else
  echo "!!! FAIL !!!"
  echo "There is no tested version of python present"
  exit 1
fi
echo
echo "# PREPARE ${baseImage} "

# special prepare when Raspbian
if [ "${baseImage}" = "raspbian" ]; then
  # do memory split (16MB)
 raspi-config nonint do_memory_split 16
  # set to wait until network is available on boot (0 seems to yes)
 raspi-config nonint do_boot_wait 0
  # set WIFI country so boot does not block
 raspi-config nonint do_wifi_country US
  # see https://github.com/rootzoll/raspiblitz/issues/428#issuecomment-472822840
  echo "max_usb_current=1" |tee -a /boot/config.txt
  # run fsck on sd boot partition on every startup to prevent "maintenance login" screen
  # see: https://github.com/rootzoll/raspiblitz/issues/782#issuecomment-564981630
  # use command to check last fsck check: tune2fs -l /dev/mmcblk0p2
 tune2fs -c 1 /dev/mmcblk0p2
  # see https://github.com/rootzoll/raspiblitz/issues/1053#issuecomment-600878695
 sed -i 's/^/fsck.mode=force fsck.repair=yes /g' /boot/cmdline.txt
fi

echo 
echo "# change log rotates"
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
mv ./rsyslog /etc/logrotate.d/rsyslog
chown root:root /etc/logrotate.d/rsyslog
service rsyslog restart

echo 
echo "###############################"
echo "# Apt update & upgrade        #"
echo "###############################"
echo 
apt-get update -y
apt-get upgrade -f -y

echo 
echo "##########################"
echo "# Tools and dependencies #"
echo "##########################"
echo 
apt-get install -y htop git curl bash-completion vim jq bsdmainutils
# prepare for display graphics mode
# see https://github.com/rootzoll/raspiblitz/pull/334
apt-get install -y fbi
# check for dependencies on DietPi, Ubuntu, Armbian
apt install -y build-essential
# dependencies for python
apt install -y python3-venv python3-dev python3-wheel python3-jinja2 \
python3-pip
# make sure /usr/bin/pip exists (and calls pip3 in Debian Buster)
aptupdate-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
# install ifconfig
apt install -y net-tools
# to display hex codes
apt install -y xxd
# setuptools needed for Nyx
aptpip install setuptools
# netcat
apt install -y netcat
# install killall, fuser
apt-get install -y psmisc
# dialog
apt install -y dialog
apt-get clean
apt-get -y autoremove

echo 
echo "#############"
echo "# JoininBox #"
echo "#############"
echo 
echo "# add the 'joinmarket' user"
adduser --disabled-password --gecos "" joinmarket

echo "# clone the joininbox repo and copy the scripts"
cd /home/joinmarket
sudo -u joinmarket git clone -b ${wantedBranch} https://github.com/${githubUser}/joininbox.git
sudo -u joinmarket cp ./joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp ./joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
chmod +x /home/joinmarket/*.sh
sudo -u joinmarket cp -r ./joininbox/scripts/standalone /home/joinmarket/
chmod +x /home/joinmarket/standalone/*.sh

echo "# set the default password 'joininbox' for the users 'pi', \
'joinmarket' and 'root'"
adduser joinmarket sudo
# chsh joinmarket -s /bin/bash
# configure for usage without password entry for the joinmarket user
# https://www.tecmint.com/run-sudo-command-without-password-linux/
echo 'joinmarket ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo
echo "root:joininbox" | chpasswd
echo "joinmarket:joininbox" | chpasswd
if [ $(grep -c pi  < /etc/passwd) -gt 0 ];then
  echo "pi:joininbox" | chpasswd
fi

echo "# create the joinin.conf"
sudo -u joinmarket touch /home/joinmarket/joinin.conf

echo 
echo "#######"
echo "# Tor #"
echo "#######"
echo 
# add default value to joinin config if needed
checkTorEntry=$(sudo -u joinmarket cat /home/joinmarket/joinin.conf | \
grep -c "runBehindTor")
if [ ${checkTorEntry} -eq 0 ]; then
  echo "runBehindTor=off" | tee -a /home/joinmarket/joinin.conf
fi

torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
if [ "$torTest" != "Congratulations. This browser is configured to use Tor." ]
then
  echo "# install the Tor repo"
  echo 
  echo "# Install dirmngr"
  apt install -y dirmngr apt-transport-https
  echo 
  echo "# Adding KEYS deb.torproject.org "
  torKeyAvailable=$(gpg --list-keys | grep -c \
  "A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89")
  echo "torKeyAvailable=${torKeyAvailable}"
  if [ ${torKeyAvailable} -eq 0 ]; then
    # https://support.torproject.org/apt/tor-deb-repo/
    wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
    gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
    echo "OK"
  else
    echo "# Tor key is available"
  fi
  echo "# Adding Tor Sources to sources.list"
  torSourceListAvailable=$(cat /etc/apt/sources.list | grep -c \
  'https://deb.torproject.org/torproject.org')
  echo "torSourceListAvailable=${torSourceListAvailable}"  
  if [ ${torSourceListAvailable} -eq 0 ]; then
    echo "Adding TOR sources ..."
    if [ "${baseImage}" = "raspbian" ]||[ "${baseImage}" = "buster" ]||[ "${baseImage}" = "dietpi" ]; then
      echo "deb https://deb.torproject.org/torproject.org buster main" | tee -a /etc/apt/sources.list
      echo "deb-src https://deb.torproject.org/torproject.org buster main" | tee -a /etc/apt/sources.list
    elif [ "${baseImage}" = "bionic" ]; then
      echo "deb https://deb.torproject.org/torproject.org bionic main" | tee -a /etc/apt/sources.list
      echo "deb-src https://deb.torproject.org/torproject.org bionic main" | tee -a /etc/apt/sources.list
    elif [ "${baseImage}" = "focal" ]; then
      echo "deb https://deb.torproject.org/torproject.org focal main" | tee -a /etc/apt/sources.list
      echo "deb-src https://deb.torproject.org/torproject.org focal main" | tee -a /etc/apt/sources.list    
    fi
    echo "OK"
  else
    echo "Tor sources are available"
  fi
  apt update
  if [ "$cpu" = "armv6l" ]; then
    # https://2019.www.torproject.org/docs/debian#source
    echo "# running on armv6l - need to compile Tor from source"
    apt install -y build-essential fakeroot devscripts
    apt build-dep -y tor deb.torproject.org-keyring
    mkdir ~/debian-packages; cd ~/debian-packages
    apt source tor
    cd tor-*
    debuild -rfakeroot -uc -us
    cd ..
    dpkg -i tor_*.deb
    # setup Tor in the backgound
    # TODO - test if remains in the background after the Tor service is started
    tor &
  else
    echo "# Install Tor"
    apt install -y tor
  fi
fi

# test Tor
tries=0
while [ "$torTest" != "Congratulations. This browser is configured to use Tor." ]
do
  echo "# waiting another 10 seconds for Tor"
  echo "# press CTRL + C to abort"
  sleep 10
  tries=$((tries+1))
  if [ $tries = 100 ]; then
    echo "# FAIL - Tor was not set up successfully"
    exit 1
  fi
  torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
  https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
done
echo
echo "# $torTest"
echo
echo "# Tor has been tested successfully"
echo
echo "# install torsocks and nyx"
apt install -y torsocks tor-arm

# Tor config
# torrc
if ! grep -Eq "^DataDirectory" /etc/tor/torrc; then
  echo "DataDirectory /var/lib/tor" | tee -a /etc/tor/torrc
fi
if ! grep -Eq "^ControlPort 9051" /etc/tor/torrc; then
  echo "ControlPort 9051" | tee -a /etc/tor/torrc
fi
if ! grep -Eq "^CookieAuthentication 1" /etc/tor/torrc; then
  echo "CookieAuthentication 1" | tee -a /etc/tor/torrc
fi
sed -i "s:^CookieAuthFile*:#CookieAuthFile:g" /etc/tor/torrc
# torsocks.conf
if ! grep -Eq "^AllowOutboundLocalhost 1" /etc/tor/torsocks.conf; then          
  echo "AllowOutboundLocalhost 1" | tee -a /etc/tor/torsocks.conf
fi
# add the joinmarket user to the tor group
usermod -a -G debian-tor joinmarket
# setting value in joinin config
sed -i "s/^runBehindTor=.*/runBehindTor=on/g" /home/joinmarket/joinin.conf

echo 
echo "#############"
echo "# Hardening #"
echo "#############"
echo 
# install packages
apt install -y virtualenv fail2ban ufw
# autostart fail2ban
systemctl enable fail2ban

# set up the firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22 comment 'allow SSH'

old_kernel=$(uname -a | grep -c "4.14.165")
if [ $old_kernel -gt 0 ]; then
  # due to the old kernel iptables needs to be configured 
  # https://superuser.com/questions/1480986/iptables-1-8-2-failed-to-initialize-nft-protocol-not-supported
  echo "switching to iptables-legacy"
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
fi
echo "# enabling the firewall"
ufw --force enable
systemctl enable ufw
ufw status

# make folder for authorized keys 
sudo -u joinmarket mkdir -p /home/joinmarket/.ssh
chmod -R 700 /home/joinmarket/.ssh

# install a command-line fuzzy finder (https://github.com/junegunn/fzf)
apt -y install fzf
bash -c "echo 'source /usr/share/doc/fzf/examples/key-bindings.bash' >> \
/home/joinmarket/.bashrc"

# install tmux
apt -y install tmux

echo 
echo "#############"
echo "# Autostart #"
echo "#############"
echo 
echo "
if [ -f \"/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate\" ]; then
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


echo 
echo "#########################"
echo "# Download Bitcoin Core #"
echo "#########################"
echo 
sudo -u joinmarket /home/joinmarket/install.bitcoincore.sh downloadCoreOnly

echo 
echo "######################"
echo "# Install JoinMarket #"
echo "######################"
echo 
sudo -u joinmarket /home/joinmarket/install.joinmarket.sh install

echo
echo "###########################"
echo "# The Base Image is ready #"
echo "###########################"
echo 
echo "Look through / save this output and continue with:"
echo "'su - joinmarket'"
echo
echo "To make an SDcard image safe to share use:"
echo "'/home/joinmarket/standalone/prepare.release.sh'"
echo
echo "the ssh login credentials are until the first login:"
echo "user:joinmarket"
echo "password:joininbox"
echo 