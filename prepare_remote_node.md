# Prepare a remote node to accept the JoinMarket connection
JoinMarket (running in JoinInBox) needs to connect to Bitcoin Core.  
A pruned node with the [**wallet enabled**](FAQ.md#activate-the-bitcoind-wallet-on-a-raspiblitz) will do and txindex is not required.  
This guide shows how to prepare a RaspiBlitz to accept this connection.

## LAN connection

In the terminal of the node - allow remote RPC connections to Bitcoin Core  
This can be skipped if you [connect through Tor](#tor-connection)

1) Edit the bitcoin.conf  
    `$ sudo nano /mnt/hdd/bitcoin/bitcoin.conf`

    Add the values:  
    (edit to your local subnet - the first 3 numbes of the LAN IP address, the example used here is: 192.168.1)  
    (can keep the other `rpcallowip` and `rpcbind` entires especially for the localhost: 127.0.0.1)
    ```
    rpcallowip=192.168.1.0/24
    rpcbind=0.0.0.0
    ```
2) Restart Bitcoin Core   
   
    `$ sudo systemctl restart bitcoind`

3) Open the firewall to allow the RPC connection from LAN  
   
    (edit to your local subnet):  
    `sudo ufw allow from 192.168.1.0/24 to any port 8332`  
    `ufw enable`

4) Take note of the `LAN_ADDRESS` of the remote node and fill it in to the `rpc_host` in `joinmarket.cfg`

## Tor connection

On the node - activate Tor and create a Hidden Service

Make sure that Tor is installed or active in the SERVICES menu

#### Create a Hidden Service to forward the bitcoin RPC port

1) On the RaspiBlitz since v1.4 there is a script to create a hidden service:  
    `./config.scripts/internet.hiddenservice.sh bitcoinrpc 8332 8332`  

2) Take note of the `Tor_Hidden_Service.onion` and fill in to the `rpc_host` in the `joinmarket.cfg`

Alternatively proceed manually: 

1) Open the Tor configuration file  
    `$ sudo nano /etc/tor/torrc`

2) Insert the lines  
    ```bash
    # Hidden Service v3 for bitcoinrpc
    HiddenServiceDir /mnt/hdd/tor/bitcoinrpc
    HiddenServiceVersion 3
    HiddenServicePort 8332 127.0.0.1:8332
    ```
3) Restart Tor  
   
    `$ sudo systemctl restart tor` 

4) Take note of the `Tor_Hidden_Service.onion`  
   
    `$ sudo cat /mnt/hdd/tor/bitcoinrpc/hostname`

5) Fill in the `Tor_Hidden_Service.onion` to the `rpc_host` in the `joinmarket.cfg`


Remember to use `torify` with the python scripts when connecting remotely through Tor - applied automatically in the JoininBox

Example:  
`torify wallet-tool.py wallet.jmdat`

also need to [allow Tor to connect to localhost](FAQ.md#allow-tor-to-connect-to-localhost)
## Resources:

* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)

* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)
