#!/bin/bash


COVERITY_VERSION=cov-analysis-linux64-8.5.0
# Download Coverity tar and license
wget http://cov.jf.intel.com/downloads/$COVERITY_VERSION.tar.gz
wget http://cov.jf.intel.com/downloads/license.zip
sudo apt-get update -y
sudo apt-get install unzip -y

# Extract
tar xf $COVERITY_VERSION.tar.gz
unzip license.zip
cp license.dat $COVERITY_VERSION/bin
cd $COVERITY_VERSION
OUT='export PATH="/opt/maven/bin:'$(pwd)'/bin:$PATH"'
sudo touch /etc/profile.d/env.sh
echo $OUT | sudo tee /etc/profile.d/env.sh

# Download Java 8
sudo add-apt-repository ppa:webupd8team/java -y
sudo apt-get update -y
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install oracle-java8-installer -y

# Download Maven and install
cd /opt/
sudo wget http://mirrors.koehn.com/apache/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.tar.gz
sudo tar -xvzf apache-maven-3.5.0-bin.tar.gz
sudo mv apache-maven-3.5.0 maven
source /etc/profile.d/env.sh
mvn -V > /dev/null 2>&1

# Download settings.xml
cd ~/.m2/
wget https://wiki.onap.org/download/attachments/1015867/settings.xml
echo "Installed Coverity and Maven"
echo "Add proxy settings in ~/.m2/settings.xml if behind a proxy"