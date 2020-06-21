# JoininBox

A terminal based graphical menu for JoinMarket.

<p align="left">
  <img width="400" src="/images/menu.png">
  <img width="400" src="/images/menu.wallet.png">
</p>
<p align="left">
  <img width="400" src="/images/menu.yg.png">
  <img width="400" src="/images/menu.payjoin.png">
</p>

## Install the JoininBox menu on a RaspiBlitz v1.5+ 
* Run the script in the RaspiBlitz terminal (will install JoinMarket if not active already):
  ```bash
  # download
  wget https://raw.githubusercontent.com/openoms/joininbox/master/build_menu_on_raspiblitz.sh
  # run
  bash build_menu_on_raspiblitz.sh
  ```

## Build a dedicated JoinMarket Box remotely connected to a full node

<p align="left">
  <img width="400" src="/images/joininbox.jpeg">
</p>

* Test environments:
  * Hardkernel Odroid XU4 running Armbian
  * Raspberry Pi 3 and 4 running Raspbian
  * Debian Buster desktop
  * Connected to a RaspiBlitz 1.4 (any Bitcoin Core node can work, including previous RaspiBlitz versions)

### Install and set up the base image
* [Set up Armbian on the Hardkernel Odroid XU4](https://github.com/openoms/joininbox/blob/master/FAQ.md#set-up-armbian-on-the-hardkernel-odroid-xu4)
* [Download and verify Raspbian SDcard image for a Raspberry Pi](https://github.com/openoms/joininbox/blob/master/FAQ.md#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi)

### Set up JoininBox
* Continue to work as the `root` user or change with:  
`$ sudo - su`

* Run the build script:
  ```bash 
  # download
  wget https://raw.githubusercontent.com/openoms/joininbox/master/build_joininbox.sh
  # run (installing Tor also)
  sudo bash build_joininbox.sh --with-tor
  ```

* start the JoininBox menu by changing to the  `joinmarket` user in the terminal:  
 `$ sudo su joinmarket`  
or  
log in with ssh to:  
`joinmarket@LAN_IP_ADDRESS`

* Choose `CONFIG` in the menu to install JoinMarket (on the first run) and edit the `joinmarket.cfg`
---

## More info:

* How to [prepare a remote node to accept the JoinMarket connection](prepare_remote_node.md)
* Manual instructions on how to [build the JoininBox](build_joininbox.md)
* [Frequently Asked Questions and notes](FAQ.md)
* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)
* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)

## Forums:

* Keybase: https://keybase.io/team/raspiblitz#joinmarket  
* Telegram: https://t.me/joinmarketorg  
* IRC: #joinmarket on Freenode  
* Reddit: https://www.reddit.com/r/joinmarket/  
