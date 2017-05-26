mkdir -p /opt/config
echo "https://nexus.onap.org/content/sites/raw_" > /opt/config/nexus_repo.txt
echo "nexus3.onap.org:10001" > /opt/config/nexus_docker_repo.txt
echo "docker" > /opt/config/nexus_username.txt
echo "docker" > /opt/config/nexus_password.txt
echo "1.1.0-SNAPSHOT" > /opt/config/artifacts_version.txt
echo "8.8.8.8" > /opt/config/dns_ip_addr.txt
echo "1.0-STAGING-latest" > /opt/config/docker_version.txt
echo "release-1.0.0" > /opt/config/gerrit_branch.txt
echo "openstack" > /opt/config/cloud_env.txt

# Download and run install script
#curl -k https://nexus.onap.org/content/sites/raw/org.openecomp.demo/boot/1.1.0-SNAPSHOT/sdnc_install.sh -o /opt/sdnc_install.sh
#cd /opt
#chmod +x sdnc_install.sh
# ./sdnc_install.sh

# sdnc_install.sh
##########################

# Read configuration files
NEXUS_REPO=$(cat /opt/config/nexus_repo.txt)
ARTIFACTS_VERSION=$(cat /opt/config/artifacts_version.txt)
DNS_IP_ADDR=$(cat /opt/config/dns_ip_addr.txt)
CLOUD_ENV=$(cat /opt/config/cloud_env.txt)
GERRIT_BRANCH=$(cat /opt/config/gerrit_branch.txt)
MTU=$(/sbin/ifconfig | grep MTU | sed 's/.*MTU://' | sed 's/ .*//' | sort -n | head -1)

# Add host name to /etc/host to avoid warnings in openstack images
#if [[ $CLOUD_ENV != "rackspace" ]]
#then
#	echo 127.0.0.1 $(hostname) >> /etc/hosts
#
#	# Allow remote login as root
#	mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bk
#	cp /home/ubuntu/.ssh/authorized_keys /root/.ssh
#fi

# Set private IP in /etc/network/interfaces manually in the presence of public interface
# Some VM images don't add the private interface automatically, we have to do it during the component installation
#if [[ $CLOUD_ENV == "openstack_nofloat" ]]
#then
#	LOCAL_IP=$(cat /opt/config/local_ip_addr.txt)
#	CIDR=$(cat /opt/config/oam_network_cidr.txt)
#	BITMASK=$(echo $CIDR | cut -d"/" -f2)
#
#	# Compute the netmask based on the network cidr
#	if [[ $BITMASK == "8" ]]
#	then
#		NETMASK=255.0.0.0
#	elif [[ $BITMASK == "16" ]]
#	then
#		NETMASK=255.255.0.0
#	elif [[ $BITMASK == "24" ]]
#	then
#		NETMASK=255.255.255.0
#	fi

#	echo "auto eth1" >> /etc/network/interfaces
#	echo "iface eth1 inet static" >> /etc/network/interfaces
#	echo "    address $LOCAL_IP" >> /etc/network/interfaces
#	echo "    netmask $NETMASK" >> /etc/network/interfaces
#	echo "    mtu $MTU" >> /etc/network/interfaces
#	ifup eth1
#fi

# Download dependencies
add-apt-repository -y ppa:openjdk-r/ppa
apt-get update
apt-get install -y apt-transport-https ca-certificates wget openjdk-8-jdk git ntp ntpdate

# Download scripts from Nexus
#curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACTS_VERSION/sdnc_vm_init.sh -o /opt/sdnc_vm_init.sh
#curl -k $NEXUS_REPO/org.openecomp.demo/boot/$ARTIFACTS_VERSION/sdnc_serv.sh -o /opt/sdnc_serv.sh
#chmod +x /opt/sdnc_vm_init.sh
#chmod +x /opt/sdnc_serv.sh
#mv /opt/sdnc_serv.sh /etc/init.d
#update-rc.d sdnc_serv.sh defaults

# Download and install docker-engine and docker-compose
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y --allow-unauthenticated docker-engine

mkdir /opt/docker
curl -L https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /opt/docker/docker-compose
chmod +x /opt/docker/docker-compose

cp /lib/systemd/system/docker.service /etc/systemd/system
sed -i "/ExecStart/s/$/ --mtu=$MTU/g" /etc/systemd/system/docker.service
service docker restart

# DNS IP address configuration
echo "nameserver "$DNS_IP_ADDR >> /etc/resolvconf/resolv.conf.d/head
resolvconf -u

# Clone Gerrit repository and run docker containers
cd /opt
git clone -b $GERRIT_BRANCH --single-branch http://gerrit.onap.org/r/sdnc/oam.git sdnc
# ./sdnc_vm_init.sh

# sdnc_vm_init.sh
##################################

NEXUS_USERNAME=$(cat /opt/config/nexus_username.txt)
NEXUS_PASSWD=$(cat /opt/config/nexus_password.txt)
export NEXUS_DOCKER_REPO=$(cat /opt/config/nexus_docker_repo.txt)
DOCKER_IMAGE_VERSION=$(cat /opt/config/docker_version.txt)
export MTU=$(/sbin/ifconfig | grep MTU | sed 's/.*MTU://' | sed 's/ .*//' | sort -n | head -1)

cd /opt/sdnc
git pull

cd /opt/sdnc/installation/src/main/yaml
docker login -u $NEXUS_USERNAME -p $NEXUS_PASSWD $NEXUS_DOCKER_REPO

docker pull $NEXUS_DOCKER_REPO/openecomp/sdnc-image:$DOCKER_IMAGE_VERSION
docker tag $NEXUS_DOCKER_REPO/openecomp/sdnc-image:$DOCKER_IMAGE_VERSION openecomp/sdnc-image:latest

docker pull $NEXUS_DOCKER_REPO/openecomp/admportal-sdnc-image:$DOCKER_IMAGE_VERSION
docker tag $NEXUS_DOCKER_REPO/openecomp/admportal-sdnc-image:$DOCKER_IMAGE_VERSION openecomp/admportal-sdnc-image:latest

docker pull $NEXUS_DOCKER_REPO/openecomp/dgbuilder-sdnc-image:$DOCKER_IMAGE_VERSION
docker tag $NEXUS_DOCKER_REPO/openecomp/dgbuilder-sdnc-image:$DOCKER_IMAGE_VERSION openecomp/dgbuilder-sdnc-image:latest

/opt/docker/docker-compose up -d

