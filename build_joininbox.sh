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
  echo "Usage: sudo bash build_joininbox.sh <github user> <branch> <tag|commit> <without-qt>"
  echo "Example:"
  echo "'sudo bash build_joininbox.sh openoms master commit without-qt'"
  echo "to install from the master branch latest commit without the QT GUI"
  echo "By default uses https://github.com/openoms/joininbox/tree/master and installs the QT GUI"
  exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  echo "Root access is needed to create the dedicated user and to install system dependencies"
  exit 1
fi

echo
echo "##########################"
echo "# JOININBOX BUILD SCRIPT"
echo "##########################"
echo

githubUser="$1"
if [ ${#githubUser} -eq 0 ]; then
  githubUser="openoms"
fi

echo "# Check the command options"
wantedBranch="$2"
if [ ${#wantedBranch} -eq 0 ]; then
  wantedBranch="master"
fi

echo "
# Installing JoininBox from:
# https://github.com/${githubUser}/joininbox/tree/${wantedBranch}

# Press ENTER to confirm or CTRL+C to exit"
read key

echo
echo "###################################"
echo "# Identify the CPU and base image"
echo "###################################"
echo
cpu=$(uname -m)
echo "# CPU: ${cpu}"
if [ $(cat /etc/os-release 2>/dev/null | grep -c 'Debian') -gt 0 ]; then
  if [ $(uname -n | grep -c 'raspberrypi') -gt 0 ]; then
    # default image for RaspberryPi 64 or 32bit
    baseimage="raspios"
  elif [ $(uname -n | grep -c 'rpi') -gt 0 ] && [ "${cpu}" = aarch64 ]; then
    # a clean alternative image of debian for RaspberryPi
    baseimage="debian_rpi64"
  elif [ "${cpu}" = "arm" ] || [ "${cpu}" = "aarch64" ]; then
    # experimental: fallback for all debian on arm
    baseimage="armbian"
  else
    # experimental: fallback for all debian on other CPUs
    baseimage="debian"
  fi
elif [ $(cat /etc/os-release 2>/dev/null | grep -c 'Ubuntu') -gt 0 ]; then
  baseimage="ubuntu"
else
  echo "\n!!! FAIL: Base Image cannot be detected or is not supported."
  cat /etc/os-release 2>/dev/null
  uname -a
  exit 1
fi
echo "baseimage=${baseimage}"
echo
echo "############################"
echo "# Preparing the base image"
echo "############################"
echo

echo "# Prepare ${baseImage} "
# special prepare on RPi
if [ "${baseimage}" = "raspios" ] || [ "${baseimage}" = "debian_rpi64" ] ||
  [ "${baseimage}" = "armbian" ]; then
  # fixing locales for build
  # https://github.com/rootzoll/raspiblitz/issues/138
  # https://daker.me/2014/10/how-to-fix-perl-warning-setting-locale-failed-in-raspbian.html
  # https://stackoverflow.com/questions/38188762/generate-all-locales-in-a-docker-image
  echo "# FIXING LOCALES FOR BUILD "
  apt-get install -y locales
  sed -i "s/^# en_US.UTF-8 UTF-8.*/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/^# en_US ISO-8859-1.*/en_US ISO-8859-1/g" /etc/locale.gen
  locale-gen
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  # https://github.com/rootzoll/raspiblitz/issues/684
  sed -i "s/^    SendEnv LANG LC.*/#   SendEnv LANG LC_*/g" /etc/ssh/ssh_config
fi
if [ "${baseimage}" = "raspios" ]; then
  # only on RaspberryOS
  # remove unnecessary files
  rm -rf /home/pi/MagPi
  # https://www.reddit.com/r/linux/comments/lbu0t1/microsoft_repo_installed_on_all_raspberry_pis/
  rm -f /etc/apt/sources.list.d/vscode.list
  rm -f /etc/apt/trusted.gpg.d/microsoft.gpg
fi

if [ "${baseimage}" = "raspios" ] || [ "${baseimage}" = "debian_rpi64" ]; then
  echo -e "\n*** PREPARE RASPBERRY OS VARIANTS ***"
  if apt-get list | grep "raspi-config"; then
    sudo apt-get install -y raspi-config
    # do memory split (16MB)
    sudo raspi-config nonint do_memory_split 16
    # set to wait until network is available on boot (0 seems to yes)
    sudo raspi-config nonint do_boot_wait 0
  fi

  configFile="/boot/config.txt"
  max_usb_current="max_usb_current=1"
  max_usb_currentDone=$(grep -c "$max_usb_current" $configFile)

  if [ ${max_usb_currentDone} -eq 0 ]; then
    echo | sudo tee -a $configFile
    echo "# JoininBox" | sudo tee -a $configFile
    echo "$max_usb_current" | sudo tee -a $configFile
  else
    echo "$max_usb_current already in $configFile"
  fi

  # run fsck on sd root partition on every startup to prevent "maintenance login" screen
  # see: https://github.com/rootzoll/raspiblitz/issues/782#issuecomment-564981630
  # see https://github.com/rootzoll/raspiblitz/issues/1053#issuecomment-600878695
  # use command to check last fsck check: sudo tune2fs -l /dev/mmcblk0p2
  if [ "${tweak_boot_drive}" == "true" ]; then
    echo "* running tune2fs"
    sudo tune2fs -c 1 /dev/mmcblk0p2
  else
    echo "* skipping tweak_boot_drive"
  fi

  # edit kernel parameters
  kernelOptionsFile=/boot/cmdline.txt
  fsOption1="fsck.mode=force"
  fsOption2="fsck.repair=yes"
  fsOption1InFile=$(grep -c ${fsOption1} ${kernelOptionsFile})
  fsOption2InFile=$(grep -c ${fsOption2} ${kernelOptionsFile})

  if [ ${fsOption1InFile} -eq 0 ]; then
    sudo sed -i "s/^/$fsOption1 /g" "$kernelOptionsFile"
    echo "$fsOption1 added to $kernelOptionsFile"
  else
    echo "$fsOption1 already in $kernelOptionsFile"
  fi
  if [ ${fsOption2InFile} -eq 0 ]; then
    sudo sed -i "s/^/$fsOption2 /g" "$kernelOptionsFile"
    echo "$fsOption2 added to $kernelOptionsFile"
  else
    echo "$fsOption2 already in $kernelOptionsFile"
  fi
fi

echo
echo "# Change log rotates"
# see https://github.com/rootzoll/raspiblitz/issues/394#issuecomment-471535483
echo "/var/log/syslog" >>./rsyslog
echo "{" >>./rsyslog
echo "	rotate 7" >>./rsyslog
echo "	daily" >>./rsyslog
echo "	missingok" >>./rsyslog
echo "	notifempty" >>./rsyslog
echo "	delaycompress" >>./rsyslog
echo "	compress" >>./rsyslog
echo "	postrotate" >>./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >>./rsyslog
echo "	endscript" >>./rsyslog
echo "}" >>./rsyslog
echo "" >>./rsyslog
echo "/var/log/mail.info" >>./rsyslog
echo "/var/log/mail.warn" >>./rsyslog
echo "/var/log/mail.err" >>./rsyslog
echo "/var/log/mail.log" >>./rsyslog
echo "/var/log/daemon.log" >>./rsyslog
echo "{" >>./rsyslog
echo "        rotate 4" >>./rsyslog
echo "        size=100M" >>./rsyslog
echo "        missingok" >>./rsyslog
echo "        notifempty" >>./rsyslog
echo "        compress" >>./rsyslog
echo "        delaycompress" >>./rsyslog
echo "        sharedscripts" >>./rsyslog
echo "        postrotate" >>./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >>./rsyslog
echo "        endscript" >>./rsyslog
echo "}" >>./rsyslog
echo "" >>./rsyslog
echo "/var/log/kern.log" >>./rsyslog
echo "/var/log/auth.log" >>./rsyslog
echo "{" >>./rsyslog
echo "        rotate 4" >>./rsyslog
echo "        size=100M" >>./rsyslog
echo "        missingok" >>./rsyslog
echo "        notifempty" >>./rsyslog
echo "        compress" >>./rsyslog
echo "        delaycompress" >>./rsyslog
echo "        sharedscripts" >>./rsyslog
echo "        postrotate" >>./rsyslog
echo "                invoke-rc.d rsyslog rotate > /dev/null" >>./rsyslog
echo "        endscript" >>./rsyslog
echo "}" >>./rsyslog
echo "" >>./rsyslog
echo "/var/log/user.log" >>./rsyslog
echo "/var/log/lpr.log" >>./rsyslog
echo "/var/log/cron.log" >>./rsyslog
echo "/var/log/debug" >>./rsyslog
echo "/var/log/messages" >>./rsyslog
echo "{" >>./rsyslog
echo "	rotate 4" >>./rsyslog
echo "	weekly" >>./rsyslog
echo "	missingok" >>./rsyslog
echo "	notifempty" >>./rsyslog
echo "	compress" >>./rsyslog
echo "	delaycompress" >>./rsyslog
echo "	sharedscripts" >>./rsyslog
echo "	postrotate" >>./rsyslog
echo "		invoke-rc.d rsyslog rotate > /dev/null" >>./rsyslog
echo "	endscript" >>./rsyslog
echo "}" >>./rsyslog
mv /etc/logrotate.d/rsyslog /dev/shm/rsyslog.ori
mv ./rsyslog /etc/logrotate.d/rsyslog
chown root:root /etc/logrotate.d/rsyslog
service rsyslog restart
echo
echo "# Saved the original /etc/logrotate.d/rsyslog in the memory: /dev/shm/rsyslog.ori"
echo "# To restore original version run:"
echo "'sudo mv /dev/shm/rsyslog.ori /etc/logrotate.d/rsyslog'"
echo "'sudo service rsyslog restart'"
echo "# if not restored or copied before shutdown the /dev/shm/rsyslog.ori will be wiped."
echo

echo
echo "########################"
echo "# apt-get update & upgrade"
echo "########################"
echo
apt-get update -y
apt-get upgrade -f -y

echo
echo "##########"
echo "# Python"
echo "##########"
echo
# apt dependencies for python
apt-get install -y python3 virtualenv python3-venv python3-dev python3-wheel python3-jinja2 python3-pip
if [ "${cpu}" = "armv7l" ] || [ "${cpu}" = "armv6l" ]; then
  if [ ! -f "/usr/bin/python3.7" ]; then
    # install python37
    pythonVersion="3.7.9"
    majorPythonVersion=$(echo "$pythonVersion" | awk -F. '{print $1"."$2}')
    # dependencies
    sudo apt-get install software-properties-common build-essential libnss3-dev zlib1g-dev libgdbm-dev libncurses5-dev libssl-dev libffi-dev libreadline-dev libsqlite3-dev libbz2-dev -y
    # download
    wget --progress=bar:force https://www.python.org/ftp/python/${pythonVersion}/Python-${pythonVersion}.tgz
    # optional signature for verification
    wget --progress=bar:force https://www.python.org/ftp/python/${pythonVersion}/Python-${pythonVersion}.tgz.asc
    # get PGP pubkey of Ned Deily (Python release signing key) <nad@python.org>
    gpg --recv-key 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
    # check for: Good signature from "Pablo Galindo Salgado <pablogsal@gmail.com>"
    gpg --verify Python-${pythonVersion}.tgz.asc || (
      echo "# PGP verfication failed"
      exit 1
    )
    # unzip
    tar xvf Python-${pythonVersion}.tgz
    cd Python-${pythonVersion} || (
      echo "# Pyhton37 was not downloaded"
      exit 1
    )
    # configure
    ./configure --enable-optimizations
    # install
    make altinstall
    # move the python binary to the expected directory
    mv "$(which python${majorPythonVersion})" /usr/bin/
    # check
    ls -la /usr/bin/python${majorPythonVersion} || (
      echo "# Python37 was not installed"
      exit 1
    )
    # clean
    cd ..
    rm Python-${pythonVersion}.tgz
    rm -rf Python-${pythonVersion}
  fi
  update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
  echo "# python calls python3.7"

else
  if [ -f "/usr/bin/python3.7" ]; then
    # make sure /usr/bin/python exists (and calls Python3.7)
    update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1
    echo "# python calls python3.7"
  elif [ -f "/usr/bin/python3.8" ]; then
    # use python 3.8 if available
    update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1
    echo "# python calls python3.8"
  elif [ -f "/usr/bin/python3.9" ]; then
    # use python 3.9 if available
    update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1
    echo "# python calls python3.9"
  elif [ -f "/usr/bin/python3.10" ]; then
    # use python 3.10 if available
    update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
    echo "# python calls python3.10"
  elif [ -f "/usr/bin/python3.11" ]; then
    # use python 3.11 if available
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1
    echo "# python calls python3.11"
  else
    echo "!!! FAIL !!!"
    echo "There is no tested version of python present"
    exit 1
  fi
fi

# make sure /usr/bin/pip exists (and calls pip3)
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
# setuptools needed for Nyx
pip install setuptools

echo
echo "##########################"
echo "# apt-get packages"
echo "##########################"
echo
# system
apt-get install -y lsb-release
apt-get install -y htop git curl bash-completion vim jq bsdmainutils
# prepare for display graphics mode
# see https://github.com/rootzoll/raspiblitz/pull/334
apt-get install -y fbi
# check for dependencies on DietPi, Ubuntu, Armbian
apt-get install -y build-essential
# install ifconfig
apt-get install -y net-tools
# to display hex codes
apt-get install -y xxd
# netcat
apt-get install -y netcat
# install killall, fuser
apt-get install -y psmisc
# dialog
apt-get install -y dialog
# qrencode
apt-get install -y qrencode
# unzip for the pruned node snapshot
apt-get install -y unzip
apt-get clean
apt-get -y autoremove

echo
echo "#############"
echo "# JoininBox"
echo "#############"
echo
echo "# add the 'joinmarket' user"
adduser --disabled-password --gecos "" joinmarket

echo "# clone the joininbox repo and copy the scripts"
cd /home/joinmarket || (
  echo "# User wasn't created"
  exit 1
)
sudo -u joinmarket git clone -b ${wantedBranch} https://github.com/${githubUser}/joininbox.git

# related issue: https://github.com/openoms/joininbox/issues/102
git config --global --add safe.directory /home/joinmarket/joininbox

cd /home/joinmarket/joininbox || (
  echo "# Failed git clone"
  exit 1
)

if [ $# -lt 3 ] || [ "$3" = tag ]; then
  # use the latest tag by default
  tag=$(git tag | sort -V | tail -1)
  # reset to the last release # be aware this is alphabetical (use one digit versions)
  sudo -u joinmarket git reset --hard ${tag}

else
  if [ $# -gt 2 ] && [ "$3" != commit ]; then
    # reset to named commit if given
    sudo -u joinmarket git reset --hard $3
  fi
fi

if sudo -u joinmarket git log --show-signature --oneline | head -n3 | grep 5BFB77609B081B65; then
  PGPsigner="openoms"
  PGPpubkeyLink="https://github.com/openoms.gpg"
  PGPpubkeyFingerprint="13C688DB5B9C745DE4D2E4545BFB77609B081B65"
elif sudo -u joinmarket git log --show-signature --oneline | head -n3 | grep 4AEE18F83AFDEB23; then
  echo "# The last commit was made on GitHub and is signed with the GitHub PGP key."
  PGPsigner="web-flow"
  PGPpubkeyLink="https://github.com/${PGPsigner}.gpg"
  PGPpubkeyFingerprint="4AEE18F83AFDEB23"
fi

sudo chmod 777 /dev/shm
sudo -u joinmarket bash /home/joinmarket/joininbox/scripts/verify.git.sh \
  ${PGPsigner} ${PGPpubkeyLink} ${PGPpubkeyFingerprint} ${tag} || exit 1

sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/* /home/joinmarket/
sudo -u joinmarket cp /home/joinmarket/joininbox/scripts/.* /home/joinmarket/ 2>/dev/null
chmod +x /home/joinmarket/*.sh
sudo -u joinmarket cp -r /home/joinmarket/joininbox/scripts/standalone /home/joinmarket/
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
if [ $(grep -c pi </etc/passwd) -gt 0 ]; then
  echo "pi:joininbox" | chpasswd
fi

echo "# create the joinin.conf"
sudo -u joinmarket touch /home/joinmarket/joinin.conf

echo
echo "#######"
echo "# Tor"
echo "#######"
echo
# add default value to joinin config if needed
checkTorEntry=$(sudo -u joinmarket cat /home/joinmarket/joinin.conf |
  grep -c "runBehindTor")
if [ ${checkTorEntry} -eq 0 ]; then
  echo "runBehindTor=off" | tee -a /home/joinmarket/joinin.conf
fi

torTest=$(curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s \
  https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs)
if [ "$torTest" != "Congratulations. This browser is configured to use Tor." ]; then
  echo "# install the Tor repo"
  echo
  echo "# Install dirmngr"
  apt-get install -y dirmngr apt-transport-https
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
    echo "Adding Tor sources ..."
    arch=$(dpkg --print-architecture)
    distro=$(lsb_release -sc)
    echo "\
deb [arch=${arch}] https://deb.torproject.org/torproject.org ${distro} main
deb-src [arch=${arch}] https://deb.torproject.org/torproject.org ${distro} main" |
      sudo tee /etc/apt/sources.list.d/tor.list
    echo "OK"
  else
    echo "Tor sources are available"
  fi
  apt-get update
  if [ "${arch}" = "armhf" ]; then
    # https://2019.www.torproject.org/docs/debian#source
    echo "# running on armv6l - need to compile Tor from source"
    apt-get install -y build-essential fakeroot devscripts
    apt-get build-dep -y tor deb.torproject.org-keyring
    mkdir ~/debian-packages
    cd ~/debian-packages
    apt-get source tor
    cd tor-* || exit 1
    debuild -rfakeroot -uc -us
    cd .. || exit 1
    dpkg -i tor_*.deb
    # setup Tor in the backgound
    # TODO - test if remains in the background after the Tor service is started
    tor &
  else
    echo "# Install Tor"
    apt-get install -y tor
  fi
fi

echo "# Install torsocks and nyx"
apt-get install -y torsocks tor-arm

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
echo "# Hardening"
echo "#############"
echo
# install packages
apt-get install -y fail2ban ufw
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

# make a folder for authorized keys
sudo -u joinmarket mkdir -p /home/joinmarket/.ssh
chmod -R 700 /home/joinmarket/.ssh

# deny root login via ssh
if grep -Eq "^PermitRootLogin" /etc/ssh/sshd_config; then
  sed -i "s/^PermitRootLogin.*/PermitRootLogin  no/g" /etc/ssh/sshd_config
else
  echo "PermitRootLogin  no" >>/etc/ssh/sshd_config
fi
systemctl restart ssh

echo
echo "##########"
echo "# Extras"
echo "##########"
echo

# install a command-line fuzzy finder (https://github.com/junegunn/fzf)
apt-get -y install fzf
bash -c "echo 'source /usr/share/doc/fzf/examples/key-bindings.bash' >> \
/home/joinmarket/.bashrc"

# install tmux
apt-get -y install tmux

echo
echo "#############"
echo "# Autostart"
echo "#############"
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

echo "#########################"
echo "# Download Bitcoin Core"
echo "#########################"
echo
sudo -u joinmarket /home/joinmarket/install.bitcoincore.sh downloadCoreOnly || exit 1

echo
echo "######################"
echo "# Install JoinMarket"
echo "######################"

qtgui=true
checkEntry=$(sudo -u joinmarket cat /home/joinmarket/joinin.conf | grep -c "qtgui")
if [ ${checkEntry} -eq 0 ]; then
  echo "qtgui=true" | tee -a /home/joinmarket/joinin.conf
fi
if [ "$4" = "without-qt" ]; then
  qtgui="false"
  sed -i "s/^qtgui=.*/qtgui=false/g" /home/joinmarket/joinin.conf
fi
sudo -u joinmarket /home/joinmarket/install.joinmarket.sh -i install -q "$qtgui" || exit 1

echo "###################"
echo "# bootstrap.service"
echo "###################"
sudo chmod +x /home/joinmarket/standalone/bootstrap.sh
sudo cp /home/joinmarket/joininbox/scripts/standalone/bootstrap.service \
  /etc/systemd/system/bootstrap.service
sudo systemctl enable bootstrap

echo
echo "###########################"
echo "# The base image is ready"
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
