#!/bin/bash
# Create configuration files
mkdir -p /opt/config
echo "https://nexus.onap.org/content/sites/raw" > /opt/config/nexus_repo.txt
echo "nexus3.onap.org:10001" > /opt/config/nexus_docker_repo.txt
echo "docker" > /opt/config/nexus_username.txt
echo "docker" > /opt/config/nexus_password.txt
echo "1.1.0-SNAPSHOT" > /opt/config/artifacts_version.txt
echo "8.8.8.8" > /opt/config/dns_ip_addr.txt
echo "1.0-STAGING-latest" > /opt/config/docker_version.txt
echo "release-1.0.0" > /opt/config/gerrit_branch.txt
echo "openstack" > /opt/config/cloud_env.txt

# Download and run install script
curl -k https://nexus.onap.org/content/sites/raw/org.openecomp.demo/boot/1.1.0-SNAPSHOT/sdnc_install.sh -o /opt/sdnc_install.sh
cd /opt
chmod +x sdnc_install.sh
./sdnc_install.sh
