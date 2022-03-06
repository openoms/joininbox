#!/bin/bash

# based on https://github.com/RPi-Distro/raspi-config/blob/d98686647ced7c0c0490dc123432834735d1c13d/raspi-config#L157

# do_expand_rootfs
function do_expand_rootfs() {
  ROOT_PART="$(findmnt / -o source -n)"
  ROOT_DEV="/dev/$(lsblk -no pkname "$ROOT_PART")"

  PART_NUM="$(echo "$ROOT_PART" | grep -o "[[:digit:]]*$")"

  # NOTE: the NOOBS partition layout confuses parted. For now, let's only
  # agree to work with a sufficiently simple partition layout
  if [ "$PART_NUM" -ne 2 ]; then
    whiptail --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
    return 0
  fi

  LAST_PART_NUM=$(parted "$ROOT_DEV" -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ $LAST_PART_NUM -ne $PART_NUM ]; then
    whiptail --msgbox "$ROOT_PART is not the last partition. Don't know how to expand" 20 60 2
    return 0
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted "$ROOT_DEV" -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk "$ROOT_DEV" <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs "$ROOT_PART" &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

# check if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (with sudo)"
  exit
fi

# fix locales
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8

echo "# Expanding the root partition ..."
if [ -f /usr/lib/armbian/armbian-resize-filesystem ];then
  echo "# Running: 'sudo /usr/lib/armbian/armbian-resize-filesystem start'"
  sudo /usr/lib/armbian/armbian-resize-filesystem start
  sed -i "s#setupStep=.*#setupStep=7#g" /home/joinmarket/joinin.conf
else
  do_expand_rootfs
  sed -i "s#setupStep=.*#setupStep=7#g" /home/joinmarket/joinin.conf
  echo
  echo "# Need to reboot for the filesystem to enlarge"
  echo "# Log in again with ssh and use the new password set"
  echo
  echo "# Press ENTER to restart ..."
  read key
  echo
  sudo shutdown -h -r now
fi