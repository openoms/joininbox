<!-- omit in toc -->
# Frequently Asked Questions and Notes

- [Public JoinMarket Order Book links](#public-joinmarket-order-book-links)
- [Signet links](#signet-links)
- [SSH hardening options](#ssh-hardening-options)
  - [SSH key authentication](#ssh-key-authentication)
  - [Two factor authenetication (2FA) for SSH](#two-factor-authenetication-2fa-for-ssh)
  - [Log in through SSH using a hardware wallet](#log-in-through-ssh-using-a-hardware-wallet)
- [SSH through Tor from Linux](#ssh-through-tor-from-linux)
- [Allow Tor to connect to localhost](#allow-tor-to-connect-to-localhost)
- [Set up Armbian on the Hardkernel Odroid HC1 / XU4](#set-up-armbian-on-the-hardkernel-odroid-hc1--xu4)
- [Download and verify Raspbian SDcard image for a Raspberry Pi](#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi)
- [Error when connecting to a full node remotely through Tor](#error-when-connecting-to-a-full-node-remotely-through-tor)
- [Erase the joinmarket user and the /home/joinmarket folder](#erase-the-joinmarket-user-and-the-homejoinmarket-folder)
- [Sample bitcoin.conf for a remote node accepting RPC connections through LAN](#sample-bitcoinconf-for-a-remote-node-accepting-rpc-connections-through-lan)
- [Using the 2.13" WaveShare e-ink display](#using-the-213-waveshare-e-ink-display)
- [Compile Tor for the RPi Zero (armv6l)](#compile-tor-for-the-rpi-zero-armv6l)
- [Build the SDcard image](#build-the-sdcard-image)
  - [Boot Ubuntu Live from USB: https://releases.ubuntu.com/focal/ubuntu-20.04.2-desktop-amd64.iso](#boot-ubuntu-live-from-usb-httpsreleasesubuntucomfocalubuntu-20042-desktop-amd64iso)
  - [Download and verify the base image](#download-and-verify-the-base-image)
  - [Flash the base image to the SDcard](#flash-the-base-image-to-the-sdcard)
  - [Prepare the base image](#prepare-the-base-image)
  - [Install Joininbox](#install-joininbox)
  - [Prepare the SDcard release](#prepare-the-sdcard-release)
  - [Sign the image on an airgapped computer](#sign-the-image-on-an-airgapped-computer)
- [Verify the downloaded the image](#verify-the-downloaded-the-image)
  - [Linux instructions](#linux-instructions)
  - [Windows instructions](#windows-instructions)
- [Wallet recovery](#wallet-recovery)
  - [on JoininBox](#on-joininbox)
  - [on the remote node](#on-the-remote-node)
- [USB SSD recommendation](#usb-ssd-recommendation)
- [Pruned node notes](#pruned-node-notes)
- [External drive](#external-drive)

## Public JoinMarket Order Book links
* <https://nixbitcoin.org/obwatcher/>  
* <https://ttbit.mine.bz/orderbook>

## Signet links
* Faucet (free signet coins): https://signet.bc-2.jp
* Block Explorer:
    * esplora: <https://explorer.bc-2.jp>  
    * mempool.space: <https://mempool.space/signet>
* JoinMarket Order Book: <http://gopnmsknawlntb4qpyav3q5ejvvk6p74a7y5xotmph4v64wl3wicscad.onion>
* [Concise instructions on setting up Joinmarket for testing on signet](https://gist.github.com/AdamISZ/325716a66c7be7dd3fc4acdfce449fb1)
* <https://en.bitcoin.it/wiki/Signet>

## SSH hardening options

### SSH key authentication
* <https://stadicus.github.io/RaspiBolt/raspibolt_21_security.html#login-with-ssh-keys>

### Two factor authenetication (2FA) for SSH
Detailed guide: <https://pimylifeup.com/setup-2fa-ssh/>  
See all the options at: <https://www.mankier.com/1/google-authenticator#Options>
* Commands:
  ```
  sudo apt update
  sudo apt install libpam-google-authenticator
  google-authenticator --time-based --force --disallow-reuse --qr-mode=UTF8 --rate-limit=3 --rate-time=30 --window-size=3

  echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd

  sudo sed -i "s/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g" /etc/ssh/sshd_config

  sudo systemctl restart sshd
  ```
* test without exiting first by connecting to the localhost:  
`ssh joinmarket@127.0.0.1`
*  verify that the login with paasword and 2FA works before exiting the terminal

* Set 2FA up for ssh key authentication:
  ```
  sudo sed -i "s/^@include common-auth/#@include common-auth/g" /etc/pam.d/sshd
  echo "AuthenticationMethods publickey,keyboard-interactive" | sudo tee -a /etc/ssh/sshd_config
  sudo systemctl restart sshd
  ```

### Log in through SSH using a hardware wallet
* See the official pages for:
    * [Trezor](https://wiki.trezor.io/Apps:SSH_agent)
    * [Ledger](https://support.ledger.com/hc/en-us/articles/115005200649)
* Linux client for [TREZOR One](https://trezor.io/), [TREZOR Model T](https://trezor.io/), [Keepkey](https://www.keepkey.com/), and [Ledger Nano S](https://www.ledgerwallet.com/products/ledger-nano-s):
    * [github.com/romanz/trezor-agent](https://github.com/romanz/trezor-agent/blob/master/doc/README-SSH.md)
* Windows client for Trezor and Keepkey:
    * <https://github.com/martin-lizner/trezor-ssh-agent>
* paste the generated SSH pubkey to:  
`$ nano /home/joinmarket/.ssh/authorized_keys`

## SSH through Tor from Linux
On a RaspiBlitz
* since v1.4 there is a script to create a hidden service on your blitz:  
`./config.scripts/internet.hiddenservice.sh ssh 22 22`  
* get the Hidden Service address to connect to with:  
`sudo cat /mnt/hdd/tor/ssh/hostname`  

On a Debian based Linux Desktop (Ubuntu, Debian, MX Linux etc.)
* needs Tor running on your desktop:  
`sudo apt install tor`
* might need to add:  
`sudo apt install torsocks` 

* edit the Tor config file:  
`sudo nano /etc/tor/torrc`
* add:
    ```
    # Hidden Service for ssh
    HiddenServiceDir /var/lib/tor/ssh
    HiddenServiceVersion 3
    HiddenServicePort 22 127.0.0.1:22
    ```
* Restart Tor:  
`sudo systemctl restart tor`
* get the Hidden Service address to connect to with:  
`sudo cat /mnt/hdd/tor/ssh/hostname`  

Use `ssh` with `torify`  on the desktop (needs Tor installed):  
`torify ssh admin@HiddenServiceAddress.onion`

## Allow Tor to connect to localhost
* To solve the error when running `$ torify python yg-privacyenhanced.py wallet.jmdat`
    ```
    [INFO]  starting yield generator
    [INFO]  Listening on port 27183
    [INFO]  Starting transaction monitor in walletservice
    1580214062 WARNING torsocks[28563]: [connect] Connection to a local address are     denied since it might be a TCP DNS query to a local DNS server. Rejecting it for    safety reasons. (in tsocks_connect() at connect.c:192)
    ```

* Edit the `torsocks.conf` and activate the option `AllowOutboundLocalhost 1`:  
`$ sudo nano /etc/tor/torsocks.conf`

    ```
    # Set Torsocks to allow outbound connections to the loopback interface.
    # If set to 1, connect() will be allowed to be used to the loopback interface
    # bypassing Tor. If set to 2, in addition to TCP connect(), UDP operations to
    # the loopback interface will also be allowed, bypassing Tor. This option
    # should not be used by most users. (Default: 0)
    AllowOutboundLocalhost 1
    ```

* Restart Tor:   
`sudo systemctl restart tor`

## Set up Armbian on the Hardkernel Odroid HC1 / XU4
* Download the base image (`.img.gz`), the `.sha` and `.asc` file
https://www.armbian.com/odroid-xu4/
* Verify: https://docs.armbian.com/User-Guide_Getting-Started/#how-to-check-download-authenticity
    ```bash
    gpg --keyserver ha.pool.sks-keyservers.net --recv-key DF00FAF1C577104B50BF1D0093D6889F9F0E78D5
    # gpg: key 93D6889F9F0E78D5: public key "Igor Pecovnik # <igor@armbian.  com>" imported
    # gpg: Total number processed: 1
    # gpg:               imported: 1
    gpg --verify Armbian_21.02.3_Odroidxu4_buster_legacy_4.14.222.img.xz.asc
    # gpg: assuming signed data in 'Armbian_21.02.3_Odroidxu4_buster_legacy_4.14.222.img.xz'
    # gpg: Signature made Tue 09 Mar 2021 03:00:30 GMT
    # gpg:                using RSA key DF00FAF1C577104B50BF1D0093D6889F9F0E78D5
    # gpg: Good signature from "Igor Pecovnik <igor@armbian.com>" [unknown]
    # gpg:                 aka "Igor Pecovnik (Ljubljana, Slovenia) <igor.pecovnik@gmail.com>" [unknown]
    # gpg: WARNING: This key is not certified with a trusted signature!
    # gpg:          There is no indication that the signature belongs to the owner.
    # Primary key fingerprint: DF00 FAF1 C577 104B 50BF  1D00 93D6 889F 9F0E 78D5
    shasum -c Armbian_21.02.3_Odroidxu4_buster_legacy_4.14.222.img.xz.sha
    # Armbian_21.02.3_Odroidxu4_buster_legacy_4.14.222.img.xz: OK
    ```
* Preparation  
    Make sure you have a good & reliable SD card and a proper power supply. Archives can be uncompressed with 7-Zip on Windows, Keka on OS X and 7z on Linux (apt-get install p7zip-full). RAW images can be written with Etcher (all OS).
* Boot  
    Insert the SD card into the slot, connect a cable to your network if possible or a display and power your board. (First) boot (with DHCP) takes up to 35 seconds with a class 10 SD Card.
* Login  
    Log in as: `root`  Password: `1234`. Then you are prompted to change this password (US-Keyboard setting). When done, you are asked to create a normal user-account for your everyday tasks.
* Change the password.
* Create a new user called `joinmarket` and set the password (the password will be changed to `joininbox`).  
 Keep pressing [ENTER] to use the default user information.
* Continue to [install JoininBox](README.md#install-joininbox)

## Download and verify Raspbian SDcard image for a Raspberry Pi
To be able to open the JoinMarket-QT GUI on the dekstop from the RPI
need to use the Raspberry Pi OS (32-bit) with desktop inage
* Download image:  
https://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-2020-05-28/2020-05-27-raspios-buster-armhf.zip
* Download signature:  
https://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-2020-05-28/2020-05-27-raspios-buster-armhf.zip.sig
* Import PGP pubkey:  
`curl https://www.raspberrypi.org/raspberrypi_downloads.gpg.key | gpg --import`
* Verify the image:  
`gpg --verify 2020-05-27-raspios-buster-armhf.zip.sig`
* Flash the image to an SDcard, can use the [Raspberry Pi Imager](https://www.raspberrypi.org/downloads/)
* put a file called simply: `ssh` to the root of the sdcard.  
Read more on [how to gain ssh access here](https://www.raspberrypi.org/documentation/remote-access/ssh/).
* boot up the RPi and log in with ssh to:   
`pi@LAN_IP_ADDRESS`  
The default password is: `raspberry`
* Continue to [install JoininBox](README.md#install-joininbox)

## Error when connecting to a full node remotely through Tor
* Getting the error:
    ```
    socket.gaierror: [Errno -2] Name or service not known
    ```
* Remember to use `torify` with the python scripts when connecting remotely through Tor. Example:  
    `torify wallet-tool.py wallet.jmdat`

## Erase the joinmarket user and the /home/joinmarket folder
`sudo srm -rf /home/joinmarket/`  
`sudo userdel -rf joinmarket`

## Sample bitcoin.conf for a remote node accepting RPC connections through LAN
```
# bitcoind configuration

# mainnet/testnet
testnet=0

# Bitcoind options
server=1
daemon=1
txindex=1
disablewallet=0

main.wallet=wallet.dat
datadir=/mnt/hdd/bitcoin

# Connection settings
rpcuser=REDACTED
rpcpassword=REDACTED
rpcport=8332
#rpcallowip=127.0.0.1
#main.rpcbind=127.0.0.1:8332
# SET THE LOCAL SUBNET
rpcallowip=192.168.1.0/24
main.rpcbind=0.0.0.0
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333

# SBC optimizations
dbcache=1512
maxorphantx=10
maxmempool=300
maxconnections=40
maxuploadtarget=5000

# Tor
onlynet=onion
proxy=127.0.0.1:9050
main.bind=127.0.0.1
test.bind=127.0.0.1
main.addnode=fno4aakpl6sg6y47.onion
main.addnode=toguvy5upyuctudx.onion
main.addnode=ndndword5lpb7eex.onion
main.addnode=6m2iqgnqjxh7ulyk.onion
main.addnode=5tuxetn7tar3q5kp.onion
dnsseed=0
dns=0

# for Bisq
peerbloomfilters=1
```

## Using the 2.13" WaveShare e-ink display
https://www.waveshare.com/wiki/2.13inch_e-Paper_HAT
https://www.raspberrypi.org/documentation/hardware/raspberrypi/spi/README.md
SPI0 is disabled by default. To enable it, use raspi-config, or ensure the line dtparam=spi=on isn't commented out in /boot/config.txt
* Installation
  ```
  #Install BCM2835 libraries
  wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.60.tar.gz
  tar zxvf bcm2835-1.60.tar.gz 
  cd bcm2835-1.60/
  sudo ./configure
  sudo make
  sudo make check
  sudo make install
  #For more details, please refer to http://www.airspayce.com/mikem/bcm2835/

  #Install wiringPi libraries

  sudo apt-get install wiringpi

  #For Pi 4, you need to update it：
  cd /tmp
  wget https://project-downloads.drogon.net/wiringpi-latest.deb
  sudo dpkg -i wiringpi-latest.deb
  gpio -v
  #You will get 2.52 information if you install it correctly

  #Install Python libraries
  #python3
  sudo apt-get update
  sudo apt-get install python3-pip
  sudo apt-get install python3-pil
  sudo apt-get install python3-numpy
  sudo pip3 install RPi.GPIO
  sudo pip3 install spidev
  ```

* Test:
  ```
  sudo git clone https://github.com/waveshare/e-Paper
  cd e-Paper/RaspberryPi\&JetsonNano/python/examples
  sudo python epd_2in13_V2_test.py
  ```
Code examples:   
https://github.com/waveshare/e-Paper/blob/master/RaspberryPi%26JetsonNano/python/examples/epd_2in13_V2_test.py
https://github.com/21isenough/LightningATM/blob/master/displays/waveshare2in13.py  

## Compile Tor for the RPi Zero (armv6l)
https://2019.www.torproject.org/docs/debian#source

## Build the SDcard image
* Partially based on: https://github.com/rootzoll/raspiblitz/blob/v1.6/FAQ.md#what-is-the-process-of-creating-a-new-sd-card-image-release

### Boot Ubuntu Live from USB: https://releases.ubuntu.com/focal/ubuntu-20.04.2-desktop-amd64.iso
* Connect to a secure WiFi (hardware switch on) or LAN
  
### Download and verify the base image
* Open a terminal
* Paste the following commands (see the comments for the explanations and an example output)
    ```bash  
    # Download the base image:
    wget https://raspi.debian.net/verified/20210210_raspi_4_buster.img.xz

    # Download the PGP signed sha256 hash
    wget https://raspi.debian.net/verified/20210210_raspi_4_buster.xz.sha256.asc

    # Verify:
    # download the signing pubkey
    gpg --receive-key E2F63B4353F45989
    # verify the PGP signed sha256 hash
    gpg --verify 20210210_raspi_4_buster.xz.sha256.asc
    # Look for the output 'Good signature':
    # gpg: Signature made Wed 10 Feb 2021 20:22:05 GMT
    # gpg:                using EDDSA key 60B3093D96108E5CB97142EFE2F63B4353F45989
    # gpg: Good signature from "Gunnar Wolf <gwolf@gwolf.org>" [unknown]
    # gpg:                 aka "Gunnar Eyal Wolf Iszaevich <gwolf@iiec.unam.mx>" [unknown]
    # gpg:                 aka "Gunnar Wolf <gwolf@debian.org>" [unknown]
    # gpg: Note: This key has expired!
    # Primary key fingerprint: 4D14 0506 53A4 02D7 3687  049D 2404 C954 6E14 5360
    #     Subkey fingerprint: 60B3 093D 9610 8E5C B971  42EF E2F6 3B43 53F4 5989

    # compare the hash to the hash of the image file
    sha256sum --check 20210210_raspi_4_buster.xz.sha256.asc
    # Look for the output 'OK':
    # 20201112_raspi_4.img.xz: OK
    # sha256sum: WARNING: 10 lines are improperly formatted
    ```
### Flash the base image to the SDcard
* Connect an SDcard reader with a 8GB SDcard.
* In the file manager open the context menu (right click) on the `.img.xz` file.
* Select the option `Open With Disk Image Writer`.
* Write the image to the SDcard.
### Prepare the base image

* Before the first boot edit the `sysconf.txt` on the `RASPIFIRM` partition to be able to ssh remotely - needs an authorized ssh pubkey.
* Generate ssh keys on Ubuntu with (keep selecting the defaults with ENTER):
    ```bash
    ssh-keygen -t rsa -b 4096
    ```
* Click on the RASPIFIRM volume once in the file manager to mount it
* Copy the ssh pubkey from the Ubuntu image to the `sysconf.txt` the `RASPIFIRM` directory (make sure it is mounted):
    ```bash
    echo "root_authorized_key=$(cat ~/.ssh/id_rsa.pub)" | tee -a /media/ubuntu/RASPIFIRM/sysconf.txt
    # Check with:
    cat /media/ubuntu/RASPIFIRM/sysconf.txt
    ```   
    The `sysconf.txt` will reset after boot and moves the ssh pubkey to `/root/.ssh/authorized_keys`
* Place the SDcard in the RPi, boot up and connect with ssh (use the hostname, `arp -a` or check the router)
    ```bash
    ssh root@rpi4-20210210
    ```
* Install basic dependencies
    ```bash
    apt update
    apt install sudo wget
    ```
### Install Joininbox
* Download and run the build script
  ```bash 
  # download
  wget https://raw.githubusercontent.com/openoms/joininbox/master/build_joininbox.sh
  # inspect the script
  cat build_joininbox.sh
  # run
  sudo bash build_joininbox.sh
  ```
* Monitor/Check outputs for warnings/errors

### Prepare the SDcard release
 * Make the SDcard image safe to share by removing unique infos like ssh pubkeys and network identifiers:  
     ```bash
    /home/joinmarket/standalone/prepare.release.sh
    ```
* Disconnect WiFi/LAN on build laptop (hardware switch off) and shutdown
* Remove Ubuntu LIVE USB stick and cut power from the RaspberryPi

### Sign the image on an airgapped computer
* Connect USB stick with [Tails](https://tails.boum.org/) (stay offline)
* Power on the Build Laptop (press F12 for boot menu)
* Connect USB stick with GPG signing keys - decrypt drive if needed
* Open Terminal and cd into directory of USB Stick under `/media/amnesia`
* Run `gpg --import backupsecretkey.gpg`, check and exit
* Disconnect USB stick with GPG keys
* Take the SD card from the RaspberryPi and connect with an external SD card reader to the laptop
* Click on the RASPIFIRM volume once in the file manager to mount it
* Connect another USB stick, open in file manager and delete old files
* Open Terminal and cd into directory of USB stick under `/media/amnesia`
* Run `lsblk` to check on the SD card device name (ignore last partition number)
* Clone the SDcard:   
  `dd if=/dev/[sdcarddevice] | gzip > joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz`
* When finished you should see that more than 7GB was copied.
* Create sha256 hash of the image:  
  `sha256sum *.gz > joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256`
* Sign the sha256 hash file:  
  `gpg --detach-sign --armor *.sha256`
* Check the files:
  ```bash
  ls
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256.asc
  ```
* Shutdown the build computer
* Upload the new image to server - put the .sig file and sha256sum.txt next to it
* Copy the sha256sum to GitHub README and update the download link

## Verify the downloaded the image
### Linux instructions
* Open a terminal in the directory with the downloaded files
    ```
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256.asc
    ```
* Paste the following commands (see the comments for the explanations and an example output)
  ```bash
  # Import the signing pubkey: 
  curl https://keybase.io/oms/pgp_keys.asc | gpg --import 
  
  # Verify the signature of the sha256 hash:
  gpg --verify *.asc 
  # Look for the output 'Good signature':
  # gpg: assuming signed data in 'joininbox-v0.2.0-2021-02-15.img.gz.sha256'
  # gpg: Signature made Mon 15 Feb 2021 14:16:56 GMT
  # gpg:                using RSA key 13C688DB5B9C745DE4D2E4545BFB77609B081B65
  # gpg: Good signature from "openoms <oms@tuta.io>" [unknown]
  # gpg: WARNING: This key is not certified with a trusted signature!
  # gpg:          There is no indication that the signature belongs to the owner.
  # Primary key fingerprint: 13C6 88DB 5B9C 745D E4D2  E454 5BFB 7760 9B08 1B65
  
  # Compare the sha256 hash to the hash of the image file
  shasum -c *.sha256
  # Look for the output 'OK' :
  # joininbox-v0.2.0-2021-02-15.img.gz: OK
  ```

### Windows instructions
* Download and open the PGP verification software for Windows from <https://www.gpg4win.org> 
* Verify the `joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256` file
* The signature is in the file:  
  `joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256.asc `
* The signing PGP key is: <https://keybase.io/oms/pgp_keys.asc>
* Display the sha256 hash from the `joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.sha256` file with Notepad or use the command `more`:  
  `C:\> more *.sha256`
* Get the sha256 hash of the image file with the built-in tool `certutil`:  
`C:\> certUtil -hashfile C:\joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz SHA256`
* Compare the two hashes to ensure the authenticity and integrity of the downloaded image.

## Wallet recovery
JoinMarket docs:
* https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md#portability
* https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md#recover

### on JoininBox
* Connect the remote bitcoind with `CONFIG` -> `CONNECT` menu so it checks if the connection is successful. It will also set the remote watch-only wallet in bitcoind to "joininbox" so will need to rescan that after recovering an old wallet with previously used addresses.

* When using the CLI and connecting to the remote node over Tor, you will need to use the script with the torify prefix like:  
`torify python3 wallet-tool.py --recoversync -g 20 ~/.joinmarket/wallets/wallet.jmdat`

### on the remote node
* Use the menu option `WALLET` -> `RESCAN` or follow manually
* the wallet defined as
`rpc_wallet =`
in the joinmarket.cfg is the wallet which is used as watch only in the remote bitcoind.
You need to run rescanblockchain on that wallet in bitcoind after importing the joinmarket wallet.
* The wallet is set in the joinmarket.cfg (by default called `joininbox` should show up when you run:  
`bitcoin-cli listwallets`

* To rescan on the node run (https://developer.bitcoin.org/reference/rpc/rescanblockchain.html?highlight=rescanblockchain):  
`bitcoin-cli -rpcwallet=joininbox rescanblockchain 477120`  
Rescanning fom the first SegWit block is sufficient for the default SegWit wallets.

* Monitor progress (on a RaspiBlitz):  
`sudo tail -fn 100 /mnt/hdd/bitcoin/debug.log`  
Once the rescan is finished you balances should appear in the `INFO` menu (`wallet-tool.py`)
## USB SSD recommendation
**JoininBox operates on the minimum viable hardware under the assumption that the seed (and passphrase) of the wallets used is safely backed up and can be recovered fully**
* The above warning is especially true for SDcard as they fail often, use a good quality one.
* If using an external USB drive I recommend using a Sandisk Extreme Pro 128GB USB SSD:
https://twitter.com/openoms/status/1362486943301459968
* a good alternative is a USB connector and internal SSD as in the [RaspiBlitz shopping list](https://github.com/rootzoll/raspiblitz#package-standard-around-250-usd). Pay attention to choose a compatible SATA-USB adapter since that is a common problem with the Raspberry Pi 4.
* Cheap USB drives are very likely to fail after weeks of heavy usage: https://github.com/rootzoll/raspiblitz/issues/924

## Pruned node notes
It is only recommended to create a new wallet on a pruned node.
Importing an old wallet is not possible without downloading the whole blockchain again (would be too slow and unreliable when using an SDcard only).

To recover a wallet one will need to connect to a node without pruning switched on and rescan there.
When the funds are recovered they can be sent to the addresses created with a new wallet started on a pruned node.

More info:
https://bitcoin.stackexchange.com/questions/99681/how-can-i-import-a-private-key-into-a-pruned-node/99853#99853

## External drive
Alternatively to a pruned node there could be a larger >400 GB storage connected and mounted on the standalone JoininBox with the `.bitcoin` directory containing the `blocks` and `chainstate` symlinked to `/home/store/app-data/` and owned by the `bitcoin` user.
* See the manual commands and output:
  ```bash
  lsblk
  # NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
  # sda           8:0    0 931.5G  0 disk 
  # └─sda1        8:1    0 931.5G  0 part 
  # mmcblk1     179:0    0  29.1G  0 disk 
  # └─mmcblk1p1 179:1    0  28.8G  0 part /
  # zram0       253:0    0 995.2M  0 disk [SWAP]
  # zram1       253:1    0    50M  0 disk /var/log
  sudo mkdir -p /mnt/hdd
  sudo mount /dev/sda1 /mnt/hdd
  lsblk
  # NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
  # sda           8:0    0 931.5G  0 disk 
  # └─sda1        8:1    0 931.5G  0 part /mnt/hdd
  # mmcblk1     179:0    0  29.1G  0 disk 
  # └─mmcblk1p1 179:1    0  28.8G  0 part /
  # zram0       253:0    0 995.2M  0 disk [SWAP]
  # zram1       253:1    0    50M  0 disk /var/log
  ls -la /mnt/hdd
  # drwxr-xr-x  7 1005 1006 4096 Mar 21 10:38 bitcoin
  source ~/_functions.sh
  installBitcoinCoreStandalone
  # remove symlink
  sudo rm /home/bitcoin/.bitcoin
  # create new symlink
  sudo ln -s /mnt/hdd/bitcoin /home/bitcoin/.bitcoin
  # fix permissions
  sudo chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin/
  # check
  ls -la /home/bitcoin/.bitcoin/
  # total 25676
  # drwxr-xr-x  7 bitcoin bitcoin     4096 Mar 21 10:38 .
  # drwxr-xr-x  4 root    root        4096 Mar 20 18:51 ..
  # -rw-------  1 bitcoin bitcoin      105 Mar 21 10:38 anchors.dat
  # -rw-------  1 bitcoin bitcoin   224355 Jan 13 20:04 banlist.dat
  # -r--r--r--  1 bitcoin bitcoin      674 Mar 20 19:03 bitcoin.conf
  # drwxrwxr-x  3 bitcoin bitcoin   135168 Mar 20 23:57 blocks
  # drwxrwxr-x  2 bitcoin bitcoin    98304 Mar 21 10:38 chainstate
  # -rw-------  1 bitcoin bitcoin  2631680 Mar 21 10:38 debug.log
  # -rw-------  1 bitcoin bitcoin   247985 Mar 21 10:38 fee_estimates.dat
  # drwx------  4 bitcoin bitcoin     4096 Dec  6 14:18 indexes
  # -rw-------  1 bitcoin bitcoin        0 Feb 10 10:57 .lock
  # -rw-------  1 bitcoin bitcoin 21369746 Mar 21 10:38 mempool.dat
  # -rw-------  1 bitcoin bitcoin      820 Jan 28 19:07 onion_private_key
  # -rw-------  1 bitcoin bitcoin       99 Feb 10 10:58 onion_v3_private_key
  # -rw-------  1 bitcoin bitcoin  1521305 Mar 21 10:38 peers.dat
  # -rw-r--r--  1 bitcoin bitcoin        7 Mar 21 10:08 settings.json
  # drwx------ 34 bitcoin bitcoin     4096 Dec  7 23:39 specter
  # drwx------  2 bitcoin bitcoin     4096 Mar 21 10:38 wallet.dat
  installMainnet
  # Failed to stop bitcoind.service: Unit bitcoind.service not loaded.
  # 
  # [Unit]
  # Description=Bitcoin daemon on mainnet
  # [Service]
  # User=bitcoin
  # Group=bitcoin
  # Type=forking
  # PIDFile=/home/bitcoin/bitcoin/bitcoind.pid
  # ExecStart=/home/bitcoin/bitcoin/bitcoind -daemon -pid=/home/bitcoin/bitcoin/bitcoind.pid
  # KillMode=process
  # Restart=always
  # TimeoutSec=120
  # RestartSec=30
  # StandardOutput=null
  # StandardError=journal
  # 
  # [Install]
  # WantedBy=multi-user.target
  # 
  # Created symlink /etc/systemd/system/multi-user.target.wants/bitcoind.service → /etc/systemd/system/bitcoind.service.
  # # OK - the bitcoind.service is now enabled
  # 
  # # Installed Bitcoin Core version v0.21.0
  # 
  # # Monitor the bitcoind with: sudo tail -f /home/bitcoin/.bitcoin/mainnet/debug.log
  # 
  # # Create wallet.dat ...
  # error code: -28
  # error message:
  # Loading block index...
  # check progress
  sudo tail -f /home/bitcoin/.bitcoin/debug.log | grep progress
  # 2021-03-23T12:12:34Z UpdateTip: new best=0000000000000000000c503fbc0e2724b4713dbbb8b0f0048177fc3aaebe0b9b height=675602 version=0x20400000 log2_work=92.750996 tx=626795389 date='2021-03-21T11:05:10Z' progress=0.999011 cache=5.4MiB(48880txo)
  ```
