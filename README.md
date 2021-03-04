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
  
**The addresses, transactions and balances of JoinMarket can be seen in the watch-only wallet of the connected node.**
  * use your own or trusted node
  * to protect privacy in case of physical access use disk encryption

### Required Hardware
* RaspberryPi 4 ([alternatively any other computer running a Debian Linux flavour](#tested-environments))
* Power supply (5V 3A and above recommended)
* Heatsink case
* 16GB SDcard (minimum)
* [(USB SSD to run a pruned bitcoin node locally)](FAQ.md#usb-ssd-recommendation)  
  
**JoininBox operates on the minimum viable hardware under the assumption that the seed (and passphrase) of the wallets used is safely backed up and can be recovered fully**

### Set up with an SDcard image
* Find the links to the prebuilt image in the [releases](https://github.com/openoms/joininbox/releases)
* [Verify the downloaded image](FAQ.md#verify-the-downloaded-the-image)
* Write to the SDcard with [Balena Etcher](https://www.balena.io/etcher/)
* Assemble the RaspberryPi and connect with a LAN cable to the internet
* Make sure that your laptop and the RPi are on the same local network
* Boot by connecting the power cable
* Open a terminal ([OSX](https://www.youtube.com/watch?v=5XgBd6rjuDQ)/[Win10](https://www.howtogeek.com/336775/how-to-enable-and-use-windows-10s-built-in-ssh-commands/)) and connect with ssh.  
  Use the hostname of the latest SDcard image (`rpi4-20210210`) or to find the IP address to connect to:  
  * scan with the [AngryIP Scanner](https://angryip.org/)
  * use `sudo arp -a` or
  * check the router interface 

  `ssh joinmarket@rpi4-20210210` → use the password: `joininbox`
* after the first loging will be prompted to change the password to access Joininbox

  ![password change](/images/password.change.png)

* next will be presented with the CONFIG menu to
  * Edit the joinmarket.cfg manually
  * Connect to  a remote bitcoin node on mainnet
  * Try JoinMarket on signet
  
  ![config menu](/images/menu.config.png)

* Continuing with one of the options or exiting will get you to the main JoininBox menu where you can start using JoinMarket
   
   ![menu](/images/menu.png)

* Find [more info on the usage](#more-info) and [community help](#forums) at the end of this readme
### Set up JoininBox on Linux
#### Tested environments
  * Debian Buster X86_64 desktop
  * [Raspberry Pi 4 running 64bit Debian Buster](FAQ.md#build-the-sdcard-image)
  * [Hardkernel Odroid XU4 running 32bit Armbian Buster](FAQ.md#set-up-armbian-on-the-hardkernel-odroid-xu4)
  * Hardkernel Odroid C4 running 64bit Armbian Focal and Buster
  * Raspberry Pi Zero, [3 and 4 running RaspberryOS](FAQ.md#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi) (32bit Buster)

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

## About JoinMarket

* [JoinMarket documentation](https://github.com/JoinMarket-Org/joinmarket-clientserver/tree/master/docs)
* [Recommendations for users](https://joinmarket.me/blog/blog/the-445-btc-gridchain-case/index.html#recommendations) on [waxwing's blog](https://joinmarket.me/category/waxwings-blog.html)
* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)
* [JoinMarket on Ubuntu](https://www.youtube.com/watch?v=zTCC86IUzWo) video by [K3tan](https://twitter.com/_k3tan)
* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)
## Forums

* Telegram: <https://t.me/joinmarketorg>
* IRC: #joinmarket on Freenode  
* Reddit: <https://www.reddit.com/r/joinmarket/>
* Keybase: <https://keybase.io/team/raspiblitz#joinmarket>

## Donations
* To waxwing for JoinMarket: <https://joinmarket.me/donations/>
* To openoms for JoininBox: <https://tips.diynodes.com>