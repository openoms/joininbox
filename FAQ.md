<!-- omit in toc -->
# Frequently Asked Questions and Notes
- [SSH through Tor from Linux](#ssh-through-tor-from-linux)
- [Allow Tor to connect to localhost](#allow-tor-to-connect-to-localhost)
- [Set up Armbian on the Hardkernel Odroid XU4](#set-up-armbian-on-the-hardkernel-odroid-xu4)
- [Download and verify Raspbian SDcard image for a Raspberry Pi](#download-and-verify-raspbian-sdcard-image-for-a-raspberry-pi)
- [Log in through SSH using a hardware wallet](#log-in-through-ssh-using-a-hardware-wallet)
- [Error when connecting to a full node remotely through Tor](#error-when-connecting-to-a-full-node-remotely-through-tor)
- [Nuke the joinmarket user and the /home/joinmarket folder](#nuke-the-joinmarket-user-and-the-homejoinmarket-folder)
- [Sample bitcoin.conf for a remote node accepting RPC connections through LAN](#sample-bitcoinconf-for-a-remote-node-accepting-rpc-connections-through-lan)
- [Using the 2.13" WaveShare e-ink display](#using-the-213-waveshare-e-ink-display)
- [Compile Tor for the RPi Zero (armv6l)](#compile-tor-for-the-rpi-zero-armv6l)
- [Build the SDcard image](#build-the-sdcard-image)
  - [Boot Ubuntu Live from USB: https://releases.ubuntu.com/focal/ubuntu-20.04.2-desktop-amd64.iso](#boot-ubuntu-live-from-usb-httpsreleasesubuntucomfocalubuntu-20042-desktop-amd64iso)
  - [Download,verify and flash the base image to the SDcard](#downloadverify-and-flash-the-base-image-to-the-sdcard)
  - [Prepare the base image](#prepare-the-base-image)
  - [Install Joininbox](#install-joininbox)
  - [Prepare the SDcard release](#prepare-the-sdcard-release)
  - [Sign the image](#sign-the-image)
### SSH through Tor from Linux
On a RaspiBlitz
* since v1.4 there is a script to create a hidden service on your blitz:  
`./config.scripts/internet.hiddenservice.sh ssh 22 22`  
* get the Hidden Service address to connect to with:  
`sudo cat /mnt/hdd/tor/ssh/hostname`  

On the Debian based Linux Desktop (Ubuntu, Debian, MX Linux etc.)
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

### Allow Tor to connect to localhost

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

### Set up Armbian on the Hardkernel Odroid XU4
* Download the SDcard image  
https://dl.armbian.com/odroidxu4/Buster_legacy  
* Verify  
https://docs.armbian.com/User-Guide_Getting-Started/#how-to-check-download-authenticity

    ```
    $ gpg --verify Armbian_20.02.0-rc0_Odroidxu4_buster_legacy_4.14.165.img.asc
    gpg: assuming signed data in 'Armbian_20.02.0-rc0_Odroidxu4_buster_legacy_4.14.165.img'
    gpg: Signature made Mon 20 Jan 2020 05:23:20 GMT
    gpg:                using RSA key DF00FAF1C577104B50BF1D0093D6889F9F0E78D5
    gpg: Good signature from "Igor Pecovnik <igor@armbian.com>" [unknown]
    gpg:                 aka "Igor Pecovnik (Ljubljana, Slovenia) <igor.pecovnik@gmail.com>" [unknown]
    gpg: WARNING: This key is not certified with a trusted signature!
    gpg:          There is no indication that the signature belongs to the owner.
    Primary key fingerprint: DF00 FAF1 C577 104B 50BF  1D00 93D6 889F 9F0E 78D5
    ```

* Preparation  
    Make sure you have a good & reliable SD card and a proper power supply. Archives can be uncompressed with 7-Zip on Windows, Keka on OS X and 7z on Linux (apt-get install p7zip-full). RAW images can be written with Etcher (all OS).

* Boot  
    Insert the SD card into the slot, connect a cable to your network if possible or a display and power your board. (First) boot (with DHCP) takes up to 35 seconds with a class 10 SD Card.

* Login  
    Log in as: root  Password: 1234. Then you are prompted to change this password (US-Keyboard setting). When done, you are asked to create a normal user-account for your everyday tasks.

* Change the password.
* Create a new user called `joinmarket` and set the password.  
 Keep pressing [ENTER] to use the default user information.

### Download and verify Raspbian SDcard image for a Raspberry Pi

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

### Error when connecting to a full node remotely through Tor
* Getting the error:
    ```
    socket.gaierror: [Errno -2] Name or service not known
    ```
* Remember to use `torify` with the python scripts when connecting remotely through Tor. Example:  
    `torify wallet-tool.py wallet.jmdat`

### Nuke the joinmarket user and the /home/joinmarket folder
`sudo userdel -r joinmarket`

### Sample bitcoin.conf for a remote node accepting RPC connections through LAN
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

### Using the 2.13" WaveShare e-ink display
https://www.waveshare.com/wiki/2.13inch_e-Paper_HAT
https://www.raspberrypi.org/documentation/hardware/raspberrypi/spi/README.md
SPI0 is disabled by default. To enable it, use raspi-config, or ensure the line dtparam=spi=on isn't commented out in /boot/config.txt
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

Test:
```
sudo git clone https://github.com/waveshare/e-Paper
cd e-Paper/RaspberryPi\&JetsonNano/python/examples
sudo python epd_2in13_V2_test.py
```
Code examples:   
https://github.com/waveshare/e-Paper/blob/master/RaspberryPi%26JetsonNano/python/examples/epd_2in13_V2_test.py
https://github.com/21isenough/LightningATM/blob/master/displays/waveshare2in13.py  

### Compile Tor for the RPi Zero (armv6l)

https://2019.www.torproject.org/docs/debian#source

### Build the SDcard image
* Check out: https://github.com/rootzoll/raspiblitz/blob/v1.6/FAQ.md#what-is-the-process-of-creating-a-new-sd-card-image-release
#### Boot Ubuntu Live from USB: https://releases.ubuntu.com/focal/ubuntu-20.04.2-desktop-amd64.iso
* Connect to a secure WiFi (hardware switch on) or LAN
#### Download,verify and flash the base image to the SDcard 
* Image: https://raspi.debian.net/verified/20210210_raspi_4_buster.img.xz
* Signature: https://raspi.debian.net/verified/20210210_raspi_4_buster.xz.sha256.asc

    ```bash
    gpg --receive-key E2F63B4353F45989
    gpg --verify 20210210_raspi_4_buster.xz.sha256.asc 
        gpg: Signature made Wed 10 Feb 2021 20:22:05 GMT
        gpg:                using EDDSA key 60B3093D96108E5CB97142EFE2F63B4353F45989
        gpg: Good signature from "Gunnar Wolf <gwolf@gwolf.org>" [unknown]
        gpg:                 aka "Gunnar Eyal Wolf Iszaevich <gwolf@iiec.unam.mx>" [unknown]
        gpg:                 aka "Gunnar Wolf <gwolf@debian.org>" [unknown]
        gpg: Note: This key has expired!
        Primary key fingerprint: 4D14 0506 53A4 02D7 3687  049D 2404 C954 6E14 5360
            Subkey fingerprint: 60B3 093D 9610 8E5C B971  42EF E2F6 3B43 53F4 5989
    cat 20210210_raspi_4_buster.xz.sha256.asc 
        -----BEGIN PGP SIGNED MESSAGE-----
        Hash: SHA256

        425f02915439d92ae13c889cb1e17378076d716e5e37fc557470646a95ccf43c  20210210_raspi_4_buster.img.xz
        -----BEGIN PGP SIGNATURE-----

        iHUEARYIAB0WIQRgswk9lhCOXLlxQu/i9jtDU/RZiQUCYCRAbQAKCRDi9jtDU/RZ
        iX+qAPwMniKYC9fKqAUyYTHf58CWrAeQKczjkwBsgp9bi29zAQEAmXHd/TVZ/x07
        Q4HVd6s4IAEj0H+jkGdMZujtO7sYqg8=
        =ZUv1
        -----END PGP SIGNATURE-----

    sha256sum 20210210_raspi_4_buster.img.xz 
        425f02915439d92ae13c889cb1e17378076d716e5e37fc557470646a95ccf43c  20210210_raspi_4_buster.img.xz
    ```

* Connect SD card reader with a 8GB SD card
* In the file manager open context on the .img.xz file, select `Open With Disk Image Writer` and write the image to the SDcard.
#### Prepare the base image

* Before the first boot edit the `sysconf.txt` on the `RASPIFIRM` partition to be able to ssh remotely - needs an authorized ssh pubkey.
* Generate ssk keys on Ubuntu with:
    ```bash
    ssh-keygen -t rsa -b 4096
    ```

* Copy the ssh pubkey from the Ubuntu image to the `sysconf.txt` the `RASPIFIRM` directory (make sure it is mounted):
    ```bash
    echo "root_authorized_key=$(cat ~/.ssh/id_rsa.pub)" | tee -a /media/ubuntu/RASPIFIRM/sysconf.txt
    ```
* Check with:
    ```bash
    cat /media/ubuntu/RASPIFIRM/sysconf.txt
    ```   
    The `sysconf.txt` will reset after boot and moves the ssh pubkey to `/root/.ssh/authorized_keys`
* Boot the RPi and connect with ssh (use the hostname, `arp -a` or check router))
    ```bash
    ssh root@rpi4-20210210
    ```
* Install basic dependencies
    ```bash
    apt update
    apt install sudo wget
    ```
#### Install Joininbox
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
#### Prepare the SDcard release
 * Make the SDcard image safe to share by removing unique infos like ssh pubkeys and network identifiers:  
     ```bash
    /home/joinmarket/prepare.release.sh
    ```
* Disconnect WiFi/LAN on build laptop (hardware switch off) and shutdown
* Remove Ubuntu LIVE USB stick and cut power from the RaspberryPi
#### Sign the image
* Connect USB stick with [Tails](https://tails.boum.org/) (make it stay offline)
* Power on the Build Laptop (press F12 for boot menu)
* Connect USB stick with GPG signing keys - decrypt drive if needed
* Open Terminal and cd into directory of USB Stick under `/media/amnesia`
* Run `gpg --import backupkey.gpg`, check and exit
* Disconnect USB stick with GPG keys
* Take the SD card from the RaspberryPi and connect with an external SD card reader to the laptop
* Click on boot volume once in the file manger
* Connect another USB stick, open in file manager and delete old files
* Open Terminal and cd into directory of USB stick under `/media/amnesia`
* Run `lsblk` to check on the SD card device name (ignore last partition number)
* Clone the SDcard:   
  `dd if=/dev/[sdcarddevice] | gzip > ./joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz`
* When finished you should see that more than 7GB was copied.
* Create sha256sum:  
  `sha256sum *.gz > sha256.txt`
* Sign:  
  `gpg --detach-sign --armor *.gz`  
  `gpg --clear-sign *.txt`
* Check the files:
  ```bash
  ls
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz      sha256.txt
    joininbox-vX.X.X-YEAR-MONTH-DAY.img.gz.asc  sha256.txt.asc
  ```
* Shutdown the build computer
* Upload the new image to server - put the .sig file and sha256sum.txt next to it
* Copy the sha256sum to GitHub README and update the download link
