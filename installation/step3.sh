#! /bin/sh
#12.	Run the following for loop to configure Docker storage on the other nodes, enable Docker, and restart the node
scp root@master1.example.com:/etc/sysconfig/docker-storage-setup ./
for node in infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do
		echo Configuring Docker Storage and rebooting $node
		scp docker-storage-setup ${node}:/etc/sysconfig/docker-storage-setup
		ssh $node "
		docker-storage-setup ;
		systemctl enable docker
		systemctl start docker"
done
#1.	Verify that the Docker service has started on all nodes:
echo "Sleeping for a minute"
sleep 60
for node in   master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do
		echo Checking docker status on $node
		ssh $node "systemctl status docker | grep Active" 
done
REGISTRY="registry.access.redhat.com";PTH="openshift3"
OSE_VERSION=$(yum info atomic-openshift | grep Version | awk '{print $3}')
#5.	Now on the bastion host, pull down the Docker images to node1 and node2 in the primary region with the following command(it is a time taking process):
for node in  node1.example.com \
			 node2.example.com \
             node3.example.com; \
do
ssh $node "
docker pull $REGISTRY/$PTH/ose-deployer:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ose-sti-builder:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ose-pod:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ose-keepalived-ipfailover:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ruby-20-rhel7 ; \
docker pull $REGISTRY/$PTH/mysql-55-rhel7 ; \
docker pull openshift/hello-openshift:v1.2.1 ;
"
done
#6.	On bastion, pull only the basic images and the registry and router images to the infranode1 host
node=infranode1.example.com
ssh $node "
docker pull $REGISTRY/$PTH/ose-haproxy-router:v$OSE_VERSION  ; \
docker pull $REGISTRY/$PTH/ose-deployer:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ose-pod:v$OSE_VERSION ; \
docker pull $REGISTRY/$PTH/ose-docker-registry:v$OSE_VERSION ;
"
#7.	Examine the information in the Docker pool on the node1 and node2 hosts
ssh node1.example.com docker info
ssh node2.example.com docker info
ssh node3.example.com docker info
ssh node1.example.com "lvs"
ssh node2.example.com "lvs"
ssh node3.example.com "lvs"
#install the OpenShift utility package
yum -y install atomic-openshift-utils
#•	Write the inventory file
export OSE_VERSION=3.6

cat << EOF > /etc/ansible/hosts
[OSEv3:children]
masters
nodes
nfs

[OSEv3:vars]
ansible_user=root

#Disable pre-installation checks, NOT RECOMMENDED FOR PRODUCTIVE ENVIRONMENTS
openshift_disable_check=memory_availability,disk_availability

# enable ntp on masters to ensure proper failover
openshift_clock_enabled=true

deployment_type=openshift-enterprise
openshift_release=v$OSE_VERSION

openshift_master_cluster_method=native
openshift_master_cluster_hostname=master1.example.com
openshift_master_cluster_public_hostname=master1-${GUID}.oslab.opentlc.com

os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'

openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]
#openshift_master_htpasswd_users={'andrew': '\$apr1\$cHkRDw5u\$eU/ENgeCdo/ADmHF7SZhP/', 'marina': '\$apr1\$cHkRDw5u\$eU/ENgeCdo/ADmHF7SZhP/'

# default project node selector
osm_default_node_selector='region=primary'
openshift_hosted_router_selector='region=infra'
openshift_hosted_router_replicas=1
#openshift_hosted_router_certificate={"certfile": "/path/to/router.crt", "keyfile": "/path/to/router.key", "cafile": "/path/to/router-ca.crt"}
openshift_hosted_registry_selector='region=infra'
openshift_hosted_registry_replicas=1

openshift_master_default_subdomain=cloudapps-${GUID}.oslab.opentlc.com

#openshift_use_dnsmasq=False
#openshift_node_dnsmasq_additional_config_file=/home/bob/ose-dnsmasq.conf

openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_host=bastion.example.com
openshift_hosted_registry_storage_nfs_directory=/exports
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=5Gi

[nfs]
bastion.example.com

[masters]
master1.example.com openshift_hostname=master1.example.com openshift_public_hostname=master1-${GUID}.oslab.opentlc.com

[nodes]
master1.example.com openshift_hostname=master1.example.com openshift_public_hostname=master1-${GUID}.oslab.opentlc.com openshift_node_labels="{'region': 'infra'}"
infranode1.example.com openshift_hostname=infranode1.example.com openshift_public_hostname=infranode1-${GUID}.oslab.opentlc.com openshift_node_labels="{'region': 'infra', 'zone': 'infranodes'}"
node1.example.com openshift_hostname=node1.example.com openshift_public_hostname=node1-${GUID}.oslab.opentlc.com openshift_node_labels="{'region': 'primary', 'zone': 'east'}"
node2.example.com openshift_hostname=node2.example.com openshift_public_hostname=node2-${GUID}.oslab.opentlc.com openshift_node_labels="{'region': 'primary', 'zone': 'west'}"
node3.example.com openshift_hostname=node3.example.com openshift_public_hostname=node3-${GUID}.oslab.opentlc.com openshift_node_labels="{'region': 'primary', 'zone': 'north'}"
EOF
# run the installation using the following playbook
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml


