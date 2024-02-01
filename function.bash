#!/bin/bash

#Este script es para el EIG02

pp=$( ps -ef | grep -v grep | grep watchdog-sos -c )
ps aux | grep watchdog-sos
echo $pp
if [ $pp -gt 0 ]
 then
   echo "deteniendo watchdog-sos"
   pid=$(ps aux | grep ssh | grep -v grep | tr -s ' ' | cut -d\  -f2)
   pid=$(echo $pid | cut -d ' ' -f 1)
   echo $pid
   kill -9 $pid
   echo "script watchdog-sos con pid $pid detenido"
 else
   echo "watchdog-sos no esta activo"
 exit
fi