# Install Jam and connect to a remote Joininbox

* tested on Debian Bullseye desktop - Ubuntu should also work

### Download the repo
```
git clone github.com/openoms/joininbox
cd joininbox
git checkout jam
```

### Install Jam locally
* will be under the user: `jam`
```
cd scripts/jam-remote
bash install.jam.sh on
```

### On your Joininbox
* (optional) update the joininbox scripts: `UPDATE` - `ADVANCED` - `JBCOMMIT`)
* start the `API` from `TOOLS`
* (optional) start the ob-watcher from `OFFERS`

### Forward the API and ob-watcher ports with ssh from your Joininbox
```
bash ssh-portforward <JOININBOX_LAN_IP
```

### Open Jam locally using the wallets on your remote Joininbox
`https://localhost:7501`
