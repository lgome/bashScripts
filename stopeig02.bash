#!/bin/bash

#Este script es para el EIG02

set -e

#nos vamos a init.d 
cd /etc/init.d
#paramos confirmaciones
sh StopConfirmations.sh
#retrasamos la ejecucion del script durante 2 segundos
sleep 2
#nos vamos a la carpeta donde se encuentran los scripts RestartScript y watchdog-sos
cd /u01
#declaramos la variable pp y verificamos que el script watchdog-sos esta corriendo
pp=$( ps -ef | grep -v grep | grep watchdog-sos.sh -c )
ps aux | grep watchdog-sos
echo $(date) "el numero de procesos activos para watchdog-sos son: " $pp 
if [ $pp -gt 0 ]
 then
   echo $(date) "deteniendo watchdog-sos"
   pid=$(ps aux | grep watchdog-sos.sh | grep -v grep | tr -s ' ' | cut -d\  -f2)
   #pid=$(echo $pid | cut -d ' ' -f 1)
   echo $(date) "el PID de watchdog-sos es: " $pid
   sudo kill -15 $pid
   echo $(date)"script watchdog-sos con pid $pid detenido"
 else
   echo "watchdog-sos no esta activo, nada que detener"
 exit
fi
#declaramos variable pp y asignamos la cantidad de procesos 
pp=$( ps -ef | grep -v grep | grep RestartScript_by_String -c )
ps aux | grep RestartScript_by_String
echo $(date) "el numero de procesos activos para RestartScript_by_String son: " $pp 
if [ $pp -gt 0 ]
 then
   echo $(date) "deteniendo RestartScript_by_String"
   pid=$(ps aux | grep RestartScript_by_String.sh | grep -v grep | tr -s ' ' | cut -d\  -f2)
   #pid=$(echo $pid | cut -d ' ' -f 1)
   echo $(date) "el PID de RestartScript_by_String es: " $pid
  sudo kill -15 $pid
   echo $(date)"script RestartScript_by_String con pid $pid detenido"
 else
   echo "RestartScript_by_String no esta activo, nada que detener"
 exit
fi
#declaramos variable pp y asignamos la cantidad de procesos 
pp=$( ps -ef | grep -v grep | grep RestartScript_by_time.sh -c )
ps aux | grep RestartScript_by_String
echo $(date) "el numero de procesos activos para RestartScript_by_time son: " "$pp" 
if [ "$pp" -gt 0 ]
 then
   echo $(date) "deteniendo RestartScript_by_String"
   pid=$(ps aux | grep RestartScript_by_time.sh | grep -v grep | tr -s ' ' | cut -d\  -f2)
   #pid=$(echo $pid | cut -d ' ' -f 1)
   echo $(date) "el PID de RestartScript_by_time es: " "$pid"
  sudo kill -15 "$pid"
   echo $(date) "script RestartScript_by_time con pid $pid detenido"
   sleep 2
   while [ "$pp" -ge 10 ]
   do 
   echo "$pp"
   done
   if [ "$pp" -le 10 ]
   then
   #encendemos confirmaciones
  sudo sh /etc/init.d/StartConfirmations.sh
   
  #levantamos watchdog-sos
  sudo sh /u01/watchdog-sos.sh &
  #levantamos RestartScript_by_String
  sudo sh /u01/RestartScript_by_String.sh &
#levantamos RestartScript_by_time
  sudo sh /u01/RestartScript_by_time.sh &
   fi
 else
   echo "RestartScript_by_time no esta activo, nada que detener"
 exit
fi
if [ $? -eq 0 ]
  then
    echo "confirmaciones exitosamente reiniciadas" 
    exit 0
  else
    echo "fallo al reiniciar confirmaciones"
    exit 1
fi


exit


