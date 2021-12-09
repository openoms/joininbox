## Build a dedicated JoinMarket Box remotely connected to a full node

Tested on:
* Hardkernel Odroid XU4 with Armbian
* Connected to a RaspiBlitz 1.4RCx

### Set up Armbian
* Download the SDcard image:  
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
 
### Preparations
* Configure sudo without password for the joinmarket user
    ```bash
    adduser joinmarket sudo
    # https://www.tecmint.com/run-sudo-command-without-password-linux/
    echo 'joinmarket ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo
    ```
* Install the dependencies and Tor
    ```bash
    # continue to work as root
    sudo su

    # add Tor signing key and repo
    curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
    gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
    echo "deb https://deb.torproject.org/torproject.org buster main" |tee -a /etc/apt/sources.list
    echo "deb-src https://deb.torproject.org/torproject.org buster main" | tee -a /etc/apt/sources.list

    # update and upgrade packages
    apt update
    apt upgrade -y

    # install packages
    apt install -y git virtualenv fail2ban ufw tor torsocks

    ```

### Hardening
* Set up fail2ban and the firewall (UFW)
    ```bash
    systemctl enable fail2ban

    # set up the firewall
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22    comment 'allow SSH'

    # due to the old kernel iptables needs to be configured and restart to set up
    # https://superuser.com/questions/1480986/iptables-1-8-2-failed-to-initialize-nft-protocol-not-supported
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

    ufw enable
    systemctl enable ufw
    ufw status
    ```

* Correct output:
    ```
    Status: active

    To                         Action      From
    --                         ------      ----
    22                         ALLOW       Anywhere                   # allow SSH
    22 (v6)                    ALLOW       Anywhere (v6)              # allow SSH
    ```


* Setting up the ssh keys and removing the password login option is described in the [RaspiBolt Guide](https://raspibolt.org/security.html#login-with-ssh-keys)
    ```bash
    # make ssh keystore for the "joinmarket" user
    sudo -u joinmarket mkdir -p ~/.ssh
    ```
* Open a separate terminal on the desktop to copy the local ssh pubkey (fill in the JoinInBox_IP):
    ```bash
    cat ~/.ssh/id_rsa.pub | ssh joinmarket@JoinInBox_IP 'cat >> ~/.ssh/authorized_keys && chmod -R 700 ~/.ssh/'
    ```

* Can consider storing the ssh keys for login on a [Trezor/Ledger or Keepkey hardware wallet](FAQ.md#log-in-through-ssh-using-a-hardware-wallet).

### Install JoinMarket
* install with the `joinmarket` user
    ```bash
    # leave root and switch to the "joinmarket" user
    su - joinmarket

    # install JoinMarket from the source code
    git clone https://github.com/JoinMarket-Org/joinmarket-clientserver.git
    cd joinmarket-clientserver
    # latest release: https://github.com/JoinMarket-Orgjoinmarket-clientserver/releases
    git reset --hard v0.8.2
    ./install.sh --without-qt
    ```
### Set up JoinMarket
* activate and start to generate config
    ```bash
    # activate and start to generate config
    $ source jmvenv/bin/activate
    (jmvenv) $ cd scripts
    (jmvenv) $ python wallet-tool.py generate
    ```
    ```
    Created a new `joinmarket.cfg`. Please review and adopt the settings    and restart joinmarket.
    ```

* Edit the joinmarket.cfg  
    `$ nano ~/.joinmarket/joinmarket.cfg` 

    Fill in the values in CAPITALs

    ```
    [BLOCKCHAIN]
    #options: bitcoin-rpc, regtest
    blockchain_source = bitcoin-rpc
    network = mainnet
    rpc_host = LAN_IP_ADDRESS or HIDDEN_SERVICE_ADDRESS_FOR_BITCOINRPC.onion
    rpc_port = 8332
    rpc_user = RPC_USERNAME_OF_THE_REMOTE_NODE (AS IN BITCOIN.CONF)
    rpc_password = RPC_PASSWORD_OF_THE_REMOTE_NODE (AS IN BITCOIN.CONF)
    ```
* To make JoinMarket communicate through Tor to the peers comment out the clearnet communication channels (place a `#` on the front of the line - means it won`t be used by the script):

    ```
    [MESSAGING:server1]
    #host = irc.cyberguerrilla.org

    ...

    [MESSAGING:server2]
    #host = irc.darkscience.net
    ```
* Uncomment (remove the `#` from front of) the entries related to Tor:
    ```
    #for tor
    host = epynixtbonxn4odv34z4eqnlamnpuwfz6uwmsamcqd62si7cbix5hqad.onion
    socks5 = true
    
    ...

    #for tor
    host = darksci3bfoka7tw.onion
    socks5 = true
    ```

### Clone this repo and copy the scripts
 For testing or contributing only for now
```
cd
git clone https://github.com/openoms/joininbox.git
chmod -R +x ./joininbox/
cp ./joininbox/scripts/* ~/
```

* Try the JoininBox menu 
```bash
$ /home/joinmarket/menu.sh
```

## Resources:

* [Prepare a remote node to accept the JoinMarket connection](prepare_remote_node.md)