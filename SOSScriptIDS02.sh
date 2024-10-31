#!/bin/bash

sudo su -
lsblk -f
sleep 5
vgdisplay rootvg
sleep 5
lvresize -r -L +30G /dev/mapper/rootvg-rootlv
sleep 10
lvresize -r -L +10G /dev/mapper/rootvg-tmplv
sleep 10
yum -y install cifs-utils unzip

sudo mkdir /mnt/installation

if [ ! -d "/etc/smbcredentials" ]; then

sudo mkdir /etc/smbcredentials

fi

if [ ! -f "/etc/smbcredentials/mescorpdevstorage.cred" ]; then

    sudo bash -c 'echo "username=mescorpdevstorage" >> /etc/smbcredentials/mescorpdevstorage.cred'

    sudo bash -c 'echo "password=yF8tpCJyR1b8YZxm1t0Hgtc37SC4GQNndHJjGkoDsmO+l/mVdRGiv1RH4aVk4alYikoKD9eWqejs+ASteUizAw==" >> /etc/smbcredentials/mescorpdevstorage.cred'

fi

sudo chmod 600 /etc/smbcredentials/mescorpdevstorage.cred
sudo bash -c 'echo "//mescorpdevstorage.file.core.windows.net/installation /mnt/installation cifs nofail,credentials=/etc/smbcredentials/mescorpdevstorage.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab'

systemctl daemon-reload

sudo mount -t cifs //mescorpdevstorage.file.core.windows.net/installation /mnt/installation -o credentials=/etc/smbcredentials/mescorpdevstorage.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

cp /mnt/installation/BinariesforSosLinuxServer/* /tmp
cp /tmp/wrapper.conf /opt/
mv /tmp/ShopOperationsServerLinux.zip /opt 
sleep 10
cp /mnt/installation/BinariesforAppLinuxServer/installApp.zip /opt 
# Install splunk
echo "Install splunk forwarder" | sudo tee /dev/kmsg
cp /mnt/installation/BinariesforAppLinuxServer/splunkforwarder-9.3.0-51ccf43db5bd-Linux-x86_64.tgz /opt/splunkforwarder.tar.gz 
tar -xzf /opt/splunkforwarder.tar.gz -C /opt
rm -rf /opt/splunkforwarder.tar.gz
sleep 10
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd B5qHUEZvae

cat > /opt/splunkforwarder/etc/system/local/deploymentclient.conf <<EOF
[target-broker:deploymentServer]
targetUri = align.splunkcloud.com:8089
EOF

SPLUNK_INDEX=${SPLUNK_INDEX:-prd-mfg}
cat <<-EOF >> /opt/splunkforwarder/etc/system/local/inputs.conf

[monitor:///opt/ShopOps_*/logs/*.log]
index = $SPLUNK_INDEX
sourcetype = mescorp:sos

[monitor:///opt/ShopOps_*/logs/*.log]
index = $SPLUNK_INDEX
sourcetype = mescorp:sos
EOF

mkdir /opt/ftpc
echo "Install yum packages" | sudo tee /dev/kmsg
yum install -y glibc.i686

unzip /opt/ShopOperationsServerLinux.zip -d /opt/ShopOperationsServer_ 
#rm -rf /opt/ShopOperationsServerLinux.zip
unzip /opt/installApp.zip -d /opt/installApp
mkdir -p /usr/java
cp /opt/installApp/installAPP/jdk-8u144-linux-x64.tar.gz /usr/java/
rm -rf /opt/installApp/installAPP/jdk-8u144-linux-x64.tar.gz
tar xvf /usr/java/jdk-8u144-linux-x64.tar.gz -C /usr/java/
rm -fr /usr/java/jdk-8u144-linux-x64.tar.gz
# Appending Java environment variables to /root/.bashrc
echo "export JAVA_HOME=/usr/java/jdk1.8.0_144" >> /root/.bashrc
echo "export PATH=$JAVA_HOME/bin:$PATH" >> /root/.bashrc

MES_CORP_HOST=${MES_CORP_HOST:-mes.prd-azr.aligntech.com}  #need to update with the Jboss application server

# Create all the shopops servers
ports=(8134 8135 8136 8260 8265 8220 8221 8225 8235)
stations=(Admin1 Admin1 Admin1 Admin1 Admin1 Admin1 Admin1 Admin1 Admin1)
eventsheets=(AT_MESEventPublisher_IDS AT_MESEventPublisher_IDS2 AT_MESEventPublisher_IDS3 AT_Translation_Producer AT_Translation_Consumer AT_SUB_TPS_TPSEvent_CN AT_SUB_TPS_TPSEvent AT_CSA_Produce AT_CSA_Response)
xmx=$(( $(/bin/free -m | grep Mem | awk '{print $2}')/${#ports[@]} ))
echo "Setting RAM to $xmx"

for i in `seq 0 $(( ${#ports[@]} - 1 ))`;
do
            cd /opt
                file=/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/ShopOperationsServer.xml
                #wrapperconf=/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/conf/wrapper.conf
                cp -r /opt/ShopOperationsServer_  /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}
                #unzip -o ShopOperationsServerLinux.zip -d /opt/ShopOps_${eventsheets[$i]}_${ports[$i]} > /dev/null
                sed -i -e s/runSos/sos-${ports[$i]}/ /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/runSos.sh
                sed -i -e s/Rockwell\ Shop\ Operations\ Server/${eventsheets[$i]}/ /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/runSos.sh
                sed -i -e s/8084/${ports[$i]}/ $file
                sed -i -e "s,\(</shop-operations-server-configuration>\),<station>${stations[$i]}</station>\1," $file
                sed -i -e "s,\(</shop-operations-server-configuration>\),<event-sheet-name>${eventsheets[$i]}</event-sheet-name>\1," $file
                sed -i -e "s,\(</shop-operations-server-configuration>\),<log-folder>/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/logs</log-folder>\1," $file
                cd /opt/ShopOps_${eventsheets[$i]}_${ports[$i]} && \
                chmod 755 bin/configSosEnv.sh bin/runSos.sh bin/wrapper && \
                sed -i -e "s/@@IIOP_URL@@/remote:\/\/${MES_CORP_HOST}:8080/" $file && \
                sed -i -e "s/@@HTTP_URL@@/http:\/\/${MES_CORP_HOST}:8080/" $file && \
                #cp /tmp/wrapper.conf /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/conf/wrapper.conf
                sed -i -e "s/Xmx512m/Xmx${xmx}m/" $wrapperconf && \
                rm -rf /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/lib/activemq-all-5.15.0.jar
                rm -rf /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/lib/slf4j-api-1.7.21.jar
                rm -rf /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/lib/slf4j-log4j12-1.7.15.jar
                cd /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin
                sed -i -e 's/\r$//' runSos.sh
                cd /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/conf
                sed -i -e 's/\r$//' wrapper.conf
                echo "before cat line service"
                cd /opt
cat <<-EOF > /etc/systemd/system/sos-${ports[$i]}.service
[Unit]
Description=${eventsheets[$i]}
After=syslog.target

[Service]
Type=forking
ExecStart=/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/./runSos.sh start
ExecStop=/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/./runSos.sh stop
KillMode=control-group
Environment=SYSTEMD_KILLMODE_WARNING=true
Environment=JAVA_HOME=/usr/lib/jvm/java
RemainAfterExit=no
Restart=always
RestartSec=5s
PIDFile=/opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/bin/../bin/sos-${ports[$i]}.pid
[Install]
WantedBy=multi-user.target

EOF

sed -i -e 's/\r$//' /opt/ShopOps_${eventsheets[$i]}_${ports[$i]}/conf/wrapper.conf
chkconfig sos-${ports[$i]} on
done



systemctl daemon-reload



##########################################################copy jaxb to 8134-8135-8136##################################################################

for i in 813{4..6}
do
    mkdir -p /opt/ShopOps_AT_MESEventPublisher_IDS*${i}/bin/logs/jars
    unzip /tmp/jaxb_dependency.zip -d /opt/ShopOps_AT_MESEventPublisher_IDS*${i}/bin/logs/jars
    echo yes | cp /tmp/wrapper.conf /opt/ShopOps_AT_MESEventPublisher_IDS*${i}/conf/
done

echo 'wrapper.java.classpath.7=/opt/ShopOps_AT_MESEventPublisher_IDS_8134/bin/logs/jars/jaxb_dependency/*.jar' >> /opt/ShopOps_AT_MESEventPublisher_IDS_8134/conf/wrapper.conf
echo 'wrapper.java.classpath.7=/opt/ShopOps_AT_MESEventPublisher_IDS2_8135/bin/logs/jars/jaxb_dependency/*.jar' >> /opt/ShopOps_AT_MESEventPublisher_IDS2_8135/conf/wrapper.conf
echo 'wrapper.java.classpath.7=/opt/ShopOps_AT_MESEventPublisher_IDS3_8136/bin/logs/jars/jaxb_dependency/*.jar' >> /opt/ShopOps_AT_MESEventPublisher_IDS3_8136/conf/wrapper.conf

##########################################################copy jaxb to 8134-8135-8136##################################################################




echo "Start sos" | sudo tee /dev/kmsg
sudo systemctl daemon-reload

for i in $(seq 0 $(( ${#ports[@]} - 1 )));
do
    sudo systemctl start sos-"${ports[$i]}".service
done


##########################################################create sos.sh script##################################################################

# Create script to manage all instances
echo "Start sos bash script" | sudo tee /dev/kmsg
cat <<EOF > /usr/local/bin/sos.sh
#!/bin/bash
 
# Operation is the first argument. Defaults to 'start'
OPERATION=\${1:-start}
for port in ${ports[@]};
do
    systemctl \${OPERATION} sos-\${port}
done
EOF

chmod +x /usr/local/bin/sos.sh
##########################################################create sos.sh script##################################################################



sudo iptables -A INPUT -p udp --dport 161 -j ACCEPT
sudo firewall-cmd --permanent --add-port=161/udp
sudo iptables -A INPUT -p udp --dport 162 -j ACCEPT
sudo firewall-cmd --permanent --add-port=162/udp
sudo iptables -A OUTPUT -p tcp --dport 8089 -j ACCEPT
sudo firewall-cmd --permanent --add-port=8089/tcp
sudo iptables -A OUTPUT -p tcp --dport 9997 -j ACCEPT
sudo firewall-cmd --permanent --add-port=9997/tcp
sudo iptables-save
sudo firewall-cmd --reload

##########################################################OPEN PORTS FROM FIREWALL##################################################################
for i in 608{2..8} 803{0..8} 804{0..2} 8045 80{6,7,9}0 808{4..8} 809{0..8} 812{0,5} 813{4..6} 820{0..2} 8210 822{0,1,5} 823{0,5} 824{0..9} 825{0,5} 826{0,5} 827{0,5,6} 828{0,1,5} 161 162
do 
firewall-cmd --permanent --add-port=${i}/tcp
done
sudo firewall-cmd --reload

##########################################################CHANGE USER FROM ADMIN TO APPDude##################################################################
for i in ShopOps_*
do 
sed -i 's/admin/appdude/g' /opt/${i}/bin/ShopOperationsServer.xml
sed -i 's/ozew#/Gikbdn4N/g' /opt/${i}/bin/ShopOperationsServer.xml
done

sed -i 's/appdude/oot/g' /opt/ShopOp*_8265/bin/ShopOperationsServer.xml
sed -i 's/appdude/oot/g' /opt/ShopOp*_8260/bin/ShopOperationsServer.xml
sed -i 's/appdude/mes_corp_sub_cn/g' /opt/ShopOp*_8220/bin/ShopOperationsServer.xml
sed -i 's/appdude/mes_corp_sub_cn/g' /opt/ShopOp*_8221/bin/ShopOperationsServer.xml


##########################################################CREATE WATCHDOG SCRIPT##################################################################

cat <<-EOF > /usr/local/bin/watchdogv2.sh
#!/bin/bash

# Root folder containing the ShopOps directories
ROOT_FOLDER="/opt/"

# Error patterns to search for in the log files
ERROR_PATTERNS="(SEVERE:\ ClientUtility\ not\ bound|Could\ not\ obtain\ connection|Shutdown\ base\ activity|.* <-- Wrapper Stopped|SEVERE:\ SQL\ Exception\ message:\ The\ connection\ is\ closed\.)"

# Log file path for recording actions taken by this script
LOG_FILE_PATH="/var/log/sos-watchdog.log"

# List of log files to monitor
LOG_FILES=("wrapper.log" "AcsIntegration.log" "MESEventPublisherSOS.log" "MESEventPublisher2.log" "TreatIntegration.log" "ScanSegResponse.log" "OutboundTranslationSubscriber.log" "CSAResponseActivity.log" "AutoDDTQC.log" "TPForgeReClinCheck.log")

# Iterate over each ShopOps_* directory in the root folder if the version is ShopOps_ use this one
for folder in "$ROOT_FOLDER"/ShopOps_*; do
    
    # Extract the port number from the folder name if the version is ShopOps_ use this one
    port=$(basename "$folder" | sed sed 's/[^0-9]//g')
    
    # Log the directory being processed
    echo "[$(date)] Processing directory: $folder" >> "$LOG_FILE_PATH"
    
    # Iterate over each log file specified in LOG_FILES
    for LOG_FILE in "${LOG_FILES[@]}"; do
        LOG_PATH="${folder}/logs/${LOG_FILE}"
        
        # Check if the log file exists
        if [ ! -f "${LOG_PATH}" ]; then
            continue
        fi
        
        # Check if the log file has been updated in the last 10 minutes
        log_mod_time=$(date +%s -r "${LOG_PATH}")
        current_time=$(date +%s)
        time_diff=$((current_time - log_mod_time))
        
        if [ "$time_diff" -gt 600 ]; then
            echo "[$(date)] Log file $LOG_PATH has not been updated for at least 10 minutes (last modified: $(date -r "${LOG_PATH}")). Restarting the service on port $port." >> "$LOG_FILE_PATH"
            sudo systemctl restart sos-$port
            continue 2
        else
                echo "[$(date)] Log file $LOG_PATH --okay--  $(date -r "${LOG_PATH}")). under the service on port $port. timdiff " >> "$LOG_FILE_PATH"
        fi
        
        # Check for error patterns in the last 50 lines of the log file
        if tail -n 50 "${LOG_PATH}" | grep -E "$ERROR_PATTERNS" > /dev/null; then
            echo "[$(date)] Error pattern found in the log file $LOG_PATH. Restarting the service on port $port." >> "$LOG_FILE_PATH"
            sudo systemctl restart sos-$port
            continue 2
else
                echo "[$(date)] Log file $LOG_PATH --okay--  $(date -r "${LOG_PATH}")). under the service on port $port. errorpattern " >> "$LOG_FILE_PATH"
        fi
        
        # Check for duplicate ports in the log file
        if tail -n 50 "${LOG_PATH}" | grep -E "SEVERE: Port ${port} is occupied by other application" > /dev/null; then
            echo "[$(date)] Duplicate port found in the log file $LOG_PATH. Killing the process on port $port." >> "$LOG_FILE_PATH"
            sudo pkill -9 -f "sos-$port"
            sleep 10
            sudo systemctl restart sos-$port
            continue 2
        fi
    done
done
exit 0
EOF

##########################################################CREATE SERVICE FILE FOR THE WATCHDOG##################################################################

cat <<-EOF > /etc/systemd/system/watchdogv2.service
[Unit]
Description=SOS Watchdog Service
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/watchdogv2.sh
[Install]
WantedBy=multi-user.target
EOF

##########################################################CREATE SYSTEMD TIMER UNIT FILE FOR THE WATCHDOG##################################################################
CAT <<-EOF > /etc/systemd/system/watchdogv2.timer
[Unit]
Description=watchdog service timer

[Timer]

OnBootSec=1min
OnCalendar=*-*-* *:0/10
Unit=watchdogv2.service

[Install]
WantedBy=multi-user.target

EOF

##########################################################CREATE resolv.conf ################################################################################################
cat <<-EOF > /etc/resolv.conf
# Generated by NetworkManager
search aligntech.com
nameserver 10.10.10.50
nameserver 10.10.10.51
nameserver 10.16.243.68
search 2pbvqjriq3tepjykplybid2d3a.xx.internal.cloudapp.net
nameserver 168.63.129.16
EOF

chattr +i /etc/resolv.conf

##########################################################CREATE resolv.conf ################################################################################################


cp /tmp/splunkclouduf.spl /opt
cp /mnt/installation/BinariesforAppLinuxServer/100_align_splunkcloud.zip /tmp/

cp /mnt/installation/BinariesforAppLinuxServer/100_align_splunkcloud.zip /opt/splunkforwarder/etc/apps/ /opt/splunkforwarder/etc/apps/

unzip /opt/splunkforwarder/etc/apps/100_align_splunkcloud.zip /opt/splunkforwarder/etc/apps/100_align_splunkcloud.zip
rm -fr 100_align_splunkcloud.zip
cd /opt/splunkforwarder/bin
systemctl stop splunk
sudo ./splunk enable boot-start
systemctl restart splunk
sudo ./splunk install app /opt/splunkclouduf.spl -update 1 -auth admin:B5qHUEZvae
systemctl restart splunk
yum install -y net-snmp net-snmp-utils net-snmp-devel
sudo net-snmp-create-v3-user -ro -A snmpv3pass -X snmv3encpass -a MD5 -x DES snmpv3user
systemctl stop snmpd.service
systemctl start snmpd.service
rm -fr /tmp/*

timedatectl set-timezone America/Los_Angeles
sudo dnf -y update --security
sudo dnf -y install dnf-automatic

sleep 10

##########################################################Setup Microsoft Defender for Endpoint####################################################################
systemctl start mdatp
sleep 15
cp /mnt/installation/MES_SOS_Exclusions.json /opt/microsoft/mdatp/conf
mdatp exclusion file add --path /opt/microsoft/mdatp/conf/MES_SOS_Exclusions.json --scope global
systemctl restart mdatp
umount /mnt/installation
##########################################################Setup Microsoft Defender for Endpoint####################################################################

sudo yum -y install sysstat
sudo rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
sudo yum -y install procmon