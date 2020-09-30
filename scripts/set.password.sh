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

# mktemp 
_temp="./dialog.$$"

# 1. parameter [?newpassword]
newPassword=$1

############################

# if no password given by parameter - ask by dialog
if [ ${#newPassword} -eq 0 ]; then
  # ask user for new password A (first time)
  dialog --backtitle "JoinInBox - Password Change"\
  --title "JoininBox - Password Change"\
  --insecure --passwordbox "
Set a new password for the users:
  'joinmarket' and 'root'
(use at least 8 characters)" 10 45 2>$_temp
  
  # get user input
  password1=$( cat $_temp )
  shred $_temp
  
  # ask user for new password A (second time)
  dialog --backtitle "JoininBox - Password Change"\
     --insecure --passwordbox "Re-enter the password:\n(This is the new password to login via SSH)" 9 56 2>$_temp
  
  # get user input
  password2=$( cat $_temp )
  shred $_temp
  
  # check if passwords match
  if [ "${password1}" != "${password2}" ]; then
    DIALOGRC=.dialogrc.onerror dialog --backtitle "JoinInBox - Password Change" --msgbox "FAIL -> Passwords don't match\nPlease try again ..." 6 56
    sudo /home/joinmarket/set.password.sh
    exit 1
  fi
  
  # password zero
  if [ ${#password1} -eq 0 ]; then
    DIALOGRC=.dialogrc.onerror dialog --backtitle "JoinInBox - Password Change" --msgbox "FAIL -> Password cannot be empty\nPlease try again ..." 6 56
    sudo /home/joinmarket/set.password.sh
    exit 1
  fi
  
  # password longer than 8
  if [ ${#password1} -lt 8 ]; then
    DIALOGRC=.dialogrc.onerror dialog --backtitle "JoinInBox - Password Change" --msgbox "FAIL -> Password length under 8\nPlease try again ..." 6 56
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
if [ "$(compgen -u | grep -c pi)" -gt 0 ]; then
  echo "pi:$newPassword" | sudo chpasswd
  piUser=" and 'pi'"
fi

sleep 1
dialog --backtitle "JoininBox - Password Change" \
--msgbox "OK - changed the password for the users:
  'joinmarket', 'root' $piUser" 6 45

exit 0
