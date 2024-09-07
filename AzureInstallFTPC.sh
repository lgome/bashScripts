#!/bin/bash
#Resize partitions
lsblk -f
sleep 5
vgdisplay rootvg
sleep 5
lvresize -r -L +30G /dev/mapper/rootvg-rootlv
sleep 10
lvresize -r -L +10G /dev/mapper/rootvg-tmplv
sleep 10
# Install splunk
#echo "Install splunk forwarder" | sudo tee /dev/kmsg
#node_hostname=$(curl http://169.254.169.254/latest/meta-data/hostname)
yum -y install cifs-utils

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

# Configure Splunk
echo "Configure Splunk..." | sudo tee /dev/kmsg
cd /tmp
cp /mnt/installation/BinariesforAppLinuxServer/* /tmp
sleep 2

tar -xzf /tmp/splunkforwarder-8.2.5-77015bc7a462-Linux-x86_64.tgz -C /opt

/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd B5qHUEZvae

cat > /opt/splunkforwarder/etc/system/local/deploymentclient.conf <<EOF
[target-broker:deploymentServer]
targetUri = align.splunkcloud.com:8089
EOF

SPLUNK_INDEX=${SPLUNK_INDEX:-dev}

cat <<-EOF >> /opt/splunkforwarder/etc/system/local/inputs.conf

[monitor:///opt/ftpc10/jboss-eap-7.0/standalone/log/*.log]
index = $SPLUNK_INDEX
sourcetype = jboss
EOF

export JAVA_HOME=/usr/java/jdk1.8.0_144
export PATH=$JAVA_HOME/bin:$PATH

echo "Install yum packages" | sudo tee /dev/kmsg
#yum install -y unzip awscli java-1.8.0-openjdk-devel

cd /tmp || exit 1

#Copy 3rd party tools from s3 bucket
cd /tmp
echo "Download and unpuck zip archives from container" | sudo tee /dev/kmsg
#wget https://mescorpdevstorage.blob.core.windows.net/installation/installAPP.zip
#wget https://mescorpdevstorage.blob.core.windows.net/installation/FTPC10_4.zip
#wget https://mesinstallfiles.blob.core.windows.net/mescorpinstall/ProductionCentreWebStart-1.0.100013.zip

#Unzipping installAPP.zip
unzip installAPP.zip && rm -fr installAPP.zip

#Install Java
echo "Install java" | sudo tee /dev/kmsg
mkdir -p /usr/java
cd /usr/java/ || exit 1
cp /tmp/installAPP/jdk-8u144-linux-x64.tar.gz .
tar xvf jdk-8u144-linux-x64.tar.gz && rm -fr jdk-8u144-linux-x64.tar.gz

# Appending Java environment variables to /root/.bashrc
echo "export JAVA_HOME=/usr/java/jdk1.8.0_144" >> /root/.bashrc
echo "export PATH=$JAVA_HOME/bin:$PATH" >> /root/.bashrc

#Install Jboss
echo "Install jboss" | sudo tee /dev/kmsg
mkdir -p /opt/ftpc10
cd /opt/ftpc10 || exit 1
unzip /tmp/installAPP/jboss-eap-7.0.zip

# Processing FTPC10_4.zip
echo "Process ftpc archive" | sudo tee /dev/kmsg
cd /tmp || exit 1
unzip FTPC10_4.zip && rm -fr FTPC10_4.zip
cd /tmp/FTPC10_4 || exit 1

# Updating productioncentre.properties
echo "Update productioncentre.properties" | sudo tee /dev/kmsg
sed -i "s/localhost/$(hostname -I | sed -e 's/\ *$//g')/g" productioncentre.properties  #on cloud on last Environment we use IP on behalf the hostname
sed -i "s/Windows/Linux/g" productioncentre.properties
sed -i "s/AppServer/MES_Corp_SQA1/g" productioncentre.properties  #could be change depend of SQA1 or SQA2

java -cp DSDeployTools.jar com.datasweep.plantops.deploytools.URLConfig productioncentre.properties
cp -f *.ear /opt/ftpc10/jboss-eap-7.0/standalone/deployments/

# Updating JBoss configuration
echo "Update jboss configuration" | sudo tee /dev/kmsg
#AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
#MSSQL_SERVER=db-mes-corp.sqa1-mes.misa.aligntech.com
#MSSQL_USER=$(aws ssm get-parameter --name "/sqa1/MSSQL_USER" --region "$AWS_REGION" --query Parameter.Value --output text)
#MSSQL_PASSWORD=$(aws ssm get-parameter --name "/sqa1/MSSQL_PASSWORD" --region "$AWS_REGION" --with-decryption --query Parameter.Value --output text)

sed -i "s/10.10.151.227/$(hostname -I | sed -e 's/\ *$//g')/g" "/opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap.conf"
#sed -i "s/sqlserver:\/\/BDserver:1433/sqlserver:\/\/$MSSQL_SERVER:1433/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/<user-name>mes<\/user-name>/<user-name>$MSSQL_USER<\/user-name>/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/<password>mes<\/password>/<password>$MSSQL_PASSWORD<\/password>/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/CN_MES_SLA_PRODUCTION/MES_Production/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/devus1fabapp04.aligntech.com/mes-corp.sqa1-mes.misa.aligntech.com/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"

cp /opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap.conf /etc/default

#Jboss as service
SYSTEMD_SERVICE_PATH="/etc/systemd/system/jboss.service"
tee "$SYSTEMD_SERVICE_PATH" << 'EOF'
[Unit]
Description=Jboss EAP
After=syslog.target

[Service]
Type=forking
ExecStart=/opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap-rhel.sh start
ExecStop=/opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap-rhel.sh stop
PIDFile=/var/run/jboss-eap/jboss-eap.pid
KillMode=control-group
Environment=SYSTEMD_KILLMODE_WARNING=true
Environment=JAVA_HOME=/usr/java/jdk1.8.0_144/jre
RemainAfterExit=no
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "Start jboss service" | sudo tee /dev/kmsg
systemctl daemon-reload
systemctl enable jboss.service
systemctl start jboss.service

# Update ear
#echo "Update ear" | sudo tee /dev/kmsg
#cd /tmp
#unzip ProductionCentreWebStart-1.0.100013.zip && rm -fr ProductionCentreWebStart-1.0.100013.zip
#cp -f /opt/ftpc10/jboss-eap-7.0/standalone/deployments/ProductionCentreWebStart.ear .
#chmod +x updateProductionCentreWebStart.sh
#./updateProductionCentreWebStart.sh ProductionCentreWebStart.ear ProductionCentreWebStart.jar
#mv /opt/ftpc10/jboss-eap-7.0/standalone/deployments/ProductionCentreWebStart.ear /opt/ftpc10/jboss-eap-7.0/standalone/deployments/ProductionCentreWebStart.ear_old
#cp -f ProductionCentreWebStart.ear /opt/ftpc10/jboss-eap-7.0/standalone/deployments/

#install modules
cd /tmp
#wget https://mescorpdevstorage.blob.core.windows.net/installation/modules.zip  --quiet
unzip modules.zip
yes |cp -Rf  /tmp/modules /opt/ftpc10/jboss-eap-7.0/
systemctl restart jboss


#Install Apache ActiveMQ
echo "Install apache ActiveMQ" | sudo tee /dev/kmsg

cd /opt/ftpc10
tar xvf /tmp/installAPP/apache-activemq-5.15.16-bin.tar.gz

# Apache ActiveMQ as service
cat <<-EOF > /etc/systemd/system/activemq.service
[Unit]
Description=Apache ActiveMQ
After=syslog.target

[Service]
Type=forking
ExecStart=/opt/ftpc10/apache-activemq-5.15.16/bin/activemq start
ExecStop=/opt/ftpc10/apache-activemq-5.15.16/bin/activemq stop
PIDFile=/opt/ftpc10/apache-activemq-5.15.16/data/activemq.pid
KillMode=control-group
Environment=JAVA_HOME=/usr/java/jdk1.8.0_144/jre
RemainAfterExit=no
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "Start apache ActiveMQ" | sudo tee /dev/kmsg
systemctl daemon-reload
systemctl enable activemq.service
systemctl start activemq.service
echo "Iptables" >/tmp/iptables.txt
sudo iptables -A INPUT -p tcp --dport 8161 -j ACCEPT
sudo firewall-cmd --permanent --add-port=8161/tcp
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo iptables -A INPUT -p tcp --dport 61616 -j ACCEPT
sudo firewall-cmd --permanent --add-port=61616/tcp
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
echo "completed Iptables" >/tmp/iptables.txt
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
mv /tmp/splunkclouduf.spl /opt/splunkclouduf.spl
mv /tmp/100_align_splunkcloud.zip /opt/splunkforwarder/etc/apps/100_align_splunkcloud.zip
cd /opt/splunkforwarder/etc/apps/
unzip 100_align_splunkcloud.zip
rm -fr 100_align_splunkcloud.zip
cd /opt/splunkforwarder/bin
sudo ./splunk enable boot-start
systemctl restart splunk
sudo ./splunk install app /opt/splunkclouduf.spl -update 1 -auth admin:B5qHUEZvae
systemctl restart splunk
yum install -y net-snmp net-snmp-utils net-snmp-devel
sudo net-snmp-create-v3-user -ro -A snmpv3pass -X snmv3encpass -a MD5 -x DES snmpv3user
systemctl stop snmpd.service
systemctl start snmpd.service
sleep 2
umount /mnt/installation
