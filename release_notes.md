## v0.3.0 - Standalone pruned node
* Update to [JoinMarket v0.8.2 - Urgent upgrade for takers - to fix leak of input utxo info to makers](https://github.com/JoinMarket-Org/joinmarket-clientserver/releases/tag/v0.8.2)
* Improved signet support
* Show the XPUBs of the JoinMarket wallet to be imported to Specter
* Sign externally built PSBT-s
* Check and load bitcoind wallets automatically
* Run custom RPC commands on the connected node
* QRcode usage in the menu
* Experimental C-lightning installation (CLI only)

Standalone features:
* Run a pruned full node on mainnet with only the SDcard
* Snapshot download from [prunednode.today](https://prunednode.today/) with automated PGP verification
* Add Specter Desktop v1.2.2

Download the SDcard image for the RaspberryPi 4:
* https://mega.nz/folder/hllzVQoY#3a4U-VMfvKOq07I1Laht_g
* alternative link: https://keybase.pub/oms/joininbox-v0.3.0-2021-03-10/

```
0e3078d FAQ: improve build instructions
bede94c rm joinin.conf in prepare.release
48855c8 restart to expand the SDcard and fix startup logic
31d6263 build: don't stop at qrencode, match version
6ad294e clightning: enable-experimental-features
4fbd1ab add mempool.space/signet/api/tx to torthistx
b71e1a0 dialog formatting
5a18c3c fix permissions & rpc_pass when changing networks
848ef2b fix loading bitcoind wallet
d8f3e89 update joinmarket to v0.8.2
d4b2e6c clightning: fix aliases
18f67d8 clightning: switch on the logfile
26f10a6 specter: show the Tor address as QRcode
658036c include the bitcoin wallet to use in customRPC
af333c8 install.clightning: adapt for raspiblitz
a700e48 add clightning install script
0327210 clean aliases, check for user store directory
8b3fe4a fix core symlinks, add qrencode
c6be35e (clightning) INFO: menu options for m0, m4 and to show the DOCS
04f056c readme: add video from Keep It Simple Bitcoin
f239ad1 handle the Yield Generator password in the RAM
3ffa531 QR codes for the OrderBook and Specter
7d9b0d1 fix paths and detail bitcoind config
7aa8c58 wait to display error messages after chooseWallet
e5e02fd fix qr function
2098233 check if the file exists when choosing a wallet
d45a692 display the first new address as a QRcode
1d523dc add DOCS option to TOOLS for links with more info
46c4ec7 add PASSWORD change option to TOOLS
8449240 make all temporary files in RAM
46637f9 add QR option to TOOLS to display text as a QRcode
6354415 readme update with more docs and donation links
0c86dfc check and install optional dependencies
fb657cb change button labels
b047395 (menu-improvements) getRPC values in the customRPC function
158734f Merge pull request #26 from openoms/specter
1f4142a (origin/specter, specter) add PSBT signing option to WALLET menu
0e08c25 add XPUBS option to the WALLET menu
840094f specter: update to 1.2.2
1f60cfc add bitcoind LOGS to TOOLS
bf4672d specter insall fixes
16236e9 add SPECTER menu with UPDATE option
fa71818 add PRUNED node  and LOCAL option
c3336cd implement checkRPC to create and load core wallet
b50ae27 clean variables
71ae34f extend functions for standalone mode and core
fc51260 add Specter Desktop to standalone
837b461 install.hiddenservice: add off option
552574a CONNECT: check to create and load wallet
2739d1c TOOLS: add CUSTOMRPC to run arbitrary commands
9109ac9 WALLET: add option to rescan wallet in bitcoind
803e6d5 FAQ: add link mempool.space/signet
2a82cec FAQ: wallet recovery and hardware recommendation
3c08cde FAQ: update PGP instructions
0a5a1df readme update
5581498 CONFIG: move the RESET option last
cac655c always display info.conf.txt
4dd269e info on the yield generator settings
84cc36d generateJMconfig: always fill raspiblitz settings
e7a2ce6 restructure readme
91728dc format password change dialog
49359a6 FAQ: add signet and public order book links
167cb1d match  build script version with release 0.2
d107d0e FAQ: improve image signing instructions
63db82d start.joininbox: never exit after set.password.sh
```
## v0.2.0 - SDcard image release
* update JoinMarket to v0.8.1
* signet support to try JoinMarket with free coins. Find a faucet, block explorer and more info about signet in the FAQ
* SDcard image release for the RaspberryPi 4 based on pure Debian
* create a watch only wallet on the remotely connected Bitcoin Core

Download the latest SDcard image for the RaspberryPi 4 based on this release:

* https://mega.nz/folder/Jw833QTb#ANyX6WdvPphtCONbeKhAww
* alternative link: https://keybase.pub/oms/joininbox-v0.2.0-2021-02-15/
* build log: https://gist.github.com/openoms/15a6b4a5ac49d0a0cc16c68d95ef8d6a
```
0a5a1df readme update
5581498 CONFIG: move the RESET option last
cac655c always display info.conf.txt
4dd269e info on the yield generator settings
84cc36d generateJMconfig: always fill raspiblitz settings
e7a2ce6 restructure readme
91728dc format password change dialog
49359a6 FAQ: add signet and public order book links
167cb1d match build script version with release 0.2
d107d0e FAQ: improve image signing instructions
63db82d start.joininbox: never exit after set.password.sh
3831f05 bitcoinrpc: create a remote wallet 'joininbox'
02db4d8 improve notes on the remote connection
495dd5f remove the bootstrap.service and script
4ce27ab move scripts to the standalone dir
1d640a6 run expand.rootfs.sh with sudo from standalone dir
d61f0fc updateJoininBox: copy scripts also on reset
302ec53 add do_expand_rootfs for ARM from raspi-config
16fca22 installBitcoinCore: check for existing install
8807e48 correct hash for image
41e4da7 dignet: only create wallet.dat if not present
e9154a2 avoid double tasks in while installing Core
de904e1 minimum_makers = 1 for signet
e7d98e2 download bitcoin core to the SDcard
0637a89 check Tor on first start
d0a0e76 refactor first start process
bd985c6 FAQ: sd card build fixes
4539832 improve the build process
6b2050e switch to new pure debian release
da33526 set.password: format dialogs
ed5e199 fix joininbox first start
073ece7 FAQ: how to add ssh pubkeys
476a0d4 build: how to add ssh pubkeys
e94bdb6 installJoinMarket: pin cryptography module to v3.3.2
58f70fc config: fix menu title
bffd436 improve setupsteps
134db76 build: fix locales
ecf4847 FAQ: complete SDcard release build instructions
25a8991 add prepare.release.sh
0bb31f6 signet: fix wallet creation
7f6b5c3 display the network and localip in the menu
7c5c95f add bootstrap.service for standalone builds (#23)
0c34a4d installJoinMarket: update to v0.8.1
20c523f Merge pull request #22 from openoms/signet
60ba065 (signet) RESET: return to the menu after keypress
220b416 CONFIG: option to reset the joinmarket.cfg
cdeab6f install.signet: better output if file present
cf41d4d install.signet: improve bitcoin core download
19199f2 functions: separate copyJoininboxScripts
65ddd76 add CONFIG menu for connection and .cfg settings
66aab26 _functions: add backupJMconf
f8d672a build: include pure debian image in preparations
c9ed6ab signet: add local instance of bitcoin core
cb4c973 add an option to update JM to the latest commit
```
## v0.1.17 - Tor update option
* option to update Tor to the latest alpha on both X86 and ARM
* improve setup flow on the first run
```
543470b _functions: standardize comments
326fdce update.advanced: Tor update to the latest alpha
0bb4f35 menu: improve setup flow on the first run
04f9b02 stats: remove column 'all' to not overflow on LCD
1e1add2 build: use wget to download tor signing keys
169e6bc improve RPC connectrion instructions
70ec48d add link to nixbitcoin.org/obwatcher/
82e7e48 improve instructions on connecting over LAN
```
## v0.1.16 - remote node connection help and Boltzmann
* streamlined install process for Linux based systems (standalone mode)
* interactive help to connect to a remote bitcoind RPC over LAN or Tor
* add Boltzmann transaction entropy analysis (experimental)
```
b28cafb boltzmann: disclaimer
08eb97c readme: connecting to bitcoind RPC on a RoninDojo
3496bb2 build: update script description
e932853 Merge pull request #18 from openoms/rpc-connection-help
8ee7987 connections: minimise queries
beafd81 set:password: format dialog
0f0125c wallet: make history verbose
22d87a0 connect: improve output
eef6c90 update.advanced: format menu
7deec42 connect: fix while loop
a692627 connect: move while loop to script
5e28051 connect: correct variables
e62d843 start: change user passwords first if standalone
6269a7e connect: ask for new values if unsuccessful
b44052e build: check if pi user exists
74fa13c build: improve output
132299e build: clean output and dependencies
322f746 build: add options specify branch and forked repo
d96fc1f connect to remote node during first run
36e4968 add generateJMconfig and setIRCtoTor functions
e3da3ab add helper script to connect to a remote node
440f289 add Boltzmann to tools
9e87e46 show txid-s in history
840afdf better instructions for preparing a remote node
f18625d installJoinMarket: fix editing dependencies
7b0022e FAQ: use curl to download and import PGP key
```
## v0.1.15 - JoinMarket v0.8.0
* installs JoinMarket v0.8.0
* advanced update options in menu to help testing
* skip libsecp256k1 tests on update and testPR
* usability improvements
```
350d678 add advanced update options to menu
4593d21 joinmarket update to v0.8.0
d366b25 readme: add link to video demonstration
3a5a661 menu.freeze: wait for key once finished
fdcd60d updateJoininBox: fix updating to commit
e0c9b9c install: no libsecp256k1 test on update and testPR
60669f3 installJoinmarket: merge update and testPR
a5e5b56 readme: inspect the build script before running
```
## v0.1.14 - improve standalone installation
* major refactoring of the standalone install process
* improved compatibility with aarch64 environments
* minor UI improvements
* FAQ and README additions
```
e60a1f0 installJoinMarket: don't ask at apt install
4042dde (origin/master, origin/HEAD) installJoinMarket: add all dependencies for coincurve
c366ab2 set.password: apply colors to dialog
5f7ac02 use absolute paths everywhere
f00282b build: fix Tor test and formatting
7b943b2 build: improve base image detection, add to readme
29806b3 installJoinMarket: add coincurve before JM
23260ab FAQ: add note on wallet.dat
3b47666 refactor: check and install JM on the first run
496622c README: update instructions
83e8f01 build_joininbox: test Tor before install
3d56007 build_joininbox: refactor, add focal support
d5bb6e6 installJoinMarket: add libltdl-dev
06af831 build_joininbox.sh: clean script
```

## v0.1.13 - JoinMarket update to v0.7.2
```
2feaa64 updateJoininBox: fix updating to commit
0d39c05 start.joininbox: check for cpu type every time
78cfe9c updateJoininBox: option to update to commit
98a9b3f Order Book: rename consistently
8b394b9 installJoinMarket: update to v0.7.2
761f4dd start.joininbox: check cpu architecture
```
## v0.1.12 - improve update options
```
195b4a6 update: show current versions in dialog
ea5888f _commands: fix the qtgui shortcut
129c10b menu.update: fix path to display JM version
```
## v0.1.11 - improve update functions
```
1504d23 display current version in menu title
664df22 move install and update to functions
6cfed58 format dialog box titles
c61400c payjoin: change dialog and help output
```
## v0.1.10 - JoinMarket update to v0.7.1
```
84a381d joinmarket update to v0.7.1
63f071e wait for key before returning to menu
db595b0 build: Tor config fixes
```
## v0.1.9 - improved QT GUI instructions for Windows
```
9a1677c qtgui: add shortcut, improve windows instructions
79ae230 info.qtgui.sh: fix path in windows intructions
```