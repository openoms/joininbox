### Run the Yield Generator with `torify` (remote RPC connection to a full node)

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

### Download and verify Raspbian SDcard image for a Raspberry Pi
* Download image:  
https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip

* Download signature:  
https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip.sig

* Import PGP pubkey:  
`wget https://www.raspberrypi.org/raspberrypi_downloads.gpg.key | gpg --import`

* Verify Image:
`gpg --verify raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip.sig`

### Log in through SSH using a hardware wallet

* See the official pages for:
    * [Trezor](https://wiki.trezor.io/Apps:SSH_agent)
    * [Ledger](https://support.ledger.com/hc/en-us/articles/115005200649)

* Linux client for [TREZOR One](https://trezor.io/), [TREZOR Model T](https://trezor.io/), [Keepkey](https://www.keepkey.com/), and [Ledger Nano S](https://www.ledgerwallet.com/products/ledger-nano-s):
    * [github.com/romanz/trezor-agent](https://github.com/romanz/trezor-agent/blob/master/doc/README-SSH.md)

* Windows client for Trezor and Keepkey:
    * <https://github.com/martin-lizner/trezor-ssh-agent>

* paste the generated SSH pubkey to:  
`nano /home/joinin/.ssh/authorized_keys`

### Activate the bitcoind wallet on a RaspiBlitz
* Edit the bitcoin.conf:  
`$ sudo nano /mnt/hdd/bitcoin/bitcoin.conf`
    
* Change the disablewallet option to 0:
    ```
    disablewallet=0
    ```
* Restart bitcoind:  
`$ sudo systemctl restart bitcoind`

### Error when connecting to a full node remotely through Tor
* Getting the error:
    ```
    socket.gaierror: [Errno -2] Name or service not known
    ```
* Remember to use `torify` with the python scripts when connecting remotely through Tor. Example:  
    `torify wallet-tool.py wallet.jmdat`

### Nuke the joinin user and the /home/joinin folder
`sudo userdel -r joinin`