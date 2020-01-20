#!/usr/bin/env python

import subprocess
import sys

SCRIPT = sys.argv[1]
WALLET = sys.argv[2]

f = open('pw','r')
PW = f.read().replace('\n','')
f.close()

process = subprocess.Popen(['python', '%s' %SCRIPT,'%s' %WALLET, '--wallet-password-stdin'],
                                                                stdin=subprocess.PIPE,
                                                                stdout=subprocess.PIPE,
                                                                universal_newlines=True)
process.stdin.write ("%s" %PW)
process.stdin.close()
for line in process.stdout:
   print(line)
   