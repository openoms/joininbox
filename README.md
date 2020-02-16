## JoininBox - Build a dedicated JoinMarket Box remotely connected to a full node

* Testing on
  * Hardkernel Odroid XU4 with Armbian (more boards to come - pending testing)
  * Ubuntu 18.04 desktop

  * Connected to a RaspiBlitz 1.4RC3 (any Bitcoin Core node can work, including previous RaspiBlitz versions)

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
* Create a new user called `joinin` and set the password.  
 Keep pressing [ENTER] to use the default user information.
 
### Set up JoininBox
* Continue work as the `root` user.
* Continue with the [manual building steps](build_joininbox.md)  
or
* download and run the build script:  
```bash 
$ wget https://raw.githubusercontent.com/openoms/joininbox/master/build_joininbox.sh && sudo bash build_joininbox.sh --with-tor
```

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
- [x] YG "Run the Yield Generator" 
- [x] HISTORY "Show report" 
- [x] OBWATCH "Show the offer book" 
- [ ] EMPTY "Empty a mixdepth" 
- [x] CONF_YG "Configure the Yield Generator" 
- [x] STOP "Stop the Yield Generator" 
- [ ] GEN "Generate a wallet" 
- [ ] RESTORE "Restore a wallet" 
- [x] INSTALL "Install an configure JoinMarket" 
- [x] UP_JIB "Update JoininBox"