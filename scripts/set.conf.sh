#!/bin/bash

editScript="$1"
if [ ${#editScript} -eq 0 ]; then
  echo "please specify a file to the edit"
else
  echo "Opening $editScript"
fi
# temp conf
conf=$(mktemp -p /dev/shm/)
# trap it
trap 'rm -f $conf' 0 1 2 5 15
dialog \
--title "Editing the $editScript" \
--editbox "$editScript" 200 200 2> "$conf"
# make decison
pressed=$?
case $pressed in
  0)
    dialog --title "Finished editing" \
    --msgbox "
Saving to:
$editScript" 7 56
    sudo -u joinmarket tee "$editScript" 1>/dev/null < "$conf"
    shred "$conf";;
  1)
    shred "$conf"
    DIALOGRC=.dialogrc.onerror dialog --title "Finished editing" \
    --msgbox "
Cancelled editing:
$editScript" 7 56
    echo "Cancelled"
    exit 0;;
  255)
    shred "$conf"
    [ -s "$conf" ] &&  cat "$conf" || echo "ESC pressed."
    exit 0;;
esac