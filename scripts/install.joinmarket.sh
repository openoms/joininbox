#!/bin/bash

# https://github.com/JoinMarket-Org/joinmarket-clientserver/releases
testedJMversion="v0.9.11"

PGPsigner="kristapsk"
PGPpkeys="https://github.com/kristapsk.gpg"
PGPcheck="33E472FE870C7E5D"

#PGPsigner="waxwing"
#PGPpkeys="https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/AdamGibson.asc"
#PGPcheck="2B6FC204D9BF332D062B461A141001A1AF77F20B"

me="${0##/*}"

nocolor="\033[0m"
red="\033[31m"

## see https://github.com/rootzoll/raspiblitz/blob/v1.7/build_sdcard.sh for code comments
usage() {
  printf %s"${me} [--option <argument>]

a script to install, update or configure JoinMarket
the latest tested version: $testedJMversion is installed by default with the QT GUI

Options:
-h, --help                                           this help info
-i, --install [install|config|update|testPR|commit]  install options, use 'commit' for the latest master
-v, --version [version|number-of-PR]                 the version to install or PR to test (default: ${testedJMversion})
-q, --qtgui [0|1]                                    install the QT GUI and dependencies (default: 0)
-u, --user [user]                                    the linux user to install with (default: joinmarket)

Notes:
  all options, long and short accept --opt=value mode also
  [0|1] can also be referenced as [false|true]

"
  exit 1
}
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
fi

error_msg() {
  printf %s"${red}${me}: ${1}${nocolor}\n"
  exit 1
}
assign_value() {
  case "${2}" in
  --*) value="${2#--}" ;;
  -*) value="${2#-}" ;;
  *) value="${2}" ;;
  esac
  case "${value}" in
  0) value="false" ;;
  1) value="true" ;;
  esac
  eval "${1}"="\"${value}\""
}

get_arg() {
  case "${3}" in
  "" | -*) error_msg "Option '${2}' requires an argument." ;;
  esac
  assign_value "${1}" "${3}"
}

range_argument() {
  name="${1}"
  eval var='$'"${1}"
  shift
  if [ -n "${var:-}" ]; then
    success=0
    for tests in "${@}"; do
      [ "${var}" = "${tests}" ] && success=1
    done
    [ ${success} -ne 1 ] && error_msg "Option '--${name}' cannot be '${var}'! It can only be: ${*}."
  fi
}

while :; do
  case "${1}" in
  -*=*)
    opt="${1%=*}"
    arg="${1#*=}"
    shift_n=1
    ;;
  -*)
    opt="${1}"
    arg="${2}"
    shift_n=2
    ;;
  *)
    opt="${1}"
    arg="${2}"
    shift_n=1
    ;;
  esac
  case "${opt}" in
  -i | -i=* | --install | --install=*) get_arg install "${opt}" "${arg}" ;;
  -v | -v=* | --version | --version=*) get_arg version "${opt}" "${arg}" ;;
  -q | -q=* | --qtgui | --qtgui=*) get_arg qtgui "${opt}" "${arg}" ;;
  -u | -u=* | --user | --user=*) get_arg user "${opt}" "${arg}" ;;
  "") break ;;
  *) error_msg "Invalid option: ${opt}" ;;
  esac
  shift "${shift_n}"
done

: "${install:=install}"
range_argument install "install" "config" "update" "testPR" "commit"

: "${version:=${testedJMversion}}"
curl -s "https://github.com/JoinMarket-Org/joinmarket-clientserver/release/tag/${version}" | grep -q "\"message\": \"Version not found\"" && error_msg "'There is no: https://github.com/JoinMarket-Org/joinmarket-clientserver/release/tag/${version}'"

: "${qtgui:=false}"
range_argument qtgui "0" "1" "false" "true"

: "${user:=joinmarket}"

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

# create user if not default
if [ "${user}" != "joinmarket" ]; then
  echo "# add the '${user}' user"
  sudo adduser --system --group --shell /bin/bash --home /home/${user} ${user}
  echo "Copy the skeleton files for login"
  sudo -u ${user} cp -r /etc/skel/. /home/${user}/
  sudo adduser ${user} sudo
  # add user to Tor group
  sudo usermod -a -G debian-tor ${user}
  # configure for usage without password entry
  checkEntry=$(sudo cat /etc/sudoers | grep -c "${user} ALL=(ALL) NOPASSWD:ALL")
  if [ ${checkEntry} -eq 0 ]; then
    echo "${user} ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
  fi
  # Autostart
  checkEntry=$(sudo -u ${user} cat /home/${user}/.bashrc | grep -c "jmvenv/bin/activate")
  if [ ${checkEntry} -eq 0 ]; then
    echo "
if [ -f \"/home/${user}/joinmarket-clientserver/jmvenv/bin/activate\" ]; then
  . /home/${user}/joinmarket-clientserver/jmvenv/bin/activate
  cd /home/${user}/joinmarket-clientserver/scripts/
fi
" | sudo -u ${user} tee -a /home/${user}/.bashrc
  fi
fi

# qtgui entry in joinin.conf
checkEntry=$(sudo -u ${user} cat /home/${user}/joinin.conf | grep -c "qtgui")
if [ ${checkEntry} -eq 0 ]; then
  echo "qtgui=true" | sudo -u ${user} tee -a /home/${user}/joinin.conf
fi
sudo -u ${user} sed -i "s/^qtgui=.*/qtgui=${qtgui}/g" /home/${user}/joinin.conf

# installJoinMarket [update|testPR <PRnumber>|commit]
function installJoinMarket() {
  cd /home/${user} || exit 1
  # https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/668#issuecomment-717815719
  sudo apt-get install -y build-essential automake pkg-config libffi-dev python3-dev
  sudo -u ${user} pip config set global.break-system-packages true
  sudo -u ${user} pip install libtool asn1crypto cffi pycparser
  echo "# Installing JoinMarket"

  if [ "$install" = "update" ] || [ "$install" = "testPR" ] || [ "$install" = "commit" ]; then
    echo "# Deleting the old source code (joinmarket-clientserver directory)"
    sudo rm -rf /home/${user}/joinmarket-clientserver
  fi

  sudo -u ${user} git clone https://github.com/Joinmarket-Org/joinmarket-clientserver
  cd joinmarket-clientserver || exit 1

  if [ "$install" = "testPR" ]; then
    PRnumber=$2
    echo "# Using the PR:"
    echo "# https://github.com/JoinMarket-Org/joinmarket-clientserver/release/tag/$PRnumber"
    sudo -u ${user} git fetch origin pull/$PRnumber/head:pr$PRnumber
    sudo -u ${user} git checkout pr$PRnumber
  elif [ "$install" = "commit" ]; then
    echo "# Updating to the latest commit in:"
    echo "# https://github.com/JoinMarket-Org/joinmarket-clientserver"
  elif [ "$install" = "update" ] && [ ${#2} -gt 0 ]; then
    updateVersion="$2"
    sudo -u ${user} git reset --hard $updateVersion
  else
    sudo -u ${user} git reset --hard $testedJMversion

    sudo -u ${user} wget --prefer-family=ipv4 -O "pgp_keys.asc" ${PGPpkeys}
    sudo -u ${user} gpg --import --import-options show-only ./pgp_keys.asc
    fingerprint=$(sudo -u ${user} gpg "pgp_keys.asc" 2>/dev/null | grep "${PGPcheck}" -c)
    if [ ${fingerprint} -lt 1 ]; then
      echo
      echo "# WARNING --> the PGP fingerprint is not as expected for ${PGPsigner}"
      echo "# Should contain PGP: ${PGPcheck}"
      echo "# PRESS ENTER to TAKE THE RISK if you think all is OK"
      read -r
    fi
    sudo -u ${user} gpg --import ./pgp_keys.asc

    verifyResult=$(sudo -u ${user} git verify-tag $testedJMversion 2>&1)

    goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
    echo "# goodSignature(${goodSignature})"
    correctKey=$(echo ${verifyResult} | tr -d " \t\n\r" | grep "${PGPcheck}" -c)
    echo "# correctKey(${correctKey})"
    if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
      echo
      echo "# BUILD FAILED --> PGP verification not OK / signature(${goodSignature}) verify(${correctKey})"
      exit 1
    else
      echo
      echo "#########################################################"
      echo "# OK --> the PGP signature of the $testedJMversion tag is correct"
      echo "#########################################################"
      echo
    fi
  fi

  # Use specific python version, if set
  python_args=""
  if [[ -n "${JM_PYTHON}" ]]; then
    python_args="--python=${JM_PYTHON}"
  fi
  # do not clear screen during installation
  sudo -u ${user} sed -i 's/clear//g' install.sh

  if [ "${qtgui}" = "false" ]; then
    GUIchoice="--without-qt"
  else
    GUIchoice="--with-qt"
  fi

  if [ "$install" = "update" ] || [ "$install" = "testPR" ] || [ "$install" = "commit" ]; then
    # do not run libsecp256k1 test
    sudo -u ${user} ./install.sh "${GUIchoice}" --disable-secp-check "$python_args" || exit 1
  else
    sudo -u ${user} ./install.sh "${GUIchoice}" "$python_args" || exit 1
  fi
  currentJMversion=$(
    cd /home/${user}/joinmarket-clientserver 2>/dev/null
    git describe --tags 2>/dev/null
  )
  echo
  echo "# installed JoinMarket $currentJMversion"
  echo
  echo "# Type: 'exit' to leave the terminal and log in again"
  echo
}

if [ "$install" = "config" ]; then
  if [ ! -f "$JMcfgPath" ]; then
    generateJMconfig
  fi
  # show info
  dialog \
    --title "Configure JoinMarket" \
    --exit-label "Continue to edit the joinmarket.cfg" \
    --textbox "/home/joinmarket/info.conf.txt" 43 108
  # edit joinmarket.cfg
  /home/${user}/set.conf.sh $JMcfgPath
  exit 0
fi

if [ "$install" = "install" ]; then
  # install joinmarket
  if [ ! -f "/home/${user}/joinmarket-clientserver/jmvenv/bin/activate" ]; then
    echo
    echo "# JoinMarket is not yet installed - proceeding now"
    echo
    installJoinMarket
    errorOnInstall $?
    echo "# Check for optional dependencies: matplotlib and scipy"
    activateJMvenv
    if [ "$(pip list | grep -c matplotlib)" -eq 0 ]; then
      pip install matplotlib
    fi
    if [ "$(pip list | grep -c scipy)" -eq 0 ]; then
      # https://stackoverflow.com/questions/7496547/does-python-scipy-need-blas
      sudo apt-get install -y gfortran libopenblas-dev liblapack-dev
      # fix 'No space left on device' with 2GB RAM
      export TMPDIR='/var/tmp'
      pip install scipy
      export TMPDIR='/tmp'
    fi
  else
    echo
    echo "# JoinMarket $currentJMversion is installed"
    echo
  fi
  exit 0
fi

if [ "$install" = "update" ]; then
  stopYG
  installJoinMarket "update" "$2"
  errorOnInstall $?
  exit 0
fi

if [ "$install" = "testPR" ]; then
  stopYG
  installJoinMarket testPR $2
  errorOnInstall $?
  exit 0
fi

if [ "$install" = "commit" ]; then
  stopYG
  installJoinMarket commit
  errorOnInstall $?
  exit 0
fi
