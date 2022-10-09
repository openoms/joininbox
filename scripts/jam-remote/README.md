# Install Jam and connect to a remote Joininbox

* tested on Debian Bullseye desktop - Ubuntu should also work

### Download the repo
```
git clone github.com/openoms/joininbox
cd joininbox
```

### Install Jam locally
* will be under the user: `jam`
```
cd scripts/jam-remote
bash install.jam.sh on
```

### On your Joininbox
* (optional) update the joininbox scripts: `UPDATE` - `ADVANCED` - `JBCOMMIT`
* start the `API` from `TOOLS`
* (optional) start the ob-watcher from `OFFERS`

### Forward the API and ob-watcher ports with ssh from your Joininbox
```
bash ssh-portforward $JOININBOX_LAN_IP
```
* leave this terminal open until working with Jam
* close when done to close the ssh connection
* Earn will continue to run on the Joininbox
* can check it's logs in the menu - `MAKER` - `LOGS`

### Open Jam locally using the wallets on your remote Joininbox
`https://localhost:7501`
