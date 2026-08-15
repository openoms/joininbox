#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/v1.6/home.admin/config.scripts/internet.hiddenservice.sh
# $1 is the service name, same as the HiddenServiceDir in torrc
# $2 is the port the Hidden Service forwards to (to be used in the Tor browser)
# $3 is the port to be forwarded with the Hidden Service

# Detect failures anywhere in a pipeline (eg sed | tee): without pipefail only
# the last command's status is observed, so a failed producer writing partial
# output would go unnoticed and could yield a truncated candidate torrc.
set -o pipefail

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to configure a Tor Hidden Service"
 echo "install.hiddenservice.sh [service] [toPort] [fromPort] [optional-toPort2] [optional-fromPort2]"
 echo "install.hiddenservice.sh off [service]"
 exit 1
fi

source /home/joinmarket/_functions.sh
sourceConf /home/joinmarket/joinin.conf

# hidden-service base directory: strict absolute path, no whitespace or control
# characters, must live under an expected Tor data root
validateHiddenServiceDir() {
  case "$1" in
    /var/lib/tor|/mnt/hdd/tor) ;;
    *)
      echo "ERROR: unexpected HiddenServiceDir: $1" >&2
      echo "Expected /var/lib/tor or /mnt/hdd/tor - refusing to continue" >&2
      exit 1
      ;;
  esac
}

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

# Generate a candidate torrc without the block of the given service.
# Every stage is checked explicitly so a failed read or write never produces
# an empty or truncated candidate that would replace the live torrc.
generateTorrcCandidate() {
  service="$1"
  candidate="$2"
  # the stage file is root-owned (sudo mktemp), so the write must stay
  # inside the privileged pipeline - a plain shell redirect would be opened
  # by the unprivileged caller and fail with EACCES
  stage=$(sudo mktemp) || exit 1
  if ! sudo sed "/# Hidden Service for ${service}/,/^\s*$/{d}" /etc/tor/torrc | sudo tee "$stage" >/dev/null; then
    echo "ERROR: failed to read/process /etc/tor/torrc" >&2
    sudo rm -f -- "$stage"
    exit 1
  fi
  # a failed read must not yield an empty candidate
  if [ ! -s "$stage" ]; then
    echo "ERROR: processed torrc is empty - refusing to install" >&2
    sudo rm -f -- "$stage"
    exit 1
  fi
  if ! sudo awk 'NF > 0 {blank=0} NF == 0 {blank++} blank < 2' "$stage" | \
    sudo tee "$candidate" >/dev/null; then
    echo "ERROR: failed to write the candidate torrc" >&2
    sudo rm -f -- "$stage"
    exit 1
  fi
  if [ ! -s "$candidate" ]; then
    echo "ERROR: generated candidate is empty - refusing to install" >&2
    sudo rm -f -- "$stage"
    exit 1
  fi
  sudo rm -f -- "$stage"
}

# delete a hidden service
if [ "$1" == "off" ]; then

  service="$2"
  validateService "$service"

  candidate=$(sudo mktemp /etc/tor/torrc.joininbox.XXXXXX) || exit 1
  trap 'sudo rm -f -- "$candidate"' EXIT
  generateTorrcCandidate "$service" "$candidate"
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

if [ -z "$HiddenServiceDir" ]; then
  if [ -d "/mnt/hdd/tor" ] ; then
    HiddenServiceDir="/mnt/hdd/tor"
  else
    HiddenServiceDir="/var/lib/tor"
  fi
  echo "HiddenServiceDir=$HiddenServiceDir" >> /home/joinmarket/joinin.conf
fi
validateHiddenServiceDir "$HiddenServiceDir"

if [ "${runBehindTor}" = "on" ]; then

  candidate=$(sudo mktemp /etc/tor/torrc.joininbox.XXXXXX) || exit 1
  trap 'sudo rm -f -- "$candidate"' EXIT
  generateTorrcCandidate "$service" "$candidate"

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
  TOR_ADDRESS=$(sudo cat "$HiddenServiceDir/$service/hostname")
  if [ -z "$TOR_ADDRESS" ]; then
    echo "Waiting for the Hidden Service"
    sleep 10
    TOR_ADDRESS=$(sudo cat "$HiddenServiceDir/$service/hostname")
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
    wasAdded=$(sudo grep -c "\b127.0.0.1:$fromPort2\b" /etc/tor/torrc 2>/dev/null)
    if [ ${wasAdded} -gt 0 ]; then
      echo "or the port: $toPort2"
    fi
  fi

else
  echo "Tor is not active"
  exit 1
fi
