#!/bin/bash

# script to create a self-signed SSL certificate

USERNAME=joinmarket
HOME_DIR=/home/$USERNAME

if [ ! -f ${HOME_DIR}/selfsignedcert/cert.pem ] || [ ! -f ${HOME_DIR}/selfsignedcert/key.pem ];then
  sudo apt install openssl

  sudo -u ${USERNAME} mkdir ${HOME_DIR}/selfsignedcert
  cd ${HOME_DIR}/selfsignedcert || exit 1

  echo "# Create a self signed SSL certificate"
  localip=$(hostname -I | awk '{print $1}')

  sudo -u ${USERNAME} openssl genrsa -out key.pem 2048

  echo "
[req]
prompt             = no
default_bits       = 2048
default_keyfile    = key.pem
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = v3_ca

[req_distinguished_name]
C = GB
ST = London
L = JoinMarket
O = Joininbox
CN = Joininbox
[req_ext]
subjectAltName = @alt_names
[v3_ca]
subjectAltName = @alt_names
[alt_names]
DNS.1   = localhost
DNS.2   = 127.0.0.1
DNS.3   = $localip
" | sudo -u ${USERNAME} tee localhost.conf

  sudo -u ${USERNAME} openssl req -new -x509 -sha256 -key key.pem \
   -out cert.pem -days 3650 -config localhost.conf

fi