## JoininBox
JoinMarket terminal GUI with dialog

**Work In Progress** - suggestions and contributions are welcome

<p align="left">
  <img width="400" src="/images/mainmenu.png">
  <img width="400" src="/images/darkmenu.png">
</p>

### Build a dedicated, secure box for development: [build_joininbox.md](build_joininbox.md)

Tested on:
* Hardkernel Odroid XU4 with Armbian
* Connected to a RaspiBlitz 1.4RCx


### Installation
```bash
git clone https://github.com/openoms/joininbox.git
cd joininbox
sudo build_jouninbox.sh --with-tor
```
### Implemented functions


- [x] INFO "Wallet information" 
- [ ] PAY "Pay with a coinjoin" 
- [ ] TUMBLER "Run the Tumbler" 
- [x] YG "Run the Yield Generator" 
- [ ] HISTORY "Show report" 
- [ ] OBWATCH "Show the offer book" 
- [ ] EMPTY "Empty a mixdepth" 
- [x] CONF_YG "Configure the Yield Generator" 
- [x] STOP "Stop the Yield Generator" 
- [ ] GEN "Generate a wallet" 
- [ ] RESTORE "Restore a wallet" 
- [x] INSTALL "Install an configure JoinMarket" 
- [x] UP_JIB "Update JoininBox"
