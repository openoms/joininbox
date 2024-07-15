# Install Jam and connect to a remote Joininbox

* tested on Debian Bullseye and Bookworm desktop - Ubuntu should also work

## Steps in your Joininbox terminal
* (optional) update the joininbox scripts: `UPDATE` - `ADVANCED` - `JBCOMMIT`
* start the `API` from `TOOLS`
* (optional) start the ob-watcher from `OFFERS`

## Steps on your desktop
### Download the repo
* move to a directory where the joininbox repo will be stored
  ```
  git clone https://github.com/openoms/joininbox
  cd joininbox
  ```

### Install Jam locally
* will be under the user: `jam`
  ```
  cd scripts/jam-remote
  bash install.jam.sh on
  ```

### Forward the API and ob-watcher ports with ssh from your Joininbox
* run the ssh-port-forward script in the `joininbox/scripts/jam-remote` folder
  ```
  bash ./ssh-port-forward.sh $JOININBOX_LAN_IP
  ```
* leave this terminal open until working with Jam
* close when done to close the ssh connection

### Open Jam locally using the wallets on your remote Joininbox
* open Jam at https://localhost:7501
* accept the self-signed certificate served from your Joininbox
* Use Jam - docs: https://jamdocs.org/
* Earn will continue to run on the Joininbox even after the terminal and Jam windows are closed
* can check the logs in the Joininbox menu - `MAKER` - `LOGS`
