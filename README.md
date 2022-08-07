[![arm64-rpi-image-build](https://github.com/openoms/joininbox/actions/workflows/arm64-rpi-image-build.yml/badge.svg?branch=packer)](https://github.com/openoms/joininbox/actions/workflows/arm64-rpi-image-build.yml)

<!-- omit in toc -->
# JoininBox

A minimalistic, security focused linux environment for JoinMarket with a terminal based graphical menu.

<p align="left">
  <img width="400" src="/images/menu.png">
  <img width="400" src="/images/menu.wallet.png">
</p>

<p align="left">
  <img width="400" src="/images/menu.yg.png">
  <img width="400" src="/images/menu.tools.png">
</p>

<p align="left">
  <img width="800" src="/images/menu.m0.png">
</p>


- [Features](#features)
- [Required Hardware](#required-hardware)
- [Set up from an SDcard image](#set-up-from-an-sdcard-image)
- [Set up JoininBox on Linux](#set-up-joininbox-on-linux)
  - [Tested environments](#tested-environments)
  - [Install JoininBox](#install-joininbox)
- [More info](#more-info)
- [About JoinMarket](#about-joinmarket)
- [Forums](#forums)
- [Donations](#donations)

## Features

* Send transactions with improved privacy using CoinJoin and PayJoin
* Run the Yield Generator as a service and earn fees for providing liquidity
* Use the JoinMarket-QT GUI remotely over SSH
* Signet support to test for free
* Connect remotely to a Bitcoin Core node
  * RaspiBlitz over [LAN or Tor](prepare_remote_node.md#raspiblitz)
  * RoninDojo over [LAN or Tor](prepare_remote_node.md#ronindojo)
* Start a pruned node from https://prunednode.today/
* JoininBox is part the RaspiBlitz SERVICES

**The addresses, transactions and balances of JoinMarket can be seen in the watch-only wallet of the connected node.**
  * use your own or a trusted node
  * to protect privacy in case of physical access use disk encryption

## Required Hardware
* RaspberryPi 4 ([alternatively any other computer running a Debian Linux flavour](#tested-environments))
* Power supply (5V 3A and above recommended)
* Heatsink case
* 16GB SDcard (minimum) - 32GB to use a pruned node
* [(USB SSD to run a pruned bitcoin node locally)](FAQ.md#usb-ssd-recommendation)
* [other tested hardware ](#tested-environments)

**JoininBox operates on the minimum viable hardware under the assumption that the seed (and passphrase) of the wallets used is safely backed up and can be used to recover the funds!**

## Set using an SDcard image
* Download the latest SDcard image for the Raspberry Pi 4 or 3 generated with Packer in GitHub actions
  * Download link: <https://github.com/openoms/joininbox/suites/7702238931/artifacts/322134211>
  * Details of the build: <https://github.com/openoms/joininbox/actions/runs/2812704764>
* unzip and check the sha256sum verifying the .gz file integrity
  ```
  sha256sum -c joininbox-arm64-rpi.img.gz.sha256
  joininbox-arm64-rpi.img.gz: OK
  ```

* Write the joininbox-arm64-rpi.img.gz file to the SDcard with [Balena Etcher](https://www.balena.io/etcher/) - no need to decompress further
* Assemble the RaspberryPi and connect with a LAN cable to the internet
* Make sure that your laptop and the RPi are on the same local network
* Boot by connecting the power cable
* Open a terminal ([OSX](https://www.youtube.com/watch?v=5XgBd6rjuDQ)/[Win10](https://www.howtogeek.com/336775/how-to-enable-and-use-windows-10s-built-in-ssh-commands/)) and connect with ssh:
  ```
  ssh joinmarket@rpi4-20220121
  ```
   → the password on the first boot is: `joininbox`
* Use the hostname of the latest SDcard image (`rpi4-20220121`) or to find the IP address to connect to:  
  * scan with the [AngryIP Scanner](https://angryip.org/)
  * use `sudo arp -a` or
  * check the router interface

* after the first login will be prompted to change the password to access the menu.
  ![password change](/images/password.change.png)

* next will be presented with the CONFIG menu to
  * Connect to a remote bitcoin node on mainnet
  * Try JoinMarket on signet
  * Start a pruned node from [prunednode.today](https://prunednode.today)
  * Edit the joinmarket.cfg manually
  * Update JoininBox or JoinMarket

  ![config menu](/images/menu.startup.png)

* Update to the latest version of JoininBox and update JoinMarket if the latest version is newer than the one installed on the SDcard

  After any of the options or Exit is selected the main JoininBox menu will open where you can start using JoinMarket

   ![menu](/images/menu.png)

* Find [more info on the usage](#more-info) and [community help](#forums) at the end of this readme
## Set up JoininBox on Linux
### Tested environments
  * Debian Buster X86_64 desktop
  * Ubuntu 20.04 X86_64 desktop (virtual machine)
  * [Raspberry Pi 4 running 64bit Debian Buster](FAQ.md#build-the-sdcard-image)
  * [Hardkernel Odroid XU4/HC1 running 32bit Armbian Buster](FAQ.md#set-up-armbian-on-the-hardkernel-odroid-xu4)
  * Hardkernel Odroid C4 running 64bit Armbian Focal and Buster
  * Raspberry Pi Zero, [3 and 4 running RaspberryOS](FAQ.md#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi) (32bit Buster)

### Install JoininBox
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

## About JoinMarket
* [JoinMarket documentation](https://github.com/JoinMarket-Org/joinmarket-clientserver/tree/master/docs)
* [Recommendations for users](https://joinmarket.me/blog/blog/the-445-btc-gridchain-case/index.html#recommendations) on [waxwing's blog](https://joinmarket.me/category/waxwings-blog.html)
* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)
* [JoinMarket on Ubuntu](https://www.youtube.com/watch?v=zTCC86IUzWo) video by [K3tan](https://twitter.com/_k3tan)
* [How to use JoinMarket](https://www.keepitsimplebitcoin.com/joinmarket) command line focused video by [Keep It Simple Bitcoin](https://twitter.com/kisbitcoin)
* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)

## Forums
* Telegram: <https://t.me/joinmarketorg>
* IRC: #joinmarket on [libera.chat](https://libera.chat/) or [hackint.org](https://hackint.org/)
* Reddit: <https://www.reddit.com/r/joinmarket/>
* Keybase: <https://keybase.io/team/raspiblitz#joinmarket>

## Donations
* For JoinMarket (general): https://bitcoinprivacy.me/joinmarket-donations
* To waxwing for JoinMarket: <https://joinmarket.me/donations/>
* To openoms for JoininBox (LN + payjoin enabled - open in the [Tor Browser](https://www.torproject.org/)): <http://7tpv3ynajkv6cdocmzitcd4z3xrstp3ic6xtv5om3dc2ned3fffll5qd.onion/apps/4FePMm7m818oppkTYNZRwbDnL6HP/pos>
