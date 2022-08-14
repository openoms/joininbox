#!/bin/bash
# script to create a self-signed SSL certificate

USERNAME=jam

sudo apt install nginx

if [ ! -f  /home/jam/nginx/tls.cert ] || [ ! -f  /home/jam/nginx/tls.key ];then
  sudo apt-get install openssl

  subj="/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=example.com"
  sudo -u $USERNAME mkdir -p /home/jam/nginx/ \
   && pushd "$_" \
   && sudo -u $USERNAME openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out tls.cert -keyout tls.key -subj "$subj" \
   && popd || exit 1

else
  echo " /home/jam/nginx/cert.pem and key.pem is already present"
fi

if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
  sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi