<!-- omit in toc -->
# Prepare a bitcoin node to accept a remote RPC connection

If you have arrived here from runing JoininBox locally on the RaspiBlitz can skip these steps (CTRL+C to exit the connection settings). The connection to the local bitcoin node is set up automatically.

JoinMarket (running in JoininBox) needs to connect to Bitcoin Core via RPC.  
A pruned node with the **bitcoind wallet enabled** will do and txindex is not required.  
- [RaspiBlitz](#raspiblitz)
  - [Enable the bitcoind wallet](#enable-the-bitcoind-wallet)
  - [LAN connection](#lan-connection)
  - [Tor connection](#tor-connection)
- [RoninDojo](#ronindojo)
  - [Enable the bitcoind wallet](#enable-the-bitcoind-wallet-1)
  - [LAN connection](#lan-connection-1)
  - [Tor connection](#tor-connection-1)
  - [Recompile the Docker containers (takes time)](#recompile-the-docker-containers-takes-time)
  - [Get the Credentials](#get-the-credentials)
- [Resources](#resources)
## RaspiBlitz

### Enable the bitcoind wallet 
Since the RaspiBlitz v1.6 run this script:  
`$ config.scripts/network.wallet.sh on`

To set up manually:

* Edit the bitcoin.conf:  
`$ sudo nano /mnt/hdd/bitcoin/bitcoin.conf`
    
* Change the disablewallet option to 0:
    ```
    disablewallet=0
    ```
* Specify the wallet to be used:
    ```
    main.wallet=wallet.dat
    ```
    The default setting in JoininBox is to use the `wallet.dat`.   
    It needs to specified in the `bitcoin.conf` because otherwise when other applications (like Specter) add bitcoind wallets JoinMarket would stop working.

* Restart bitcoind:  
`$ sudo systemctl restart bitcoind`
### LAN connection

In the terminal of the node - allow remote RPC connections to Bitcoin Core  
This can be skipped if you [connect through Tor](#tor-connection)

1) Edit the bitcoin.conf  
    `$ sudo nano /mnt/hdd/bitcoin/bitcoin.conf`

    Add the values:  
    * `rpcallowip=JOININBOX_IP` or `RANGE` 
      * either specify the LAN IP of the computer (here JoininBox)
      * or use a range like: `192.168.1.0/24` - edit to your local subnet - the first 3 numbes of the LAN IP address, the example used here is: 192.168.1.x  
    * `rpcbind=LAN_IP_OF_THE_NODE` 
      * use the local IP of the bitcoin node in the example: `192.168.1.4`
    * can keep the other `rpcallowip` and `rpcbind` entires especially for the localhost: `127.0.0.1`

    Example: 
    ```bash
    rpcallowip=192.168.1.0/24
    rpcbind=192.168.1.4
    ```
2) Restart Bitcoin Core   
   
    `$ sudo systemctl restart bitcoind`

3) Open the firewall to allow the RPC connection from LAN  
   
    edit to your local subnet - in the example here 192.168.1.X):  
    `$ sudo ufw allow from 192.168.1.0/24 to any port 8332`

4) Take note of the `LAN_ADDRESS` of the remote node and fill it in to the `rpc_host` in `joinmarket.cfg`

### Tor connection

On the node - activate Tor and create a Hidden Service

Make sure that Tor is installed or active in the SERVICES menu

Create a Hidden Service to forward the bitcoin RPC port:

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

Fill in the `Tor_Hidden_Service.onion` to the `rpc_host` in the `joinmarket.cfg`

---
## RoninDojo

### Enable the bitcoind wallet 
Copy the two lines as one command to the ssh terminal:
```bash
$ sed -i 's/  -disablewallet=.*$/  -disablewallet=0\
  -wallet=wallet.dat/' ~/dojo/docker/my-dojo/bitcoin/restart.sh
```

Alternatively edit manually:  
`$ nano ~/dojo/docker/my-dojo/bitcoin/restart.sh`  
and modify:
```bash
  -disablewallet=1
```
to
```bash
  -disablewallet=0
```

and add within the brackets:
```bash
  -wallet=wallet.dat
```

### LAN connection

Edit the bitcoind container settings: 

`$ nano ~/dojo/docker/my-dojo/conf/docker-bitcoind.conf`

Set the following: 
```bash
# should be already on
BITCOIND_RPC_EXTERNAL=on   
# the RoninDojo_IP is the LAN IP address of your RoninDojo
BITCOIND_RPC_EXTERNAL_IP=RoninDojo_IP
```

Open the firewall to allow the RPC connection from LAN  
(edit to your local subnet - in the example here 192.168.1.X):  
`$ sudo ufw allow from 192.168.1.0/24 to any port 28256`

Take note: Dojo uses the port 28256 instead of the deafult 8332.

### Tor connection
Create a Hidden Service to forward the bitcoin RPC port:

Edit the torrc:  
`$ sudo nano /etc/tor/torrc`  

Add:
```bash
HiddenServiceDir /var/lib/tor/bitcoinrpc/
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:28256
```
Restart Tor:  
`$ sudo systemctl restart tor`

Show the .onion service address:  
`$ sudo cat /var/lib/tor/bitcoinrpc/hostname`


### Recompile the Docker containers (takes time)

`$ cd ~/dojo/docker/my-dojo && ./dojo.sh upgrade --nolog`

### Get the Credentials
Fill the connection settings from the `5 Credentials` -> `6 Bitcoind` menu:  
Username: RoninDojo  
Password: [RPC Password]  
Host: [RoninDojo_IP or `sudo cat /var/lib/tor/bitcoinrpc/hostname`]  
Port: [28256 for LAN or 8332 for the .onion service] 

---
Remember to use `torify` with the python scripts when connecting remotely through Tor (applied automatically in the JoininBox)

Example:  
`torify wallet-tool.py wallet.jmdat`

also need to [allow Tor to connect to localhost](FAQ.md#allow-tor-to-connect-to-localhost)
## Resources

* [JoinMarket on the RaspiBlitz guide](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/README.md)

* [Connect JoinMarket running on a Linux desktop to a remote node](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_desktop_to_blitz.md)
