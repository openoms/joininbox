#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/master/home.admin/config.scripts/blitz.set.password.sh

# command info
if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "script to set passwords for the users 'joinmarket', 'root' (and 'pi')"
  echo "sudo set.password.sh"
  echo "Interactive only - passwords are never accepted as arguments."
  exit 0
fi

# never accept secrets on the command line -
# they would leak via 'ps', shell history and systemd-cgtop
if [ $# -gt 0 ]; then
  echo "ERROR: refusing to take a password as a command-line argument." >&2
  echo "Secrets passed as arguments leak via 'ps', shell history and logs." >&2
  echo "Run 'sudo set.password.sh' without arguments for the interactive prompt." >&2
  exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit 1
fi

piUserPresent=$(compgen -u | grep -cx pi)
if [ "$piUserPresent" -gt 0 ]; then
  piUser="and 'pi'"
fi

# mktemp in the RAM (mode 600 by default - not readable by other users)
trap 'rm -f "$_temp"' EXIT
_temp="$(mktemp -p /dev/shm/)"
chmod 600 "$_temp"

# use dialog only if available and attached to a terminal
useDialog=0
if command -v dialog >/dev/null 2>&1 && [ -t 1 ]; then
  useDialog=1
fi

# clear the temp file holding a typed password
clearTemp() {
  if [ -f "$_temp" ]; then
    shred "$_temp" 2>/dev/null || rm -f "$_temp"
  fi
}

# read a password without echoing (fallback when dialog cannot be used)
# $1 = prompt text
readSecret() {
  local input
  read -r -s -p "$1" input
  # prompt/newline are UI output, not part of the secret captured by callers
  echo >&2
  printf '%s' "$input"
}

# ask a yes/no question, returns 0 for yes
# $1 = question text
askYesNo() {
  if [ "$useDialog" -eq 1 ]; then
    DIALOGRC=/home/joinmarket/.dialogrc dialog \
    --backtitle "JoininBox - Password Change" \
    --yesno "$1" 8 56
    return $?
  else
    local answer
    read -r -p "$1 [y/N] " answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
    return $?
  fi
}

# show an info/error message
# $1 = message text
showMessage() {
  if [ "$useDialog" -eq 1 ]; then
    DIALOGRC=/home/joinmarket/.dialogrc.onerror dialog \
    --backtitle "JoininBox - Password Change" \
    --msgbox "$1" 8 56
  else
    echo "$1"
  fi
}

# prompt for a new password with confirmation and validation
# $1 = description of the account(s) the password is for
# sets the global variable 'newPassword'
promptPassword() {
  local label="$1"
  local password1 password2
  while true; do
    if [ "$useDialog" -eq 1 ]; then
      # ask user for new password (first time)
      if ! DIALOGRC=/home/joinmarket/.dialogrc dialog \
      --backtitle "JoininBox - Password Change" \
      --title "JoininBox - Password Change" \
      --insecure --passwordbox "
Set a new password for $label
Use at least 8 characters." 11 56 2>"$_temp"; then
        clearTemp
        echo "Cancelled." >&2
        exit 1
      fi
      password1=$(cat "$_temp")
      clearTemp

      # ask user for new password (second time)
      if ! DIALOGRC=/home/joinmarket/.dialogrc dialog \
      --backtitle "JoininBox - Password Change" \
      --title "Confirm Password Change" \
      --insecure --passwordbox "
Confirm the new password.
This will be required to login via SSH.
  " 11 56 2>"$_temp"; then
        clearTemp
        echo "Cancelled." >&2
        exit 1
      fi
      password2=$(cat "$_temp")
      clearTemp
    else
      password1=$(readSecret "New password for $label: ")
      password2=$(readSecret "Confirm the new password: ")
    fi

    # check if passwords match
    if [ "${password1}" != "${password2}" ]; then
      showMessage "FAIL -> Passwords don't match
Please try again ..."
      continue
    fi

    # password zero
    if [ ${#password1} -eq 0 ]; then
      showMessage "FAIL -> Password cannot be empty
Please try again ..."
      continue
    fi

    # password longer than 8
    if [ ${#password1} -lt 8 ]; then
      showMessage "FAIL -> Password length under 8
Please try again ..."
      continue
    fi

    newPassword=$password1
    unset password1 password2
    return 0
  done
}

# set the password of one account
# $1 = username, $2 = password
setUserPassword() {
  printf '%s:%s\n' "$1" "$2" | chpasswd
}

# build the account list
accounts="joinmarket root"
if [ "$piUserPresent" -gt 0 ]; then
  accounts="$accounts pi"
fi

if askYesNo "Use the same password for all accounts?
('joinmarket', 'root' $piUser)"; then
  promptPassword "the users: 'joinmarket', 'root' $piUser"
  for account in $accounts; do
    setUserPassword "$account" "$newPassword"
  done
  unset newPassword
  sleep 1
  showMessage "OK - changed the password for the users:
  'joinmarket', 'root' $piUser"
else
  for account in $accounts; do
    promptPassword "the user: '$account'"
    setUserPassword "$account" "$newPassword"
    unset newPassword
  done
  sleep 1
  showMessage "OK - changed the passwords for the users:
  'joinmarket', 'root' $piUser"
fi
