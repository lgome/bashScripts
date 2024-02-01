#!/bin/bash

set -o errexit

#integer variable that works as a flag for flow execution control
declare -i x=-1

#array variable to store sql query output
declare -a d=($(sqlcmd -S 10.16.157.27 -U 'mes' -P #needtoencryptPasswdusingjavalibrariesorsimilar# -Q "SELECT TOP 1 DATEDIFF(mi,process_start_time,GETDATE()) FROM MES_Production.dbo.XFR_EXTRACT_LOG xel WITH(NOLOCK) ORDER BY process_start_time DESC"))

while [[ ${d[1]} -gt 20 ]]
 do
	if [[ $x -ge 0 ]]
	 then
	 date >> /tmp/LT.log
	 printf "%-8s\n" 'restarting LiveTransfer' >> /tmp/LT.log
	 cd /etc/init.d
	 sleep 2
	 pgrep -f 'activemq|runLoader|LiveTransfer' | xargs kill -9
	 sleep 5
	 ./startLT.sh
	 sleep 5
	# cd /opt/ftpc10/apache-activemq-5.15.0/bin/
	 sleep 1
	 nohup ./startAMQ.sh | tee -a /tmp/LT.log
	 sleep 30
	 ((x++))
	 exit 0
	else
	 printf "%-8s\n" "LT was restarted twice in a row, please restart manually" >> /tmp/LT.log
	 x=-1
	 sleep 900
	 exit 1
	fi
	
  if [[ `curl -vI prdus2mesapp32:8080 | grep '200 OK' | wc -l` -gt o ]]
   then
   printf "%-8s\n" 'jboss OK' &> /dev/null
   else
   printf "%-8s\n" 'restarting jboss' >> /tmp/LT.log
   systemctl restart jboss
  fi
 done
 
 #make it executable with chmod +x and schedule it on crontab
 