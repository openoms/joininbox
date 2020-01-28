### Run the Yield Generator with `torify` (remote RPC connection to a full node)

To solve the error when running `$ torify python yg-privacyenhanced.py wallet.jmdat`
```
[INFO]  starting yield generator
[INFO]  Listening on port 27183
[INFO]  Starting transaction monitor in walletservice
1580214062 WARNING torsocks[28563]: [connect] Connection to a local address are denied since it might be a TCP DNS query to a local DNS server. Rejecting it for safety reasons. (in tsocks_connect() at connect.c:192)
```

Edit the `torsocks.conf` and activate the option `AllowOutboundLocalhost 1` :

`$ sudo nano /etc/tor/torsocks.conf`

```
# Set Torsocks to allow outbound connections to the loopback interface.
# If set to 1, connect() will be allowed to be used to the loopback interface
# bypassing Tor. If set to 2, in addition to TCP connect(), UDP operations to
# the loopback interface will also be allowed, bypassing Tor. This option
# should not be used by most users. (Default: 0)
AllowOutboundLocalhost 1
```

Restart Tor:   
`sudo systemctl restart tor`