## JoininBox - Build a dedicated JoinMarket Box remotely connected to a full node

* Test environments:
  * Hardkernel Odroid XU4 running Armbian
  * Raspberry Pi 3 and 4 running Raspbian
  * Debian Buster desktop
  * Connected to a RaspiBlitz 1.4 (any Bitcoin Core node can work, including previous RaspiBlitz versions)

### Install and set up the base image
* [Set up Armbian on the Hardkernel Odroid XU4](https://github.com/openoms/joininbox/blob/master/FAQ.md#set-up-armbian-on-the-hardkernel-odroid-xu4)
* [Download and verify Raspbian SDcard image for a Raspberry Pi](https://github.com/openoms/joininbox/blob/master/FAQ.md#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi)

### Set up JoininBox
* Continue work as the `root` user.
* Continue with the [manual building steps](build_joininbox.md)  
or
* Run the build script:  
  ```bash 
  # download
  wget https://raw.githubusercontent.com/openoms/joininbox/master/build_joininbox.sh
  # run (install Tor also)
  sudo bash build_joininbox.sh --with-tor
  ```

### Installing the Joininbox menu on a RaspiBlitz v1.5+ 
* Run the script in the RaspiBlitz terminal (will install JoinMarket if not active already):
  ```bash
  # download
  wget https://raw.githubusercontent.com/openoms/joininbox/master/build_menu_on_raspiblitz.sh
  # run
  bash build_menu_on_raspiblitz.sh
  ```

* start in the RaspiBlitz terminal:
 `sudo su joinmarket`

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

--- 

There is a terminal based GUI in the works.

**Work In Progress** - suggestions and contributions are welcome

<p align="left">
  <img width="400" src="/images/mainmenu.png">
  <img width="400" src="/images/darkmenu.png">
</p>

### Rough plan

- [x] INFO "Wallet information" 
- [ ] PAY "Pay with a coinjoin" 
- [ ] TUMBLER "Run the Tumbler" 
- [x] MAKER "Run the Yield Generator" 
- [x] YG-LIST "List the past YG activity" 
- [x] OBWATCH "Run the offer book locally" 
- [ ] EMPTY "Empty a mixdepth" 
- [x] YG_CONF "Configure the Yield Generator" 
- [x] STOP "Stop the Yield Generator" 
- [ ] GEN "Generate a wallet" 
- [x] IMPORT "Copy wallet(s) from a remote node" 
- [ ] RESTORE "Restore a wallet" 
- [x] INSTALL "Install and configure JoinMarket" 
- [x] UPDATE "Update JoininBox"

- [ ] List and display the logs 
- [ ] Connect to a remote node 


