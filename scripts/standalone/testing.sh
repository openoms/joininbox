echo
echo "# Deleting the joinin.conf ..."
echo "# Will be recreated when the menu is next run."
sudo rm /home/joinmarket/joinin.conf 2>/dev/null
echo "# OK"

if [ $# -gt 0 ]&&[ "$1" = purge ];then
  sudo userdel -r bitcoin
  sudo userdel -r store
  sudo userdel -r specter
  rm -rf /home/joinmarket/bitcoin
  rm -rf /home/joinmarket/download
  sudo shutdown now -r
fi