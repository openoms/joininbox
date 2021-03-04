#!/bin/bash
# based on https://github.com/rootzoll/raspiblitz/blob/master/home.admin/config.scripts/blitz.set.password.sh

# command info
if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "script to set a passwords for the users 'joinmarket', 'root' (and 'pi')"
  echo "sudo set.password.sh [?newpassword] "
  echo "or just as a password enter dialog (result as file)"
  exit 1
fi

# check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit
fi

piUserPresent=$(compgen -u | grep -c pi)
if [ "$piUserPresent" -gt 0 ]; then
  piUser="and 'pi'"
fi

# mktemp in the RAM
_temp="$(mktemp -p /dev/shm/)"

# 1. parameter [?newpassword]
newPassword=$1

# if no password given by parameter - ask by dialog
if [ ${#newPassword} -eq 0 ]; then
  # ask user for new password A (first time)
  DIALOGRC=/home/joinmarket/.dialogrc dialog\
  --backtitle "JoininBox - Password Change"\
  --title "JoininBox - Password Change"\
  --insecure --passwordbox "
Set a new password for the users:
'joinmarket' and 'root' $piUser
Use at least 8 characters." 11 56 2>$_temp
  
  # get user input
  password1=$( cat $_temp )
  shred $_temp
  
  # ask user for new password A (second time)
  DIALOGRC=/home/joinmarket/.dialogrc dialog \
  --backtitle "JoininBox - Password Change"\
  --title "Confirm Password Change"\
  --insecure --passwordbox "
Confirm the new password.
This will be required to login via SSH.
  " 11 56 2>$_temp
  
  # get user input
  password2=$( cat $_temp )
  shred $_temp
  
  # check if passwords match
  if [ "${password1}" != "${password2}" ]; then
    DIALOGRC=/home/joinmarket/.dialogrc.onerror dialog \
    --backtitle "JoininBox - Password Change" \
    --msgbox "FAIL -> Passwords don't match\nPlease try again ..." 6 56
    sudo /home/joinmarket/set.password.sh
    exit 1
  fi
  
  # password zero
  if [ ${#password1} -eq 0 ]; then
    DIALOGRC=/home/joinmarket/.dialogrc.onerror dialog \
    --backtitle "JoininBox - Password Change" \
    --msgbox "FAIL -> Password cannot be empty\nPlease try again ..." 6 56
    sudo /home/joinmarket/set.password.sh
    exit 1
  fi
  
  # password longer than 8
  if [ ${#password1} -lt 8 ]; then
    DIALOGRC=/home/joinmarket/.dialogrc.onerror dialog \
    --backtitle "JoininBox - Password Change" \
    --msgbox "FAIL -> Password length under 8\nPlease try again ..." 6 56
    sudo /home/joinmarket/set.password.sh
    exit 1
  fi
  
  # use entered password now as parameter
  newPassword=$password1

fi

# change user passwords
echo "joinmarket:$newPassword" | sudo chpasswd
echo "root:$newPassword" | sudo chpasswd
# change password for 'pi' if present
if [ "$piUserPresent" -gt 0 ]; then
  echo "pi:$newPassword" | sudo chpasswd
fi

sleep 1
DIALOGRC=/home/joinmarket/.dialogrc dialog \
--backtitle "JoininBox - Password Change" \
--msgbox "OK - changed the password for the users:
  'joinmarket', 'root' $piUser" 6 45

