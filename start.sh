#!/usr/bin/env bash
PID=$(/opt/local/bin/python2.6 /MyApps/pyload/pyload/pyLoadCore.py --status)
sleep 2
kill -9 $PID
sleep 2
/opt/local/bin/python2.6 /MyApps/pyload/pyload/pyLoadCore.py --daemon
sleep 2
#TERM=$(ps acx | grep Terminal | cut -d" " -f2)
#kill -9 $TERM
