#!/bin/bash


# CHANGELOG
# - Fixed symlink for /scans
# - Added sos 8040/8041/8042
# - Added sos 8200
# - Moved sos start to the end of the script
# - Disabled aligntech yum repo
# - replaced s3cmd with awscli
# - 2021-05-13 added 8065 8205 SOS

echo "Disabling aligntech yum repo"
/usr/bin/yum-config-manager --disable CentOS-Local
/usr/bin/yum-config-manager --disable aligntech

echo "-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----" > /root/cert.pem

#Import Cert
keytool -importcert -storepass changeit -trustcacerts -alias identrustdstx2  -file /root/cert.pem -keystore /usr/lib/jvm/java/jre/lib/security/cacerts -noprompt 

# Override DNS so that we use our local endpoint (SQA2 only)
echo $(ping -W 1 -c1 mes.corp.sqa2.misa.aligntech.com | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+') sqa2us1emsapp11.aligntech.com >> /etc/hosts

###Install Splunk, this section run manual

curl https://ftpc104.s3.us-west-2.amazonaws.com/splunkforwarder-8.2.2.1-ae6821b7c64b-Linux-x86_64.tgz -o /opt/splunkforwarder-8.2.2.1-ae6821b7c64b-Linux-x86_64.tgz
cd /opt
tar zxvf splunkforwarder-8.2.2.1-ae6821b7c64b-Linux-x86_64.tgz

cat <<-EOF >>  /opt/splunkforwarder/etc/system/local/deploymentclient.conf 

[target-broker:deploymentServer]
targetUri = prdru1infosec01:8089

EOF

cd /opt/splunkforwarder/bin
./splunk start

#create user and pas
#mesteam
#mesteam.123
sudo ./splunk enable boot-start


service splunk restart

####Splunk installed Manual
 
SPLUNK_INDEX=${SPLUNK_INDEX:-sqa2}
SPLUNK_SOURCETYPE=${SPLUNK_SOURCETYPE:-generic_single_line}
 
cat <<-EOF >> /opt/splunkforwarder/etc/system/local/inputs.conf
 
[monitor:///opt/jbossas/jboss-as/*.log]
index = $SPLUNK_INDEX
sourcetype = $SPLUNK_SOURCETYPE
crcSalt = <SOURCE>
 
[monitor:///opt/jbossas/jboss-as/server/all/log/*.log]
index = $SPLUNK_INDEX
sourcetype = $SPLUNK_SOURCETYPE
crcSalt = <SOURCE>
 
[monitor:///opt/tomcat/logs/*.log]
index = $SPLUNK_INDEX
sourcetype = $SPLUNK_SOURCETYPE
crcSalt = <SOURCE>
 
[monitor:///opt/ShopOperations*/logs/wrapper.log]
index = $SPLUNK_INDEX
sourcetype = ftpc_shopops_server
crcSalt = <SOURCE>
 
[monitor:///opt/ShopOperations*/logs/*.log]
index = $SPLUNK_INDEX
sourcetype = ftpc_shopops_app
crcSalt = <SOURCE>
blacklist = wrapper.log
 
[monitor:///opt/ShopOperations*/bin/logs/*.xml]
index = $SPLUNK_INDEX
sourcetype = ftpc_shopops_xml
crcSalt = <SOURCE>
 
EOF
 
service splunk restart
 
MES_CORP_HOST=${MES_CORP_HOST:-172.16.0.15}
 
# Obtain ShopOpsServer code from PlantOpsDownloads.zip.
cd /opt
mkdir ftpc
 cp /home/ec2-user/FTPC10_4/ShopOperationsServerLinux.zip /opt/ftpc

cd /opt/ftpc
#unzip -o  ShopOperationsServerLinux.zip
#unzip -o PlantOpsDownloads.zip ShopOperationsServerLinux.zip > /dev/null
 
 
#Create all the shopops servers
ports=(8030 8031 8032 8033 8034 8035 8036 8037 8038 8045 8040 8041 8042 8134 8200 8065 8205 8060 8201 8070 8210 8215 8220)
stations=(Scan\ Upload\ MX Admin1 Admin1 Admin1 Admin1 Admin1 Pre-MTP\ TFU Pre-STP\ TFU STP Admin1 Auto\ Segmentation Pre-IPL\ TFU IPL Admin1 Admin1\ ScanSegReq Admin1 Admin1 \ ScanSegResp Admin1 Admin1 Admin1 Admin1 Admin1 Admin1 Admin1)
eventsheets=(ACS_ScanUpload ACS_AssetValidation ACS_AssetReplication ACS_TreatUpload AT_MESEventPublisher AT_ACS_Asset_Purge_Event ACS_PreMTPTreatUpload ACS_PreSTPTreatUpload AT_TPS_STPEvent AT_EIG_CORP_WO_Download AT_IOS_AutoSegmentationEvent ACS_PreIPLTreatUpload AT_TPS_IPLEvent AT_MESEventPublisher_IDS AT_TPFORGE_ClinCheckEvent AT_SMARTDDT_ScanSegReq AT_SMARTDDT_ScanSegResp AT_CQA AT_TPFORGE_ClinCheckEvent_CN AT_TPCOMPUTE_AutoDDTReq AT_TPCOMPUTE_AutoDDTResp AT_TPFORGE_ClinCheckEventPublisher AT_SUB_TPS_TPSEvent)
 
 
# Calculate Xmx allotted to each SoS by dividing total ram by
# the number of SoS processes
# xmx = total ram in MB / number of SoS
xmx=$(( $(/bin/free -m | grep Mem | awk '{print $2}')/${#ports[@]} ))
echo "Setting RAM to $xmx"

 
for i in `seq 0 $(( ${#ports[@]} - 1 ))`;
do
    cd /opt/ftpc
    file=/opt/ShopOperationsServer_${ports[$i]}/bin/ShopOperationsServer.xml
    wrapperconf=/opt/ShopOperationsServer_${ports[$i]}/conf/wrapper.conf
    unzip -o ShopOperationsServerLinux.zip -d /opt/ShopOperationsServer_${ports[$i]} > /dev/null
    sed -i -e s/runSos/sos-${ports[$i]}/ /opt/ShopOperationsServer_${ports[$i]}/bin/runSos.sh
    sed -i -e s/Rockwell\ Shop\ Operations\ Server/${eventsheets[$i]}/ /opt/ShopOperationsServer_${ports[$i]}/bin/runSos.sh
    sed -i -e s/8084/${ports[$i]}/ $file
    sed -i -e "s,\(</shop-operations-server-configuration>\),<station>${stations[$i]}</station>\1," $file
    sed -i -e "s,\(</shop-operations-server-configuration>\),<event-sheet-name>${eventsheets[$i]}</event-sheet-name>\1," $file
    cd /opt/ShopOperationsServer_${ports[$i]} && \
    chmod 755 bin/configSosEnv.sh bin/runSos.sh bin/wrapper && \
    sed -i -e "s/@@IIOP_URL@@/jnp:\/\/${MES_CORP_HOST}:1099/" $file && \
    sed -i -e "s/@@HTTP_URL@@/http:\/\/${MES_CORP_HOST}:8080/" $file && \
   cp /opt/ftpc/wrapper.conf /opt/ShopOperationsServer_${ports[$i]}/conf/wrapper.conf
    sed -i -e "s/Xmx512m/Xmx${xmx}m/" $wrapperconf && \
  
    cd /opt
 
cat <<-EOF > /etc/systemd/system/sos-${ports[$i]}.service
[Unit]
Description=${eventsheets[$i]}
After=syslog.target
 
[Service]
Type=forking
ExecStart=/opt/ShopOperationsServer_${ports[$i]}/bin/./runSos.sh start
ExecStop=/opt/ShopOperationsServer_${ports[$i]}/bin/./runSos.sh stop
KillMode=control-group
Environment=SYSTEMD_KILLMODE_WARNING=true
Environment=JAVA_HOME=/usr/lib/jvm/java
RemainAfterExit=no
Restart=always
RestartSec=5s
PIDFile=/opt/ShopOperationsServer_${ports[$i]}/bin/../bin/sos-${ports[$i]}.pid
 
[Install]
WantedBy=multi-user.target
EOF
done
 
# Reload all the startup scripts
systemctl daemon-reload
 
# Create script to manage all instances
cat <<-EOF > /usr/local/bin/sos.sh
#!/bin/bash
 
# Operation is the first argument. Defaults to 'start'
OPERATION=\${1:-start}
for port in ${ports[@]};
do
    systemctl \$OPERATION sos-\${port}
done
EOF
 
 
chmod +x /usr/local/bin/sos.sh
 
# Mount S3 bucket to access Gen2 files
sudo amazon-linux-extras install epel -y
sudo yum install s3fs-fuse -y

yum install epel-release -y
yum install s3fs-fuse -y
mkdir -p /mnt/s3fs
# set iam_role=auto so it gets credentials from the IAM role
echo "s3fs#align-env-sqa2 /mnt/s3fs fuse _netdev,allow_other,iam_role=auto 0 0" >> /etc/fstab
mount /mnt/s3fs

# Create symlinks
ln -s /mnt/s3fs/gen2/acs /scan
ln -s /mnt/s3fs/gen2/acs_pid /scan_pid
 
cat <<-EOF > /usr/local/bin/watchdog-sos.sh
#!/bin/bash
  
# Loop forever
while true;
do
    # Check each ShopOps server
    for sos in 8030 8031 8032 8033 8034 8035 8036 8037 8038 8045 8040 8041 8042;
    do
        # Check whether the log has not been updated for at least 10 minutes
        if [[ \`echo \$((\$(date +%s) - \$(date +%s -r /opt/ShopOperationsServer_\${sos}/logs/wrapper.log)))\` -gt 600 ]]; then
              
            # Check whether there is a connection error at the bottom of the log
            if [ \`tail -n 40 /opt/ShopOperationsServer_\${sos}/logs/wrapper.log | grep  '\(SEVERE:\ ClientUtility\ not\ bound\|Could\ not\ obtain\ connection\|Shutdown\ base\ activity\)' | wc -l\` -gt 0 ]; then
                  
                # Write to the log that we're restarting this service
                echo \`date\` "\${sos} is hung. restarting" >> /var/log/sos-watchdog.log
                  
                # Restart the service
                systemctl restart sos-\${sos}
            fi
        fi
    done
  
    # Check every minute
    sleep 60
done
EOF
 
chmod +x /usr/local/bin/watchdog-sos.sh
 
cat <<-EOF > /etc/systemd/system/sos-watchdog.service
[Unit]
Description=SOS Watchdog
After=syslog.target
  
[Service]
Type=simple
ExecStart=/usr/local/bin/watchdog-sos.sh
KillMode=process
RemainAfterExit=no
Restart=always
RestartSec=5s
  
[Install]
WantedBy=multi-user.target
EOF
# Create script to Restar all instances vy ARG
cat <<-EOF > /usr/local/bin/restartsos.sh
#!/bin/bash

# Operation is the first argument. Defaults to 'restart'
OPERATION=\${1:-Restart}
for port in ${ports[@]};
do
    systemctl \$OPERATION sos-\${port}
done
EOF


chmod +x /usr/local/bin/restartsos.sh


/usr/local/bin/restartsos.sh start

 
# Add custom jar files for sos-8134 (MEP-IDS)

## Create target dir and fetch the jar from S3 bucket
#mkdir -p /opt/ShopOperationsServer_8134/bin/logs/jars/jaxb_dependency
cd /opt/ftpc
curl https://ftpc104.s3.us-west-2.amazonaws.com/jaxb_dependency.zip /opt/ftpc/jaxb_dependency.zip

unzip /opt/ftpc/jaxb_dependency.zip -d /opt/ShopOperationsServer_8134/bin/logs/jars/

# Create xml folder for 8034 (MEP-IDS)
mkdir -p /opt/ShopOperationsServer_8134/xml

# Add the new classpath to the wrapper config
echo 'wrapper.java.classpath.5=/opt/ShopOperationsServer_8134/bin/logs/jars/jaxb_dependency/*.jar' >> /opt/ShopOperationsServer_8134/conf/wrapper.conf

# Add jks files for 8200
mkdir -p /opt/ShopOperationsServer_8200/kafkasettings
# /usr/local/bin/aws s3 cp s3://align-artifacts-usw2/mes/TPForgeReClinCheck/truststore.jks /opt/ShopOperationsServer_8200/kafkasettings/truststore.jks
# /usr/local/bin/aws s3 cp s3://align-artifacts-usw2/mes/TPForgeReClinCheck/keystore.jks /opt/ShopOperationsServer_8200/kafkasettings/keystore.jks

# Reload all the startup scripts
systemctl daemon-reload

echo "Starting services"
/usr/local/bin/sos.sh start

# Start sos-watchdog
systemctl enable sos-watchdog
systemctl start sos-watchdog