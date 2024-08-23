#!/bin/bash
set -e
cd /tmp/
#resize hdd
lsblk -f
vgdisplay rootvg
lvresize -r -L +30G /dev/mapper/rootvg-rootlv
lvresize -r -L +10G /dev/mapper/rootvg-tmplv



# Configure DNS
#echo "Configure internal DNS..." | sudo tee /dev/kmsg
#cat > /etc/dhcp/dhclient.conf << EOF
#timeout 300;
#
## Enable the DHCPv6 Client FQDN Option in our DHCPv6 requests:
#also request dhcp6.fqdn;
#
## Fill in the Client FQDN Option flags field. The EC2 DHCPv6 server
## will override our settings if they don't match what it supports, so
## the exact value here does not matter, but this is configured to
## match what it would set:
#send fqdn.server-update true;
#send fqdn.no-client-update false;
#
#prepend domain-search "aligntech.com";
#prepend domain-name-servers 10.16.243.68;
#EOF
#
#service network restart

# Install splunk
#echo "Install splunk forwarder" | sudo tee /dev/kmsg
#node_hostname=$(curl http://169.254.169.254/latest/meta-data/hostname)

# Configure Splunk
echo "Configure Splunk..." | sudo tee /dev/kmsg
#aws s3 cp s3://dedicated-align-env-qas-mes/splunkforwarder-8.2.5-77015bc7a462-Linux-x86_64.tgz /tmp/splunk_uf.tar.gz --quiet
cd /tmp/
wget https://mescorpdevstorage.blob.core.windows.net/installation/splunkforwarder-8.2.5-77015bc7a462-Linux-x86_64.tgz  --quiet
tar -xzf /tmp/splunkforwarder-8.2.5-77015bc7a462-Linux-x86_64.tgz -C /opt

/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd B5qHUEZvae

cat > /opt/splunkforwarder/etc/system/local/deploymentclient.conf <<EOF
[target-broker:deploymentServer]
targetUri = align.splunkcloud.com:8089
EOF

cat > /opt/splunkforwarder/etc/system/local/inputs.conf <<EOF


[monitor:///opt/ftpc10/S*/logs/*.log]
sourcetype = mescorp:ws
index = qas

[monitor:///opt/ftpc10/jboss-eap-7.0/standalone/log/*.log]
sourcetype = mescorp:ws
index = qas

[monitor:///opt/ftpc10/jboss-eap-7.0/standalone/log/*.json]
sourcetype = mescorp:ws
index = qas

EOF

export JAVA_HOME=/usr/java/jdk1.8.0_144
export PATH=$JAVA_HOME/bin:$PATH

echo "Install yum packages" | sudo tee /dev/kmsg
#yum install -y unzip 

cd /tmp || exit 1

# Copy installation binaries
echo "Download and unpuck zip archives from s3" | sudo tee /dev/kmsg
cd /tmp/
wget https://mescorpdevstorage.blob.core.windows.net/installation/third_party_tools.zip --quiet
unzip third_party_tools.zip
cd third_party_tools/
cp installAPP.zip /tmp/

#aws s3 cp s3://"dedicated-align-env-qas-mes"/third_party_tools/installAPP.zip /tmp/
#aws s3 cp s3://"dedicated-align-env-qas-mes"/WarFiles.zip /tmp/
cd /tmp/
wget https://mescorpdevstorage.blob.core.windows.net/installation/WarFiles.zip --quiet

echo "unzip installapp,warfiles zip" | sudo tee /dev/kmsg

unzip installAPP.zip
unzip WarFiles.zip
rm -fr installAPP.zip
rm -rf splunkforwarder-8.2.5-77015bc7a462-Linux-x86_64.tgz 
rm -rf third_party_tools.zip 

# Install Java
echo "Install java" | sudo tee /dev/kmsg
mkdir -p /usr/java
cp /tmp/installAPP/jdk-8u144-linux-x64.tar.gz /usr/java/
tar xvf /usr/java/jdk-8u144-linux-x64.tar.gz -C /usr/java/
rm -fr /usr/java/jdk-8u144-linux-x64.tar.gz
echo "export JAVA_HOME=/usr/java/jdk1.8.0_144" >> /root/.bashrc
echo "export PATH=$JAVA_HOME/bin:$PATH" >> /root/.bashrc
source /root/.bashrc

# Install Jboss
echo "Install jboss" | sudo tee /dev/kmsg
mkdir -p /opt/ftpc10
unzip /tmp/installAPP/jboss-eap-7.0.zip -d /opt/ftpc10

# Updating JBoss configuration
echo "Update productioncentre.properties" | sudo tee /dev/kmsg
#AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
#MSSQL_SERVER=mes-db.dev-azr.aligntech.com
#MSSQL_USER=$(aws ssm get-parameter --name "/qas/MSSQL_USER" --region "$AWS_REGION" --query Parameter.Value --output text)
#MSSQL_PASSWORD=$(aws ssm get-parameter --name "/qas/MSSQL_PASSWORD" --region "$AWS_REGION" --with-decryption --query Parameter.Value --output text)

#aws s3 cp s3://dedicated-align-env-sqa1-mes/ws_Config/standalone-full.xml /opt/ftpc10/jboss-eap-7.0/standalone/configuration/
cd /tmp/
echo "Download ws_config" | sudo tee /dev/kmsg
wget https://mescorpdevstorage.blob.core.windows.net/installation/ws_Config.zip --quiet
unzip ws_Config.zip
cp /tmp/ws_Config/standalone-full.xml  /opt/ftpc10/jboss-eap-7.0/standalone/configuration/

# Modules 
echo "Download jboss modules" | sudo tee /dev/kmsg
mkdir -p /opt/ftpc10/jboss-eap-7.0/modules/com/rockwell/ftpc/jboss/main
cd /tmp/
wget https://mescorpdevstorage.blob.core.windows.net/installation/ftpc_module.zip --quiet
unzip ftpc_module.zip
 cd ftpc_module/

 #cp /tmp/ftpc_module/Client.jar /opt/ftpc10/jboss-eap-7.0/modules/com/rockwell/ftpc/jboss/main/
#cp /tmp/ftpc_module/module.xml /opt/ftpc10/jboss-eap-7.0/modules/com/rockwell/ftpc/jboss/main/
#cp /tmp/ftpc_module/org.mortbay.jetty-5.1.3.jar /opt/ftpc10/jboss-eap-7.0/modules/com/rockwell/ftpc/jboss/main/
yes |cp -Rf /tmp/ftpc_module/* /opt/ftpc10/jboss-eap-7.0/modules/com/rockwell/ftpc/jboss/main/

echo "Update jboss configuration" | sudo tee /dev/kmsg
sed -i "s/10.10.151.227/$(hostname -I)/g" "/opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap.conf"
#sed -i "s/sqlserver:\/\/BDserver:1433/sqlserver:\/\/$MSSQL_SERVER:1433/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/<user-name>mes<\/user-name>/<user-name>$MSSQL_USER<\/user-name>/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/<password>mes<\/password>/<password>$MSSQL_PASSWORD<\/password>/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"
#sed -i "s/CN_MES_SLA_PRODUCTION/MES_Production/g" "/opt/ftpc10/jboss-eap-7.0/standalone/configuration/standalone-full.xml"

cp /opt/ftpc10/jboss-eap-7.0/bin/init.d/jboss-eap.conf /etc/default

# Jboss as service
echo "create Jboss as service" | sudo tee /dev/kmsg
cat <<-EOF > /etc/systemd/system/jboss.service
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

# Copy config file for WS
echo "Copy config file for WS" | sudo tee /dev/kmsg
cd /tmp/
wget https://mescorpdevstorage.blob.core.windows.net/installation/MESServices_Log4j2.xml --quiet
cp /tmp//MESServices_Log4j2.xml /opt/ftpc10/jboss-eap-7.0/standalone/configuration/

# Create config to point to APP server for this Env
cat <<-EOF > /opt/ftpc10/jboss-eap-7.0/standalone/configuration/mesws-config.properties
MES.ServerURL=http://mes.qas-azr.aligntech.com:8080
EOF

echo "Start jboss service" | sudo tee /dev/kmsg
systemctl daemon-reload
systemctl enable jboss
systemctl start jboss

#sudo iptables -A INPUT -p tcp --dport 9990 -j ACCEPT

#sudo firewall-cmd --permanent --add-port=9990/tcp
#sudo firewall-cmd --reload
#iptables-save
#firewall-cmd --reload

# Deploy war files
/opt/ftpc10/jboss-eap-7.0/bin/jboss-cli.sh -c --controller=localhost:9990 --command="deploy /tmp/MESServices.war"
/opt/ftpc10/jboss-eap-7.0/bin/jboss-cli.sh -c --controller=localhost:9990 --command="deploy /tmp/MESAutomation.war"

# Install Apache ActiveMQ
echo "Install apache ActiveMQ" | sudo tee /dev/kmsg
cd /opt/ftpc10
tar xvf /tmp/installAPP/apache-activemq-5.15.0-bin.tar

# Apache ActiveMQ as service
cat <<-EOF > /etc/systemd/system/activemq.service
[Unit]
Description=Apache ActiveMQ
After=syslog.target

[Service]
Type=forking
ExecStart=/opt/ftpc10/apache-activemq-5.15.0/bin/activemq start
ExecStop=/opt/ftpc10/apache-activemq-5.15.0/bin/activemq stop
PIDFile=/opt/ftpc10/apache-activemq-5.15.0/data/activemq.pid
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
wget -O /opt/splunkclouduf.spl https://mescorpdevstorage.blob.core.windows.net/installation/splunkclouduf.spl
wget -O /opt/splunkforwarder/etc/apps/100_align_splunkcloud.zip https://mescorpdevstorage.blob.core.windows.net/installation/100_align_splunkcloud.zip
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
