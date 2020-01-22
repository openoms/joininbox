#!/bin/bash
rm -r /home/joinin/joininbox
git clone https://github.com/openoms/joininbox.git

rm /home/joinin/*.sh
rm /home/joinin/*.py

cp ./joininbox/scripts/* /home/joinin/
chmod +x /home/joinin/*.sh
chmod +x /home/joinin/*.py
