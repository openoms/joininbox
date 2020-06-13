#!/home/joinmarket/joinmarket-clientserver/jmvenv/bin/python

import subprocess
import sys
import os

SCRIPT = sys.argv[1]
WALLET = sys.argv[2]
OPTION = sys.argv[3]

f = open('/home/joinmarket/.pw','r')
PW = f.read().strip()
f.close()
os.system('rm -f /home/joinmarket/.pw')

logfile = open('%s.log' %SCRIPT, 'w')

process = subprocess.Popen(['python', '/home/joinmarket/joinmarket-clientserver/scripts/%s.py' %SCRIPT,'%s.jmdat' %WALLET, '%s' %OPTION, '--wallet-password-stdin'],
                                                                stdin=subprocess.PIPE,
                                                                universal_newlines=True,
                                                                stderr=subprocess.STDOUT,
                                                                stdout=logfile)
process.stdin.write ("%s" %PW)
process.stdin.close()

process.wait()
logfile.close()