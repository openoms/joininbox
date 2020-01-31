#!/bin/bash

# command info
if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "JoininBox setup with optional Tor install"
 echo "sudo build_joininbox.sh [--with-tor]"
 exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit
fi

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

echo "*** Add the 'joinin' user ***"
adduser --disabled-password --gecos "" joinin

echo "*** Clone the joininbox repo and copy the scripts ***"
cd /home/joinin
sudo -u joinin git clone https://github.com/openoms/joininbox.git
sudo -u joinin cp ./joininbox/scripts/* /home/joinin/
sudo -u joinin cp ./joininbox/scripts/.* /home/joinin/ 2>/dev/null

chmod +x /home/joinin/*.sh
chmod +x /home/joinin/*.py

echo "*** Setting the password for the users 'joinin' and 'root' ***"
apt install dialog
/home/joinin/setpassword.sh
echo "joinin:$PASSWORD" | sudo chpasswd
adduser joinin sudo
# chsh joinin -s /bin/bash
# configure sudo for usage without password entry for the joinin user
# https://www.tecmint.com/run-sudo-command-without-password-linux/
echo 'joinin ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo


if [ "$1" = "--with-tor" ] || [ "$1" = "tor" ]; then
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
  apt install tor torsocks
fi

# update and upgrade packages
apt update

### Hardening
echo "*** HARDENING ***"
# install packages
apt install -y git virtualenv fail2ban ufw
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
sudo -u joinin mkdir -p ~/.ssh
sudo chmod -R 700 /home/joinin/.ssh

# install a command-line fuzzy finder (https://github.com/junegunn/fzf)
sudo apt -y install fzf
sudo bash -c "echo 'source /usr/share/doc/fzf/examples/key-bindings.bash' >> /home/joinin/.bashrc"

# install tmux
sudo apt -y install tmux

# hold off autostart for now
# bash autostart for joinin
#sudo bash -c "echo '# shortcut commands' >> /home/joinin/.bashrc"
#sudo bash -c "echo 'source /home/joinin/_commands.sh' >> /home/joinin/.bashrc"
#sudo bash -c "echo '# automatically start main menu for joinin unless' >> /home/joinin/.bashrc"
#sudo bash -c "echo '# when running in a tmux session' >> /home/joinin/.bashrc"
#sudo bash -c "echo 'if [ -z \"\$TMUX\" ]; then' >> /home/joinin/.bashrc"
#sudo bash -c "echo '  ./menu.sh' >> /home/joinin/.bashrc"
#sudo bash -c "echo 'fi' >> /home/joinin/.bashrc"

echo "*** READY ***"
echo ""
echo "Look through the output and press ENTER to proceed to the menu"
echo "Press CTRL + C to abort"
read key
su - joinin