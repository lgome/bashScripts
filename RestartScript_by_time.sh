#!/bin/bash

while true;
do
for sos in SosMiiConfirm_activity  ;
do
if [[ `echo $(($(date +%s) - $(date +%s -r /u01/ftpc9/${sos}/logs/wrapper.log)))` -gt 200 ]]; then
#echo "1"
#if [ `tail -n 10 /u01/ftpc9/${sos}/logs/wrapper.log | egrep 'Could\ not\ obtain\ connection|Wrapper\ Stopped' | wc -l` -gt 0 ]; then
#echo "2"
echo `date` "${sos} is hung. restarting" >> /u01/ftpc9/restartLogs/sos-watchdog_by_time.log
service run${sos} stop
sleep 15
service run${sos} start
fi
#fi
done
sleep 3
done
