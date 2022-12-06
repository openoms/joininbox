#!/bin/bash

# This script runs on every start called by bootstrap.service
# see logs with --> tail -n 100 /home/joininbox/joinin.log

# using: https://github.com/rootzoll/raspiblitz/blob/v1.8/home.admin/_bootstrap.sh

# LOGFILE - store debug logs of bootstrap
# resets on every start
logFile="/home/joinmarket/joinin.log"

# Init bootstrap log file
echo "Writing logs to: ${logFile}"
echo "" > $logFile
sudo chmod 640 ${logFile}
sudo chown root:sudo ${logFile}
echo "***********************************************" >> $logFile
echo "Running Joininbox Bootstrap " >> $logFile
date >> $logFile
echo "***********************************************" >> $logFile

# make sure SSH server is configured & running
sudo /home/joinmarket/standalone/ssh.sh checkrepair >> ${logFile}
