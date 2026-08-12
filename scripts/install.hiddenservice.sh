#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/v1.6/home.admin/config.scripts/internet.hiddenservice.sh
# $1 is the service name, same as the HiddenServiceDir in torrc
# $2 is the port the Hidden Service forwards to (to be used in the Tor browser)
# $3 is the port to be forwarded with the Hidden Service

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to configure a Tor Hidden Service"
 echo "install.hiddenservice.sh [service] [toPort] [fromPort] [optional-toPort2] [optional-fromPort2]"
 echo "install.hiddenservice.sh off [service]"
 exit 1
fi

source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

validateService() {
  case "$1" in
    ''|*[!A-Za-z0-9_-]*)
      echo "ERROR: invalid service name: $1" >&2
      exit 1
      ;;
  esac
}

validatePort() {
  case "$1" in
    ''|*[!0-9]*)
      echo "ERROR: invalid port: $1" >&2
      exit 1
      ;;
  esac
  if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
    echo "ERROR: port outside the range 1-65535: $1" >&2
    exit 1
  fi
}

# Install a candidate torrc only after Tor accepts it. The temporary file lives
# next to torrc so the final rename is atomic and remains root-owned.
installTorrc() {
  candidate="$1"
  sudo chmod 644 "$candidate"
  sudo chown root:root "$candidate"
  if ! sudo tor --verify-config -f "$candidate"; then
    echo "ERROR: Tor rejected the generated configuration" >&2
    sudo rm -f -- "$candidate"
    exit 1
  fi
  sudo mv -f -- "$candidate" /etc/tor/torrc
}

# delete a hidden service
if [ "$1" == "off" ]; then

  service="$2"
  validateService "$service"

  candidate=$(sudo mktemp /etc/tor/torrc.joininbox.XXXXXX) || exit 1
  trap 'sudo rm -f -- "$candidate"' EXIT
  sudo sed "/# Hidden Service for ${service}/,/^\s*$/{d}" /etc/tor/torrc | \
    awk 'NF > 0 {blank=0} NF == 0 {blank++} blank < 2' | \
    sudo tee "$candidate" >/dev/null || exit 1
  installTorrc "$candidate"
  trap - EXIT

  echo "# OK service is removed - reloading Tor ..."
  sudo systemctl reload tor
  sleep 5
  echo "# Done"
  exit 0
fi

service="$1"
validateService "$service"

toPort="$2"
if [ ${#toPort} -eq 0 ]; then
  echo "ERROR: the port to forward to is missing"
  exit 1
fi

fromPort="$3"
validatePort "$toPort"
validatePort "$fromPort"

# not mandatory
toPort2="$4"

# needed if $4 is given
fromPort2="$5"
if [ ${#toPort2} -gt 0 ]; then
  if [ ${#fromPort2} -eq 0 ]; then
    echo "ERROR: the second port to forward from is missing"
    exit 1
  fi
  validatePort "$toPort2"
  validatePort "$fromPort2"
fi

checkDirEntry=$(grep -c "HiddenServiceDir" < /home/joinmarket/joinin.conf)
if [ "$checkDirEntry" -eq 0 ]; then
  if [ -d "/mnt/hdd/tor" ] ; then
    HiddenServiceDir="/mnt/hdd/tor"
  else
    HiddenServiceDir="/var/lib/tor"
  fi
  echo "HiddenServiceDir=$HiddenServiceDir" >> /home/joinmarket/joinin.conf
fi

if [ "${runBehindTor}" = "on" ]; then

  candidate=$(sudo mktemp /etc/tor/torrc.joininbox.XXXXXX) || exit 1
  trap 'sudo rm -f -- "$candidate"' EXIT
  sudo sed "/# Hidden Service for ${service}/,/^\s*$/{d}" /etc/tor/torrc | \
    awk 'NF > 0 {blank=0} NF == 0 {blank++} blank < 2' | \
    sudo tee "$candidate" >/dev/null || exit 1

  echo "
# Hidden Service for $service
HiddenServiceDir $HiddenServiceDir/$service
HiddenServiceVersion 3
HiddenServicePort $toPort 127.0.0.1:$fromPort" | sudo tee -a "$candidate" >/dev/null

  # check and insert second port pair
  if [ ${#toPort2} -gt 0 ]; then
    alreadyThere=$(sudo grep -c "\b127.0.0.1:$fromPort2\b" "$candidate" 2>/dev/null)
    if [ ${alreadyThere} -gt 0 ]; then
      echo "The port $fromPort2 is already forwarded. Check the /etc/tor/torrc for the details."
    else
      echo "HiddenServicePort $toPort2 127.0.0.1:$fromPort2" | sudo tee -a "$candidate" >/dev/null
    fi
  fi

  installTorrc "$candidate"
  trap - EXIT

  # reload tor
  echo
  echo "Reloading Tor to activate the Hidden Service..."
  sudo systemctl reload tor
  sleep 10

  # show the Hidden Service address
  TOR_ADDRESS=$(sudo cat $HiddenServiceDir/$service/hostname)
  if [ -z "$TOR_ADDRESS" ]; then
    echo "Waiting for the Hidden Service"
    sleep 10
    TOR_ADDRESS=$(sudo cat $HiddenServiceDir/$service/hostname)
    if [ -z "$TOR_ADDRESS" ]; then
      echo " FAIL - The Hidden Service address could not be found - Tor error?"
      exit 1
    fi
  fi
  echo
  echo "The Tor Hidden Service address for $service is:"
  echo "$TOR_ADDRESS"
  echo "use with the port: $toPort"
  if [ ${#toPort2} -gt 0 ]; then
    wasAdded=$(sudo cat /etc/tor/torrc 2>/dev/null | grep -c "\b127.0.0.1:$fromPort2\b")
    if [ ${wasAdded} -gt 0 ]; then
      echo "or the port: $toPort2"
    fi
  fi

else
  echo "Tor is not active"
  exit 1
fi
