#!/bin/bash

source /home/joinmarket/_functions.sh

# BASIC MENU INFO
HEIGHT=16
WIDTH=60
CHOICE_HEIGHT=5
TITLE="Advanced update options"
MENU="
Installed versions:
JoininBox $currentJBcommit
JoinMarket NG $currentJMNGversion
$currentBTCversion"

OPTIONS=()
BACKTITLE="JoininBox GUI"

# Basic Options
OPTIONS+=(\
  JBCOMMIT "Update JoininBox to the latest commit"
  JBPR "Test a JoininBox pull request"
  JBRESET "Reinstall the JoininBox scripts and menu"
  JMNGCUSTOM "Update JoinMarket NG to a signed release"
  TOR "Update Tor to the latest alpha"
)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Back" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  JBRESET)
      updateJoininBox reset
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JBPR)
      echo
      read -p "Enter the number of the pull request to be tested: " PRnumber
      validatePRNumber "$PRnumber" || exit 1
      echo
      echo "#################### SECURITY WARNING ####################"
      echo "# You are about to install UNVERIFIED pull-request code:"
      echo "# https://github.com/openoms/joininbox/pull/$PRnumber"
      echo "#"
      echo "# - Anyone on GitHub can open a pull request."
      echo "# - The code is NOT signed by a maintainer."
      echo "# - It will run with elevated privileges on this system."
      echo "#"
      echo "# Only proceed if you have read the PR diff and trust"
      echo "# the author. Otherwise test PRs in an isolated image."
      echo "##########################################################"
      echo
      read -p "Type 'test PR $PRnumber' to confirm: " confirm
      if [ "$confirm" != "test PR $PRnumber" ]; then
        echo "# Not confirmed - cancelling"
        exit 1
      fi
      updateJoininBox pr $PRnumber
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JBCOMMIT)
      updateJoininBox commit
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  JMNGCUSTOM)
      clear
      echo
      read -r -p "Enter the signed release version, eg '0.38.0': " updateVersion
      if ! [[ "$updateVersion" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9][A-Za-z0-9._-]*)?$ ]]; then
        echo "# Invalid signed release version"
        exit 1
      fi
      read -p "Continue to install the version:
https://github.com/joinmarket-ng/joinmarket-ng/releases/tag/${updateVersion}
(Y/N)? " confirm && [[ $confirm == [yY]||$confirm == [yY][eE][sS] ]]||exit 1
      sudo /usr/local/libexec/joininbox/install.joinmarket-ng.sh update "$updateVersion"
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
  TOR)
      updateTor
      errorOnInstall $?
      echo
      echo "Press ENTER to return to the menu"
      read key
      ;;
esac
