# Prepare a remote node to accept the JoinMarket connection
JoinMarket (running in JoininBox) needs to connect to Bitcoin Core.  
A pruned node with the wallet enabled will do and txindex is not required.  
In this guide shows how to prepare a RaspiBlitz to accept this connection.

## LAN connection

### In the node terminal - allow remote RPC connections to Bitcoin Core
This can be skipped if you connect through Tor (see [below](#tor-connection))

1) #### Edit the bitcoin.conf:  
    `$ sudo nano /mnt/hdd/bitcoin/bitcoin.conf`

    Change the values (edit to your local subnet): 
    ```
    #rpcallowip=127.0.0.1
    #rpcbind=127.0.01:8332
    rpcallowip=192.168.1.0/24
    rpcbind=0.0.0.0
    ```
2) #### Restart Bitcoin Core:  
    `$ sudo systemctl restart bitcoind`

3) #### The firewall needs to be opened to allow the RPC connection from LAN
    (edit to your local subnet):  
    `sudo ufw allow from 192.168.1.0/24 to any port 8332`  
    `ufw enable`

## Tor connection

### On the node - activate Tor and create a Hidden Service

Make sure that Tor is ative in the SERVICES menu.

#### Create a Hidden Service to forward the bitcoin RPC port

1) #### Open the Tor configuration file:  
    `$ sudo nano /etc/tor/torrc`

2) #### Insert the lines:
    ```bash
    # Hidden Service v3 for bitcoinrpc
    HiddenServiceDir /mnt/hdd/tor/bitcoinrpc
    HiddenServiceVersion 3
    HiddenServicePort 8332 127.0.0.1:8332
    ```
3) #### Restart Tor:   
    `$ sudo systemctl restart tor` 

4) #### Take note of the Tor Hidden Service address:  
    `$ sudo cat /mnt/hdd/tor/bitcoinrpc/hostname`

## Resources:

* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)

* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)