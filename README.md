# JoininBox

A minimalistic, security focused linux environment for JoinMarket with a terminal based graphical menu.

<p align="left">
  <img width="400" src="/images/menu.png">
  <img width="400" src="/images/menu.wallet.png">
</p>
<p align="left">
  <img width="400" src="/images/menu.yg.png">
  <img width="400" src="/images/menu.payjoin.png">
</p>

<p align="left">
  <img width="400" src="/images/joininbox.jpeg">
</p>

### Features

* Send transactions with improved privacy using CoinJoin and PayJoin
* Run the Yield Generator as a service and earn fees for providing liquidity
* Use the JoinMarket-QT GUI remotely over SSH
* Signet support to test for free

### Connect to a Bitcoin Core node

* Try signet locally
* Connect remotely to a
  * RaspiBlitz over LAN or Tor
  * RoninDojo over LAN or Tor
* Run locally as part of the RaspiBlitz SERVICES
* (Soon: run a pruned node locally on JoininBox)

### Required Hardware
* RaspberryPi 4 ([alternatively any other computer running a Debian Linux flavour](#tested-environments))
* 32 Gb SDcard
* (USB SSD to run a pruned bitcoin node locally)
### Set up JoininBox on Linux

#### Tested environments
  * Debian Buster X86_64 desktop
  * [Raspberry Pi 4 running 64bit Debian Buster](https://github.com/openoms/joininbox/blob/master/FAQ.md#build-the-sdcard-image)
  * [Hardkernel Odroid XU4 running 32bit Armbian Buster](https://github.com/openoms/joininbox/blob/master/FAQ.md#set-up-armbian-on-the-hardkernel-odroid-xu4)
  * Hardkernel Odroid C4 running 64bit Armbian Focal and Buster
  * Raspberry Pi Zero, [3 and 4 running RaspberryOS](https://github.com/openoms/joininbox/blob/master/FAQ.md#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi) (32bit Buster)

#### Install JoininBox
* Start as the `root` user or change with:  
`$ sudo - su`

* Run the [build script](https://github.com/openoms/joininbox/blob/master/build_joininbox.sh):
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

* [Video demonstration](https://www.youtube.com/watch?v=uGHRjilMhwY) / [slides](https://keybase.pub/oms/slides/RaspiBlitz_Tech_DeepDive/Running_JoinMarket_on_the_RaspiBlitz.pdf) of running JoinMarket with JoininBox on the RaspiBlitz 
* How to [prepare a remote node to accept the JoinMarket connection](prepare_remote_node.md)
* [Frequently Asked Questions and notes](FAQ.md)
* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)
* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)
* Instructions on how to [build the JoininBox](build_joininbox.md) step-by-step manually

## Forums

* Telegram: https://t.me/joinmarketorg  
* IRC: #joinmarket on Freenode  
* Reddit: https://www.reddit.com/r/joinmarket/  
* Keybase: https://keybase.io/team/raspiblitz#joinmarket