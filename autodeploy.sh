#!/usr/bin/sudo /bin/bash
set -e
FILE=/tmp/MESServices.war
cd /tmp
# prompt user for link of the .war file
read -p "Por favor ingrese link de descarga del .war: " Link
# check if the file is a .war file, if not, it proceeds to removing the non-.war file, also, removes existing file with same name but older date of creation
wget -N -r -nd -e robots=off -A.war $Link

if test -f "$FILE"; then
  FILE_NAME=/opt/autodeploy/log/autodeploy
  touch $FILE_NAME
  CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
  NEW_FILENAME=$FILE_NAME.$CURRENT_TIME.log
  mv $FILE_NAME $NEW_FILENAME
  WAR_FILE=MESServices.war
  WAR_NEW_FILE=$CURRENT_TIME.$WAR_FILE
  FILE_UPLOADTEXT="File uploaded by "
  FILE_OWNER=$(stat -c '%U' /tmp/MESServices.war)
  echo $(date -u) "File has been found for AutoDeploy">>$NEW_FILENAME
  echo $(date -u) $FILE_UPLOADTEXT$FILE_OWNER>>$NEW_FILENAME
  echo $(date -u) "Stopping Web Services">>$NEW_FILENAME
  #service mesws stop>>$NEW_FILENAME
  echo $(date -u) "Removing files from directory /opt/jboss-eap-5.2/jboss-as/server/all/tmp/">>$NEW_FILENAME
  #rm -fr /opt/jboss-eap-5.2/jboss-as/server/all/tmp/*>>$NEW_FILENAME
  echo $(date -u) "Removing file MESServices.war from path /opt/jboss-eap-5.2/jboss-as/server/all/deploy">>$NEW_FILENAME
  rm -fr /opt/jboss-eap-5.2/jboss-as/server/all/deploy/MESServices.war>>$NEW_FILENAME
  echo $(date -u) "Copying new MESServices.war to /opt/jboss-eap-5.2/jboss-as/server/all/deploy">>$NEW_FILENAME
  cp /tmp/MESServices.war /opt/jboss-eap-5.2/jboss-as/server/all/deploy/>>$NEW_FILENAME
  echo $(date -u) "Starting up Web Services">>$NEW_FILENAME
  #service mesws start>>$NEW_FILENAME
  echo $(date -u) "Verifying URL after deploy">>$NEW_FILENAME
  #curl http://localhost:8080/MESServices-war/buildLabel/>>$NEW_FILENAME
  echo $(date -u) "Moving deployed file to archive destination">>$NEW_FILENAME
  mv /tmp/$WAR_FILE /tmp/$WAR_NEW_FILE>>$NEW_FILENAME
  mv /tmp/$WAR_NEW_FILE /opt/autodeploy/archive/>>$NEW_FILENAME
  if [ $? -eq 0 ]
  then
    echo $(date -u) "Deployment succeeded.">>$NEW_FILENAME 
    exit 0
  else
    echo "Deployment failed!" >&2>>$NEW_FILENAME
    exit 11
  fi
fi


