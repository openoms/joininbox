#!/bin/bash

testedJMversion="v0.9.4"
PGPsigner="waxwing"
PGPpkeys="https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/AdamGibson.asc"
PGPcheck="2B6FC204D9BF332D062B461A141001A1AF77F20B"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "a script to install, update or configure JoinMarket"
 echo "install.joinmarket.sh [install|config|update|testPR <PRnumber>|commit]"
 echo "the latest tested version: $testedJMversion is installed by default"
 exit 1
fi

source /home/joinmarket/_functions.sh
source /home/joinmarket/joinin.conf

# installJoinMarket [update|testPR <PRnumber>|commit]
function installJoinMarket() {
  cpu=$(uname -m)
  cd /home/joinmarket || exit 1
  # PySide2 for armf: https://packages.debian.org/buster/python3-pyside2.qtcore
  echo "# Installing ARM specific dependencies to run the QT GUI"
  sudo apt install -y python3-pyside2.qtcore python3-pyside2.qtgui \
  python3-pyside2.qtwidgets zlib1g-dev libjpeg-dev python3-pyqt5 libltdl-dev
  # https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/668#issuecomment-717815719
  sudo apt -y install build-essential automake pkg-config libffi-dev python3-dev libgmp-dev 
  sudo -u joinmarket pip install libtool asn1crypto cffi pycparser coincurve
  echo "# Installing JoinMarket"
  
  if [ "$1" = "update" ] || [ "$1" = "testPR" ] || [ "$1" = "commit" ]; then
    echo "# Deleting the old source code (joinmarket-clientserver directory)"
    sudo rm -rf /home/joinmarket/joinmarket-clientserver
  fi
  
  sudo -u joinmarket git clone https://github.com/Joinmarket-Org/joinmarket-clientserver
  cd joinmarket-clientserver || exit 1
  
  if [ "$1" = "testPR" ]; then
    PRnumber=$2
    echo "# Using the PR:"
    echo "# https://github.com/JoinMarket-Org/joinmarket-clientserver/release/tag/$PRnumber"
    git fetch origin pull/$PRnumber/head:pr$PRnumber
    git checkout pr$PRnumber
  elif [ "$1" = "commit" ]; then
    echo "# Updating to the latest commit in:"
    echo "# https://github.com/JoinMarket-Org/joinmarket-clientserver"
  elif [ "$1" = "update" ] && [ ${#2} -gt 0 ]; then
    updateVersion="$2"
    sudo -u joinmarket git reset --hard $updateVersion
  else
    sudo -u joinmarket git reset --hard $testedJMversion

    sudo -u joinmarket wget -O "pgp_keys.asc" ${PGPpkeys}
    gpg --import --import-options show-only ./pgp_keys.asc
    fingerprint=$(gpg "pgp_keys.asc" 2>/dev/null | grep "${PGPcheck}" -c)
    if [ ${fingerprint} -lt 1 ]; then
      echo
      echo "# !!! WARNING --> the PGP fingerprint is not as expected for ${PGPsigner}"
      echo "# Should contain PGP: ${PGPcheck}"
      echo "# PRESS ENTER to TAKE THE RISK if you think all is OK"
      read key
    fi
    gpg --import ./pgp_keys.asc
    
    verifyResult=$(git verify-tag $testedJMversion 2>&1)
    
    goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
    echo "# goodSignature(${goodSignature})"
    correctKey=$(echo ${verifyResult} | tr -d " \t\n\r" | grep "${PGPcheck}" -c)
    echo "# correctKey(${correctKey})"
    if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
      echo 
      echo "# !!! BUILD FAILED --> PGP verification not OK / signature(${goodSignature}) verify(${correctKey})"
      exit 1
    else
      echo 
      echo "#########################################################"
      echo "# OK --> the PGP signature of the $testedJMversion tag is correct #"
      echo "#########################################################"
      echo 
    fi
  fi

  # do not clear screen during installation
  sudo -u joinmarket sed -i 's/clear//g' install.sh
  # do not stop at installing Debian dependencies
  sudo -u joinmarket sed -i \
  "s#^        if ! sudo apt-get install \${deb_deps\[@\]}; then#\
        if ! sudo apt-get install -y \${deb_deps\[@\]}; then#g" install.sh

  if [ ${cpu} != "x86_64" ]; then
    echo "# Make install.sh set up jmvenv with -- system-site-packages on arm"
    # and import the PySide2 armf package from the system
    sudo -u joinmarket sed -i "s#^    virtualenv -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1#\
      virtualenv --system-site-packages -p \"\${python}\" \"\${jm_source}/jmvenv\" || return 1 ;\
    /home/joinmarket/joinmarket-clientserver/jmvenv/bin/python -c \'import PySide2\'\
    #g" install.sh
    # don't install PySide2 - using the system-site-package instead 
    sudo -u joinmarket sed -i "s#^PySide2.*##g" requirements/gui.txt
    # don't install PyQt5 - using the system package instead 
    sudo -u joinmarket sed -i "s#^PyQt5.*##g" requirements/gui.txt
    sudo -u joinmarket sed -i "s#PyQt5!=5.15.0,!=5.15.1,!=5.15.2,!=6.0##g" jmqtui/setup.py
  fi

  if [ "$1" = "update" ] || [ "$1" = "testPR" ] || [ "$1" = "commit" ]; then
    # build the Qt GUI, do not run libsecp256k1 test
    sudo -u joinmarket ./install.sh --with-qt --disable-secp-check || exit 1
  else
    # build the Qt GUI
    sudo -u joinmarket ./install.sh --with-qt || exit 1
  fi
  currentJMversion=$(cd /home/joinmarket/joinmarket-clientserver 2>/dev/null; \
    git describe --tags 2>/dev/null)
  echo
  echo "# installed JoinMarket $currentJMversion"
  echo
  echo "# Type: 'exit' to leave the terminal and log in again"
  echo
}

if [ "$1" = "config" ]; then
  generateJMconfig
  # show info
  dialog \
  --title "Configure JoinMarket" \
  --exit-label "Continue to edit the joinmarket.cfg" \
  --textbox "/home/joinmarket/info.conf.txt" 45 101
  # edit joinmarket.cfg
  /home/joinmarket/set.conf.sh $JMcfgPath
  exit 0
fi

if [ "$1" = "install" ]; then
  # install joinmarket
  if [ ! -f "/home/joinmarket/joinmarket-clientserver/jmvenv/bin/activate" ] ; then
    echo
    echo "# JoinMarket is not yet installed - proceeding now"
    echo
    installJoinMarket  
    errorOnInstall $?
    echo "# Check for optional dependencies: matplotlib and scipy"
    activateJMvenv
    if [ "$(pip list | grep -c matplotlib)" -eq 0 ];then
      pip install matplotlib
    fi
    if [ "$(pip list | grep -c scipy)" -eq 0 ];then
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

if [ "$1" = "update" ]; then
  stopYG
  installJoinMarket "update" "$2"
  errorOnInstall $?
  exit 0
fi

if [ "$1" = "testPR" ]; then
  stopYG
  installJoinMarket testPR $2
  errorOnInstall $?
  exit 0
fi

if [ "$1" = "commit" ]; then
  stopYG
  installJoinMarket commit
  errorOnInstall $?
  exit 0
fi