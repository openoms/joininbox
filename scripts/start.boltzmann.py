#!/usr/bin/env python3

import configparser
import os
import sys
import getopt

def main(argv):

    description = "\nBoltzmann - https://code.samourai.io/oxt/boltzmann/\n\
A python script computing the entropy of Bitcoin transactions and the linkability of their inputs and outputs.\n\
For a description of the metrics and related discussions:\n\
Bitcoin Transactions & Privacy (part 1) : https://gist.github.com/LaurentMT/e758767ca4038ac40aaf\n\
Bitcoin Transactions & Privacy (part 2) : https://gist.github.com/LaurentMT/d361bca6dc52868573a2\n\
Bitcoin Transactions & Privacy (part 3) : https://gist.github.com/LaurentMT/e8644d5bc903f02613c6\n\
\n\
WARNING: this feature is highly experimental and not optimised to be used with JoinMarket."
    os.system('clear')
    print(description)

    txids = ''
    try:
      opts, args = getopt.getopt(argv,"t:",["txids="])
    except getopt.GetoptError:
      print('python run.boltzmann.py --txids=TXID1,TXID2')
      sys.exit(2)

    for opt, arg in opts:
        if opt in ('-t', '--txids'):
            txids = arg
    config = configparser.ConfigParser(strict=False)

    config.read('/home/joinmarket/.joinmarket/joinmarket.cfg')

    rpc_user = config['BLOCKCHAIN']['rpc_user']
    rpc_password = config['BLOCKCHAIN']['rpc_password']
    rpc_host = config['BLOCKCHAIN']['rpc_host']
    rpc_port = config['BLOCKCHAIN']['rpc_port']

    tor = ''
    if rpc_host.find('.onion') >= 0:
      print('# Connecting to bitcoind RPC over Tor')
      tor = 'torsocks'

    boltzmannpath = "/home/joinmarket/boltzmann/"

    bvenv = ". "+boltzmannpath+"bvenv/bin/activate"

    boltzmann = tor+" python "+boltzmannpath+"boltzmann/ludwig.py -p -x 30 \
--txids="+txids

    run = bvenv+";"+"export BOLTZMANN_RPC_USERNAME="+rpc_user+";\
    export BOLTZMANN_RPC_PASSWORD="+rpc_password+";\
    export BOLTZMANN_RPC_HOST="+rpc_host+";\
    export BOLTZMANN_RPC_PORT="+rpc_port+";"+boltzmann+" 2>/dev/null"

    print('# Exporting RPC connection details')
    print('# Running the command:\n'+boltzmann+'\n')
    os.system(run)

if __name__ == "__main__":
    main(sys.argv[1:])
