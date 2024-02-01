
#!/bin/bash

#check MESconfirmation event value and store it in a variable
ac=$(curl -u admin:pFTMLty76pxp79zMLPaSgQ 10.16.156.123:8161/admin/queues.jsp | grep -C3 'MII_TO_MESC_WOD</a></td>' | cut -d\  -f1 | awk -F'[^0-9]*' 'NR==5 {print $2}')
#delay the script 1 second
sleep 1
#check if variable ac is greater than 0
if [[ $ac -gt 600 ]]
 then
  echo "sending email"
   #send email with the amount of pending messages from MESC_TO_MII_EVT/
   echo $(date) there are $ac cases in MESC_WOD | mailx -s "Starting AT_Corp SOS " lgomez@aligntech.com
   #delay the script 1 second
   sleep 1
   cd /u01/ftpc9/SosMiiDownload_ATCorp/bin/
   ./runSos.sh start
   #while loop until event value decrease to less than 10
     while [[ $ac -gt 10 ]]
      do
      ac=$(curl -u admin:pFTMLty76pxp79zMLPaSgQ 10.16.156.123:8161/admin/queues.jsp | grep -C3 'MII_TO_MESC_WOD</a></td>' | cut -d\  -f1 | awk -F'[^0-9]*' 'NR==5 {print $2}')
      echo $ac
      sleep 10
      done
    #Start Confirmations
    ./runSos.sh stop
    #move to ftpc folder
   echo $wat | mailx -s "Stopped additional AT_Corp SOS, please check body of this email " lgomez@aligntech.com
   exit 0
 else
  echo "WOD OK" >/dev/null 2>&1
  exit 1
fi
