#!/bin/bash
# Harness for the passwordToFile EXIT-trap test: sources the functions, runs
# passwordToFile with a mocked dialog and prints the created
# walletPasswordFile path. When this process exits, the EXIT trap installed
# by passwordToFile must remove the file.
# stdout must stay clean except for the final path - keep git noise on stderr.
cd / || exit 1
source /home/joinmarket/_functions.sh || true
wallet="$1"
: >"$wallet"
passwordToFile
printf '%s\n' "$walletPasswordFile"
