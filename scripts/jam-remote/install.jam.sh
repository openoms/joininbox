#!/bin/bash

# https://github.com/joinmarket-webui/joinmarket-webui

USERNAME=jam
HOME_DIR=/home/$USERNAME
REPO=joinmarket-webui/joinmarket-webui
APP_DIR=webui
WEBUI_VERSION=0.0.10
SOURCEDIR=$(pwd)

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to switch jam on or off"
  echo "bonus.joinmarket-webui.sh [on|off|menu|update|update commit|precheck]"
  exit 1
fi

# show info menu
if [ "$1" = "menu" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -eq 1 ]; then
    # get network info
    fingerprint=$(openssl x509 -in /home/jam/nginx/tls.cert -fingerprint -noout | cut -d"=" -f2)
    whiptail --title " JAM " --msgbox "Open in your local web browser & accept self-signed cert:
https://localhost:7501\n
with Fingerprint:
${fingerprint}\n
" 15 57
  else
    echo "*** JAM NOT INSTALLED ***"
  fi
exit 0
fi


# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -eq 0 ]; then

    echo "*** INSTALL JAM ***"

    echo "# Creating the electrs user"
    echo
    sudo adduser --disabled-password --gecos "" jam

    # install nodeJS
    bash ${SOURCEDIR}/bonus.nodejs.sh on

    # install JAM
    cd $HOME_DIR || exit 1

    sudo -u $USERNAME git clone https://github.com/$REPO

    cd joinmarket-webui || exit 1
    sudo -u $USERNAME git reset --hard v${WEBUI_VERSION}

    GITHUB_SIGN_AUTHOR="web-flow"
    GITHUB_SIGN_PUBKEYLINK="https://github.com/web-flow.gpg"
    GITHUB_SIGN_FINGERPRINT="4AEE18F83AFDEB23"
    sudo -u $USERNAME bash ${SOURCEDIR}/../verify.git.sh \
     "${GITHUB_SIGN_AUTHOR}" "${GITHUB_SIGN_PUBKEYLINK}" "${GITHUB_SIGN_FINGERPRINT}" || exit 1

    cd $HOME_DIR || exit 1
    sudo -u $USERNAME mv joinmarket-webui $APP_DIR
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

    sudo nginx -t
    sudo systemctl reload nginx


    bash ${SOURCEDIR}/install.selfsignedcert.sh

  fi
  bash ${SOURCEDIR}/install.jam.sh menu
  exit 0
fi


# update
if [ "$1" = "update" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ ${isInstalled} -eq 1 ]; then
    echo "*** UPDATE JAM ***"
    cd $HOME_DIR

    if [ "$2" = "commit" ]; then
      echo "# Updating to the latest commit in the default branch"
      sudo -u $USERNAME wget https://github.com/$REPO/archive/refs/heads/master.tar.gz
      sudo -u $USERNAME tar -xzf master.tar.gz
      sudo -u $USERNAME rm -rf master.tar.gz
      sudo -u $USERNAME mv joinmarket-webui-master $APP_DIR-update
    else
      version=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
      cd $APP_DIR
      current=$(node -p "require('./package.json').version")
      cd ..
      if [ "$current" = "$version" ]; then
        echo "*** JAM IS ALREADY UPDATED TO LATEST VERSION ***"
        exit 0
      fi
      sudo -u $USERNAME wget https://github.com/$REPO/archive/refs/tags/v$version.tar.gz
      sudo -u $USERNAME tar -xzf v$version.tar.gz
      sudo -u $USERNAME rm v$version.tar.gz
      sudo -u $USERNAME mv joinmarket-webui-$version $APP_DIR-update
    fi

    cd $APP_DIR-update || exit 1
    sudo -u $USERNAME rm -rf docker
    sudo -u $USERNAME npm install
    if ! [ $? -eq 0 ]; then
      echo "FAIL - npm install did not run correctly, aborting"
      exit 1
    fi

    sudo -u $USERNAME npm run build
    if ! [ $? -eq 0 ]; then
      echo "FAIL - npm run build did not run correctly, aborting"
      exit 1
    fi
    cd ..
    sudo -u $USERNAME rm -rf $APP_DIR
    sudo -u $USERNAME mv $APP_DIR-update $APP_DIR

    echo "*** JAM UPDATED ***"
  else
    echo "*** JAM NOT INSTALLED ***"
  fi

  exit 0
fi


# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then
  isInstalled=$(sudo ls $HOME_DIR 2>/dev/null | grep -c "$APP_DIR")
  if [ "${isInstalled}" -eq 1 ]; then
    echo "*** UNINSTALL JAM ***"

    # close ports on firewall
    sudo ufw delete allow from any to any port 7500 comment 'allow JAM HTTP'
    sudo ufw delete allow from any to any port 7501 comment 'allow JAM HTTPS'

    # remove nginx symlinks
    sudo rm -f /etc/nginx/sites-enabled/jam*
    sudo rm -f /etc/nginx/sites-available/jam*
    sudo nginx -t
    sudo systemctl reload nginx

    # remove the app
    sudo rm -rf $HOME_DIR/$APP_DIR

    # remove SSL
    sudo rm -rf $HOME_DIR/.joinmarket/ssl

    sudo userdel -rf jam
    echo "OK JAM removed."
  else
    echo "*** JAM NOT INSTALLED ***"
  fi

  exit 0
fi

echo "FAIL - Unknown Parameter $1"
exit 1
