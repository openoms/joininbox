

# This script runs on every start called by boostrap.service
# It makes sure that the system is configured like the
# default values or as in the config.

################################
# BASIC SETTINGS
################################

# load codeVersion
source /home/admin/_version.info

# CONFIGFILE - configuration of RaspiBlitz
# used by fresh SD image to recover configuration
# and delivers basic config info for scripts 
# make raspiblitz.conf if not there
sudo touch /mnt/hdd/raspiblitz.conf
configFile="/mnt/hdd/raspiblitz.conf"

# LOGFILE - store debug logs of bootstrap
# resets on every start
logFile="/home/admin/raspiblitz.log"

# INFOFILE - state data from bootstrap
# used by display and later setup steps
infoFile="/home/admin/raspiblitz.info"


# FUNCTIONS to be used later on in the script

# wait until raspberry pi gets a local IP
function wait_for_local_network() {
  gotLocalIP=0
  until [ ${gotLocalIP} -eq 1 ]
  do
    localip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0' | egrep -i '(*[eth|ens|enp|eno|wlan|wlp][0-9]$)' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    if [ ${#localip} -eq 0 ]; then
      configWifiExists=$(sudo cat /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null| grep -c "network=")
      if [ ${configWifiExists} -eq 0 ]; then
        # display user to connect LAN
        sed -i "s/^state=.*/state=noIP/g" ${infoFile}
        sed -i "s/^message=.*/message='Connect the LAN/WAN'/g" ${infoFile}
      else
        # display user that wifi settings are not working
        sed -i "s/^state=.*/state=noIP/g" ${infoFile}
        sed -i "s/^message=.*/message='WIFI Settings not working'/g" ${infoFile}
      fi
    elif [ "${localip:0:4}" = "169." ]; then
      # display user waiting for DHCP
      sed -i "s/^state=.*/state=noDCHP/g" ${infoFile}
      sed -i "s/^message=.*/message='Waiting for DHCP'/g" ${infoFile}
    else
      gotLocalIP=1
    fi
    sleep 1
  done
}

# wait until raspberry pi gets a local IP
function wait_for_internet() {
  online=0
  until [ ${online} -eq 1 ]
  do
    # check for internet connection
    online=$(ping 1.0.0.1 -c 1 -W 2 | grep -c '1 received')
    if [ ${online} -eq 0 ]; then
      # re-test with other server
      online=$(ping 8.8.8.8 -c 1 -W 2 | grep -c '1 received')
    fi
    if [ ${online} -eq 0 ]; then
      # re-test with other server
      online=$(ping 208.67.222.222 -c 1 -W 2 | grep -c '1 received')
    fi
    if [ ${online} -eq 0 ]; then
      sed -i "s/^state=.*/state=noInternet/g" ${infoFile}
      sed -i "s/^message=.*/message='Network OK but NO Internet'/g" ${infoFile}
    fi
    sleep 1
  done
}

echo "Writing logs to: ${logFile}"
echo "" > $logFile
echo "***********************************************" >> $logFile
echo "Running RaspiBlitz Bootstrap ${codeVersion}" >> $logFile
date >> $logFile
echo "***********************************************" >> $logFile

# set default values for raspiblitz.info
network=""
chain=""
setupStep=0
fsexpanded=0
lcd2hdmi="off"

# try to load old values if available (overwrites defaults)
source ${infoFile} 2>/dev/null

# resetting info file
echo "Resetting the InfoFile: ${infoFile}"
echo "state=starting" > $infoFile
echo "message=" >> $infoFile
echo "network=${network}" >> $infoFile
echo "chain=${chain}" >> $infoFile
echo "fsexpanded=${fsexpanded}" >> $infoFile
echo "lcd2hdmi=${lcd2hdmi}" >> $infoFile
echo "setupStep=${setupStep}" >> $infoFile
if [ "${setupStep}" != "100" ]; then
  echo "hostname=${hostname}" >> $infoFile
fi
sudo chmod 777 ${infoFile}

################################
# IDENTIFY CPU ARCHITECTURE
################################

cpu="?"
isARM=$(uname -m | grep -c 'arm')
isAARCH64=$(uname -m | grep -c 'aarch64')
isX86_64=$(uname -m | grep -c 'x86_64')
if [ ${isARM} -gt 0 ]; then
  cpu="arm"
elif [ ${isAARCH64} -gt 0 ]; then
  cpu="aarch64"
elif [ ${isX86_64} -gt 0 ]; then
  cpu="x86_64"
fi
echo "cpu=${cpu}" >> $infoFile

################################
# IDENTIFY BASEIMAGE
################################

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
echo "baseimage=${baseImage}" >> $infoFile

# resetting start count files
echo "SYSTEMD RESTART LOG: blockchain (bitcoind/litecoind)" > /home/admin/systemd.blockchain.log
echo "SYSTEMD RESTART LOG: lightning (LND)" > /home/admin/systemd.lightning.log
sudo chmod 777 /home/admin/systemd.blockchain.log
sudo chmod 777 /home/admin/systemd.lightning.log

# Emergency cleaning logs when over 1GB (to prevent SD card filling up)
# see https://github.com/rootzoll/raspiblitz/issues/418#issuecomment-472180944
echo "*** Checking Log Size ***"
logsMegaByte=$(sudo du -c -m /var/log | grep "total" | awk '{print $1;}')
if [ ${logsMegaByte} -gt 1000 ]; then
  echo "WARN !! Logs /var/log in are bigger then 1GB"
  echo "ACTION --> DELETED ALL LOGS"
  if [ -d "/var/log/nginx" ]; then
    nginxLog=1
    echo "/var/log/nginx is present"
  fi
  sudo rm -r /var/log/*
  if [ $nginxLog == 1 ]; then
    sudo mkdir /var/log/nginx
    echo "Recreated /var/log/nginx"
  fi
  sleep 3
  echo "WARN !! Logs in /var/log in were bigger then 1GB and got emergency delete to prevent fillup."
  echo "If you see this in the logs please report to the GitHub issues, so LOG config needs to hbe optimized."
else
  echo "OK - logs are at ${logsMegaByte} MB - within safety limit"
fi
echo ""

################################
# GENERATE UNIQUE SSH PUB KEYS
# on first boot up
################################

numberOfPubKeys=$(sudo ls /etc/ssh/ | grep -c 'ssh_host_')
if [ ${numberOfPubKeys} -eq 0 ]; then
  echo "*** Generating new SSH PubKeys" >> $logFile
  sudo dpkg-reconfigure openssh-server
  echo "OK" >> $logFile
fi

################################
# SSH SERVER CERTS RESET
# if a file called 'ssh.reset' gets
# placed onto the boot part of
# the sd card - switch to hdmi
################################

sshReset=$(sudo ls /boot/ssh.reset* 2>/dev/null | grep -c reset)
if [ ${sshReset} -eq 1 ]; then
  # delete that file (to prevent loop)
  sudo rm /boot/ssh.reset*
  # show info ssh reset
  sed -i "s/^state=.*/state=sshreset/g" ${infoFile}
  sed -i "s/^message=.*/message='resetting SSH & reboot'/g" ${infoFile}
  # delete ssh certs
  sudo systemctl stop sshd
  sudo rm /mnt/hdd/ssh/ssh_host*
  sudo ssh-keygen -A
  sudo /home/admin/XXshutdown.sh reboot
  exit 0
fi