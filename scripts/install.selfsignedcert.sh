#!/bin/bash
# script to create a self-signed SSL certificate

USERNAME=joinmarket
HOME_DIR=/home/$USERNAME

if [ ! -f ${HOME_DIR}/.joinmarket/ssl/cert.pem ] || [ ! -f ${HOME_DIR}/.joinmarket/ssl/key.pem ];then
  sudo apt-get install openssl

  if [ -d $HOME_DIR/.joinmarket/ssl ]; then
    sudo -u $USERNAME rm -rf $HOME_DIR/.joinmarket/ssl
  fi

  subj="/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=example.com"
  sudo -u $USERNAME mkdir -p $HOME_DIR/.joinmarket/ssl/ \
   && pushd "$_" \
   && sudo -u $USERNAME openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out cert.pem -keyout key.pem -subj "$subj" \
   && popd || exit 1

else
  echo "${HOME_DIR}/.joinmarket/ssl/cert.pem and key.pem is already present"
fi
