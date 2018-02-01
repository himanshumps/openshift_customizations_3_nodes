#! /bin/sh
#1.	On the bastion host, set up the yum repository configuration file /etc/yum.repos.d/open.repowith the following repositories
export  OWN_REPO_PATH=http://admin.na.shared.opentlc.com/repos/ocp/3.6
#2.	Add the OpenShift Container Platform repository mirror to the bastion host
cat << EOF > /etc/yum.repos.d/open.repo
[rhel-7-server-rpms]
name=Red Hat Enterprise Linux 7
baseurl=${OWN_REPO_PATH}/rhel-7-server-rpms
enabled=1
gpgcheck=0

[rhel-7-server-rh-common-rpms]
name=Red Hat Enterprise Linux 7 Common
baseurl=${OWN_REPO_PATH}/rhel-7-server-rh-common-rpms
enabled=1
gpgcheck=0

[rhel-7-server-extras-rpms]
name=Red Hat Enterprise Linux 7 Extras
baseurl=${OWN_REPO_PATH}/rhel-7-server-extras-rpms
enabled=1
gpgcheck=0

[rhel-7-server-optional-rpms]
name=Red Hat Enterprise Linux 7 Optional
baseurl=${OWN_REPO_PATH}/rhel-7-server-optional-rpms
enabled=1
gpgcheck=0

[rhel-7-fast-datapath-rpms]
name=Red Hat Enterprise Linux 7 Fast Datapath
baseurl=${OWN_REPO_PATH}/rhel-7-fast-datapath-rpms
enabled=1
gpgcheck=0
EOF
cat << EOF >> /etc/yum.repos.d/open.repo

[rhel-7-server-ose-3.6-rpms]
name=Red Hat Enterprise Linux 7 OSE 3.6
baseurl=${OWN_REPO_PATH}/rhel-7-server-ose-3.6-rpms
enabled=1
gpgcheck=0
EOF
#3.	Deactivate the previous Red Hat repositories, as they are not needed anymore
mv /etc/yum.repos.d/redhat.{repo,disabled}
#4.	Clean up and list the repositories on the bastion host
yum clean all ; yum repolist
#5.	Configure the master and nodes by disabling redhat.repo and copying the open.repo file to all of the nodes directly from the bastion host
for node in master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; do
		echo Copying open repos to $node
		scp /etc/yum.repos.d/open.repo ${node}:/etc/yum.repos.d/open.repo
		ssh ${node} 'mv /etc/yum.repos.d/redhat.{repo,disabled}'
		ssh ${node} yum clean all
		ssh ${node} yum repolist
done
#1.	Install the bind and bind-utils packages
yum -y install bind bind-utils
# 2.	Verify that you have correctly configured the $GUID and $guid environment variables
echo GUID is $GUID and guid is $guid
#	If the environment variables $GUID and $guid are not set, run the following commands:
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export guid=`hostname|cut -f2 -d-|cut -f1 -d.`
host infranode1-$GUID.oslab.opentlc.com ipa.opentlc.com |grep infranode | awk '{print $4}'
HostIP=`host infranode1-$GUID.oslab.opentlc.com  ipa.opentlc.com |grep infranode | awk '{print $4}'`
domain="cloudapps-$GUID.oslab.opentlc.com"
echo $HostIP $domain
#4.	Create the zone file with the wildcard DNS
mkdir /var/named/zones
echo "\$ORIGIN  .
\$TTL 1  ;  1 seconds (for testing only)
${domain} IN SOA master.${domain}.  root.${domain}.  (
  2011112904  ;  serial
  60  ;  refresh (1 minute)
  15  ;  retry (15 seconds)
  1800  ;  expire (30 minutes)
  10  ; minimum (10 seconds)
)
  NS master.${domain}.
\$ORIGIN ${domain}.
test A ${HostIP}
* A ${HostIP}"  >  /var/named/zones/${domain}.db
cat /var/named/zones/${domain}.db
# 5.	Configure named.conf
echo "// named.conf
options {
  listen-on port 53 { any; };
  directory \"/var/named\";
  dump-file \"/var/named/data/cache_dump.db\";
  statistics-file \"/var/named/data/named_stats.txt\";
  memstatistics-file \"/var/named/data/named_mem_stats.txt\";
  allow-query { any; };
  recursion yes;
  /* Path to ISC DLV key */
  bindkeys-file \"/etc/named.iscdlv.key\";
  forwarders {
   192.168.0.1;
  };
  allow-recursion { 192.168.0.0/16; };
};
logging {
  channel default_debug {
    file \"data/named.run\";
    severity dynamic;
  };
};
zone \"${domain}\" IN {
  type master;
  file \"zones/${domain}.db\";
  allow-update { key ${domain} ; } ;
};" > /etc/named.conf
cat /etc/named.conf
#6.	Correct the file permissions and start the DNS server
chgrp named -R /var/named ; \
 chown named -Rv /var/named/zones ; \
 restorecon -Rv /var/named ; \
 chown -v root:named /etc/named.conf ; \
restorecon -v /etc/named.conf ;
#7.	Enable and start named
systemctl enable named && systemctl start named
#8.	Configure iptables to allow inbound DNS queries
iptables -I INPUT 1 -p tcp --dport 53 -s 0.0.0.0/0 -j ACCEPT ; \
iptables -I INPUT 1 -p udp --dport 53 -s 0.0.0.0/0 -j ACCEPT ; \
iptables-save > /etc/sysconfig/iptables
#1.	Test the DNS server on the administration host:
host test.cloudapps-$GUID.oslab.opentlc.com 127.0.0.1
#2.	Test with an external name server:
host test.cloudapps-$GUID.oslab.opentlc.com 8.8.8.8
#1.	Install Ansible from yum
yum -y install ansible
#2.	Create a simple inventory file with groups used by Ansible
cat << EOF > /etc/ansible/hosts
[masters]
master1.example.com

[nodes]
master1.example.com
infranode1.example.com
node1.example.com
node2.example.com
node3.example.com
EOF

cat /etc/ansible/hosts
#3.	Test the Ansible configuration
ansible nodes -m ping
#1.	On the bastion host, run the following for loop to ensure that NetworkManager is installed on the master and all nodes:
for node in   master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do \
	echo installing NetworkManager on $node ; \
	ssh $node "yum -y install NetworkManager"
done
#Install the following tools and utilities on the bastion host
yum -y install wget git net-tools bind-utils iptables-services bridge-utils
#Install bash-completion on both the bastion and master hosts
yum -y install bash-completion
ssh master1.example.com yum -y install bash-completion
echo "Run yum update on the master and all nodes: - long running process"
for node in master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do \
		echo Running yum update on $node - time taking process; \
		ssh $node "yum -y update " ; \
done
echo "Install step2.sh"



