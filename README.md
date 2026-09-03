[![arm64-rpi-image-build](https://github.com/openoms/joininbox/actions/workflows/arm64-rpi-image-build.yml/badge.svg)](https://github.com/openoms/joininbox/actions/workflows/arm64-rpi-image-build.yml) [![amd64-image-build](https://github.com/openoms/joininbox/actions/workflows/amd64-image-build.yml/badge.svg)](https://github.com/openoms/joininbox/actions/workflows/amd64-image-build.yml)

<!-- omit in toc -->
# JoininBox

A minimal, security-focused Linux environment for JoinMarket NG with terminal menus.

- [Features](#features)
- [Required Hardware](#required-hardware)
  - [A computer running a Debian / Ubuntu Linux flavour.](#a-computer-running-a-debian--ubuntu-linux-flavour)
  - [RaspberryPi 5 or 4](#raspberrypi-5-or-4)
  - [VPS eg: host4coins.net](#vps-eg-host4coinsnet)
- [Set up using an SDcard image](#set-up-using-an-sdcard-image)
- [Set up JoininBox on Linux](#set-up-joininbox-on-linux)
  - [Tested environments](#tested-environments)
  - [Install JoininBox](#install-joininbox)
  - [Migrating an existing wallet](#migrating-an-existing-wallet)
- [More info](#more-info)
- [About JoinMarket](#about-joinmarket)
- [Forums](#forums)

## Features

* Use the JoinMarket NG wallet, taker, tumbler, maker, and orderbook tools from the bundled `jm-ng` terminal UI
* Run the maker as a supervised service and earn fees for providing liquidity
* Signet support to test for free
* Connect to Bitcoin Core locally or remotely over LAN or Tor
  * RaspiBlitz over [LAN or Tor](prepare_remote_node.md#raspiblitz)
  * RoninDojo over [LAN or Tor](prepare_remote_node.md#ronindojo)
* Start a pruned node from https://pruned.host4coins.net/blocks
* Verify signed JoinMarket NG releases and install the pinned `0.38.0` release from its immutable commit
* Preserve existing legacy JoinMarket data during migration

**JoinMarket NG creates deterministic watch-only descriptor wallets in the connected Bitcoin Core node. Their names use the form `jm_<fingerprint>_<network>`.**
  * use your own or a trusted node
  * to protect privacy in case of physical access use disk encryption

## Required Hardware
### A computer running a Debian / Ubuntu Linux flavour. 
* See the [tested-environments](#tested-environments).
### RaspberryPi 5 or 4
* Power supply (5V 3A and above recommended)
* Heatsink case
* 32 GB Endurance type SDcard
* [(USB SSD to run a pruned bitcoin node locally)](FAQ.md#usb-ssd-recommendation)
### VPS eg: [host4coins.net](https://host4coins.net/)
Recommended minimum:
* 1 GB RAM
* 1 vCPU
* 32 GB SSD

**JoininBox operates on the minimum viable hardware under the assumption that the seed (and passphrase) of the wallets used is safely backed up and can be used to recover the funds!**

## Set up using an SDcard image
* Download the zip of the latest successful SDcard image build for the Raspberry Pi 4 or 5 from
  <https://github.com/openoms/joininbox/actions?query=workflow%3Aarm64-rpi-image-build++branch%3Amaster+is%3Asuccess++>  
  (note that need to be logged in to github to download the artifact image file)
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
  ssh joinmarket@LAN_IP_ADDRESS
  ```
   The password on the first boot is: `joininbox`
* To find the IP address to connect to:
  * scan with the [AngryIP Scanner](https://angryip.org/)
  * use `sudo arp -a` or
  * check the router interface

* after the first login will be prompted to change the password to access the menu.
  ![password change](/images/password.change.png)

* Next, use the CONFIG menu to
  * Connect to a remote bitcoin node on mainnet
  * Try JoinMarket on signet
  * Start a pruned node from [pruned.host4coins.net/blocks](https://pruned.host4coins.net/blocks)
  * Edit the JoinMarket NG `config.toml`
  * Update JoininBox or reinstall the pinned JoinMarket NG release

* Open `JoinMarket NG` from the main JoininBox menu, then create or import a wallet in the `jm-ng` UI.

* Find [more info on the usage](#more-info) and [community help](#forums) at the end of this readme
## Set up JoininBox on Linux
### Tested environments
* Debian 13 X86_64 ([images and logs available in GitHub actions](https://github.com/openoms/joininbox/actions?query=workflow%3Aamd64-image-build++branch%3Amaster+is%3Asuccess))
* Raspberry Pi 4 and 5 running 64-bit Raspberry Pi OS Bookworm ([images and logs available in GitHub actions](https://github.com/openoms/joininbox/actions?query=workflow%3Aarm64-rpi-image-build++branch%3Amaster+is%3Asuccess++))
* Python 3.11 or newer is required by JoinMarket NG.

### Install JoininBox
* Start as the `root` user or change with:  
`$ sudo su -`

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

JoinMarket NG runs under the isolated `joinmarketng` system account. Its data is stored in `/home/joinmarketng/.joinmarket-ng` on standalone systems and `/mnt/hdd/app-data/joinmarket-ng` on RaspiBlitz. Use the JoininBox menu or the `jm-ng` command rather than logging in as that account directly.

### Migrating an existing wallet

Legacy `.jmdat` files and JoinMarket NG `.mnemonic` files are not interchangeable. Updating JoininBox does not delete `/home/joinmarket/.joinmarket` or the old clientserver checkout. Before moving funds, recover and verify the legacy wallet mnemonic with the old tooling, then use `WALLET -> Import` in `jm-ng`. Use `jm-wallet rescan --scan-depth N` when old address use exceeds the imported descriptor range. After the rescan completes, open CoinJoin History in `jm-ng`; the TUI refreshes the wallet and reconstructs imported history automatically. Run `jm-wallet recover-bonds` for existing fidelity bonds, and verify balances and history before starting the maker.

---

## More info
* [Video demonstration](https://www.youtube.com/watch?v=uGHRjilMhwY) / [slides](https://keybase.pub/oms/slides/RaspiBlitz_Tech_DeepDive/Running_JoinMarket_on_the_RaspiBlitz.pdf) of running JoinMarket with JoininBox on the RaspiBlitz
* How to [prepare a remote node to accept the JoinMarket connection](prepare_remote_node.md)
* [Frequently Asked Questions and notes](FAQ.md)

## About JoinMarket
* [JoinMarket NG documentation](https://joinmarket-ng.github.io/joinmarket-ng/)
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
