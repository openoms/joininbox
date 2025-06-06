#!/usr/bin/env bash

# based on https://github.com/rootzoll/raspiblitz/blob/v1.8/home.admin/config.scripts/blitz.conf.sh

configFile="/home/joinmarket/joinin.conf"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ]; then
  echo "JoininBox Config Edit - adds value to file and creates entries if needed:"
  echo "blitz.conf.sh set [key] [value] [?conffile] <noquotes>"
  echo "blitz.conf.sh delete [key] [?conffile]"
  echo "note: use quotes and escape special characters for sed"
  echo
  exit 1
fi

if [ "$1" = "set" ]; then

  # get parameters
  keystr=$2
  valuestr=$(echo "${3}" | sed 's/\//\\\//g')

  # check that key & value are given
  if [ "${keystr}" == "" ] || [ "${valuestr}" == "" ]; then
    echo "# set.value.sh $*"
    echo "# FAIL: missing parameter"
    exit 1
  fi

  # check that config file exists
  raspiblitzConfExists=$(ls ${configFile} 2>/dev/null | grep -c "${configFile}")
  if [ ${raspiblitzConfExists} -eq 0 ]; then
    echo "# blitz.conf.sh $*"
    echo "# FAIL: missing config file: ${configFile}"
    exit 3
  fi

  # check if key needs to be added (prepare new entry)
  entryExists=$(grep -c "^${keystr}=" ${configFile})
  if [ ${entryExists} -eq 0 ]; then
    echo "${keystr}=" | sudo tee -a ${configFile} 1>/dev/null
  fi

  # add valuestr in quotes if not standard values and "$5" != "noquotes"
  if [ "${valuestr}" != "on" ] && [ "${valuestr}" != "off" ] && [ "${valuestr}" != "1" ] && [ "${valuestr}" != "0" ] && [ "$5" != "noquotes" ]; then
    valuestr="'${valuestr}'"
  fi

  # set value (sed needs sudo to operate when user is not root)
  sudo sed -i "s/^${keystr}=.*/${keystr}=${valuestr}/g" ${configFile}


elif [ "$1" = "delete" ]; then

  # get parameters
  keystr=$2

  # check that key & value are given
  if [ "${keystr}" == "" ]; then
    echo "# FAIL: missing parameter"
    exit 1
  fi

  # delete value
  sudo sed -i "/^${keystr}=/d" ${configFile} 2>/dev/null

else
  echo "# FAIL: parameter not known - run with -h for help"
fi