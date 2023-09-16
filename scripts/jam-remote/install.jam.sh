#!/bin/bash

# https://github.com/joinmarket-webui/jam

USERNAME=jam
WEBUI_VERSION="4d0479e"
REPO=joinmarket-webui/jam
HOME_DIR=/home/${USERNAME}
APP_DIR=webui
SOURCEDIR=$(pwd)

PGPsigner="dergigi"
PGPpubkeyLink="https://github.com/${PGPsigner}.gpg"
PGPpubkeyFingerprint="89C4A25E69A5DE7F"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to switch jam on or off"
  echo "install.jam.sh [on|off|menu|update|update commit|precheck]"
  exit 1
fi

# show info menu
if [ "$1" = "menu" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -eq 1 ]; then
    # get network info
    fingerprint=$(openssl x509 -in /home/${USERNAME}/nginx/tls.cert -fingerprint -noout | cut -d"=" -f2)
    whiptail --title " JAM " --msgbox "Open in your local web browser & accept self-signed cert:
https://localhost:7501\n
with Fingerprint:
${fingerprint}\n
" 15 57
  else
    echo "*** JAM IS NOT INSTALLED ***"
  fi
  exit 0
fi

# switch on
if [ "$1" = "on" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -eq 0 ]; then

    echo "*** INSTALL JAM ***"

    echo "# Creating the ${USERNAME} user"
    echo
    sudo adduser --system --group --home /home/${USERNAME} ${USERNAME}

    # install nodeJS
    bash ${SOURCEDIR}/bonus.nodejs.sh on

    # install Jam
    cd $HOME_DIR || exit 1

    sudo -u $USERNAME git clone https://github.com/$REPO

    cd jam || exit 1
    sudo -u $USERNAME git reset --hard ${WEBUI_VERSION}

    #sudo -u $USERNAME bash ${SOURCEDIR}/../verify.git.sh \
    #  "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" "v${WEBUI_VERSION}" || exit 1

    cd $HOME_DIR || exit 1
    sudo -u $USERNAME mv jam $APP_DIR
    cd $APP_DIR || exit 1
    sudo -u $USERNAME rm -rf docker
    if ! sudo -u $USERNAME npm install; then
      echo "FAIL - npm install did not run correctly, aborting"
      exit 1
    fi

    sudo -u $USERNAME npm run build

    ##################
    # NGINX
    ##################
    # setup nginx symlinks
    sudo cp -f ${SOURCEDIR}/nginx/sites-available/jam_ssl.conf /etc/nginx/sites-available/jam_ssl.conf
    sudo cp -r ${SOURCEDIR}/nginx/snippets /etc/nginx/
    sudo ln -sf /etc/nginx/sites-available/jam_ssl.conf /etc/nginx/sites-enabled/

    bash ${SOURCEDIR}/install.selfsignedcert.sh

    sudo nginx -t
    sudo systemctl reload nginx

  fi

  bash ${SOURCEDIR}/install.jam.sh menu

  exit 0
fi

# update
if [ "$1" = "update" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -gt 0 ]; then
    echo "*** UPDATE JAM ***"
    cd $HOME_DIR || exit 1

    if [ "$2" = "commit" ]; then
      echo "# Remove old source code"
      sudo rm -rf jam
      sudo rm -rf $APP_DIR
      echo "# Downloading the latest commit in the default branch of $REPO"
      sudo -u $USERNAME git clone https://github.com/$REPO
    else
      version=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
      cd $APP_DIR || exit 1
      current=$(node -p "require('./package.json').version")
      cd ..
      if [ "$current" = "$version" ]; then
        echo "*** JAM IS ALREADY UPDATED TO LATEST RELEASE ***"
        exit 0
      fi

      echo "# Remove old source code"
      sudo rm -rf jam
      sudo rm -rf $APP_DIR
      sudo -u $USERNAME git clone https://github.com/$REPO
      cd jam || exit 1
      sudo -u $USERNAME git reset --hard v${version}

      sudo -u $USERNAME bash ${SOURCEDIR}/../verify.git.sh \
        "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" "v${version}" || exit 1

      cd $HOME_DIR || exit 1
      sudo -u $USERNAME mv jam $APP_DIR
      cd $APP_DIR || exit 1
      sudo -u $USERNAME rm -rf docker
      if ! sudo -u $USERNAME npm install; then
        echo "FAIL - npm install did not run correctly, aborting"
        exit 1
      fi
      echo "*** JAM UPDATED to $version ***"
    fi

    if ! sudo -u $USERNAME npm install; then
      echo "FAIL - npm install did not run correctly, aborting"
      exit 1
    fi
    sudo -u $USERNAME npm run build

  else
    echo "*** JAM NOT INSTALLED ***"
  fi

  exit 0
fi

# switch off
if [ "$1" = "off" ]; then
  echo "*** UNINSTALL JAM ***"

  if [ -d /home/jam ]; then
    sudo userdel -rf jam 2>/dev/null
    echo "Removed the jam user"
  else
    echo "There is no /home/jam present"
  fi

  # close ports on firewall
  sudo ufw delete allow from any to any port 7500
  sudo ufw delete allow from any to any port 7501

  # remove nginx symlinks and config
  sudo rm -f /etc/nginx/sites-enabled/jam*
  sudo rm -f /etc/nginx/sites-available/jam*
  sudo nginx -t
  sudo systemctl reload nginx

  # remove the app
  sudo rm -rf $HOME_DIR/$APP_DIR 2>/dev/null

  # remove SSL
  sudo rm -rf $HOME_DIR/.joinmarket/ssl

  echo "OK Jam is removed."

  exit 0
fi

echo "FAIL - Unknown Parameter $1"
exit 1
