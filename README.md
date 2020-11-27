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

## Build a dedicated JoinMarket Box remotely connected to a full node

<p align="left">
  <img width="400" src="/images/joininbox.jpeg">
</p>

* Test environments:
  * Hardkernel Odroid XU4 running 32 bit Armbian Buster
  * Hardkernel Odroid C4 running 64bit Armbian Focal and Buster
  * Raspberry Pi Zero, 3 and 4 running Raspberry OS (32 bit Buster)
  * Debian Buster X86_64 desktop
  * Connected to a RaspiBlitz >1.4 (any Bitcoin Core node can work, including previous RaspiBlitz versions)

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
  # inspect the script
  cat build_joininbox.sh
  # run
  sudo bash build_joininbox.sh
  ```

* start the JoininBox menu by changing to the `joinmarket` user in the terminal:  
 `$ sudo su joinmarket`  
or  
log in with ssh to:  
`joinmarket@LAN_IP_ADDRESS`  
the default password is: `joininbox` - will be prompted to change it on the first start
---

## More info

* Video demonstration of [running JoinMarket with JoininBox on the RaspiBlitz](https://www.youtube.com/watch?v=uGHRjilMhwY)
* How to [prepare a remote node to accept the JoinMarket connection](prepare_remote_node.md)
* [Frequently Asked Questions and notes](FAQ.md)
* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)
* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)
* Instructions on how to [build the JoininBox](build_joininbox.md) step-by-step manually

## Forums

* Keybase: https://keybase.io/team/raspiblitz#joinmarket  
* Telegram: https://t.me/joinmarketorg  
* IRC: #joinmarket on Freenode  
* Reddit: https://www.reddit.com/r/joinmarket/  
