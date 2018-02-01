#! /bin/sh
#•	Install the docker package on the master and all nodes:
for node in master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do \
		echo Installing docker on $node ; \
		ssh $node "yum -y install docker" ;
done
#1.	Stop the Docker daemon and delete any files from /var/lib/docker
for node in master1.example.com \
	infranode1.example.com \
	node1.example.com \
	node2.example.com \
	node3.example.com; \
	do
		echo Cleaning up Docker on $node ; \
		ssh $node "systemctl stop docker ; rm -rf /var/lib/docker/*" ;
done
