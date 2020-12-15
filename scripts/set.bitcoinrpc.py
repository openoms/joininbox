#!/usr/bin/env python3

import configparser
import os
import sys
import getopt

def main():

    description = "# Setting bitcoinRPC in the joinmarket.cfg"
    print(description)

    try:
      opts, args = getopt.getopt(sys.argv[1:], "rphc", ["rpc_user=","rpc_pass=","rpc_host=","rpc_port="])
    except getopt.GetoptError:
      print('# Usage:')
      print('python /home/joinmarket/set.bitcoinrpc.py --rpc_user=$rpc_user --rpc_pass=$rpc_pass --rpc_host=$rpc_host --rpc_port=$rpc_port')
      sys.exit(2)

    for opt, arg in opts:
        if opt in ('-r','--rpc_user'):
            rpc_user = arg
        elif opt in ('-p','--rpc_pass'):
            rpc_password = arg
        elif opt in ('-h','--rpc_host'):
            rpc_host = arg
        elif opt in ('-c','--rpc_port'):
            rpc_port = arg
        else:
            assert False, "unhandled option"
    
    config = configparser.ConfigParser(strict=False, comment_prefixes='/', allow_no_value=True)
    config.read('/home/joinmarket/.joinmarket/joinmarket.cfg')
    
    config.set('BLOCKCHAIN','rpc_user',rpc_user)
    config.set('BLOCKCHAIN','rpc_password',rpc_password)
    config.set('BLOCKCHAIN','rpc_host',rpc_host)
    config.set('BLOCKCHAIN','rpc_port',rpc_port)

    with open('/home/joinmarket/.joinmarket/joinmarket.cfg', 'w') as configfile:
        config.write(configfile)

if __name__ == "__main__":
    main()