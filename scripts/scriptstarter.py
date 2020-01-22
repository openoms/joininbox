#!/home/joinin/joinmarket-clientserver/jmvenv/bin/python

import subprocess
import sys
import os

SCRIPT = sys.argv[1]
WALLET = sys.argv[2]

f = open('/home/joinin/.pw','r')
PW = f.read().strip()
f.close()
os.system('rm -f /home/joinin/.pw')

process = subprocess.Popen(['python', '/home/joinin/joinmarket-clientserver/scripts/%s.py' %SCRIPT,'%s.jmdat' %WALLET, '--wallet-password-stdin'],
                                                                stdin=subprocess.PIPE,
                                                                stdout=subprocess.PIPE,
                                                                universal_newlines=True)
process.stdin.write ("%s" %PW)
process.stdin.close()
   