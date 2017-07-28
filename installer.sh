#!/bin/bash

COVERITY_VERSION=cov-analysis-linux64-8.5.0

function install_java8 {
    sudo add-apt-repository ppa:webupd8team/java -y
    sudo apt-get update -y
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
    sudo apt-get install oracle-java8-installer -y
}

function install_maven3 {
    pushd /opt/
    sudo wget http://mirrors.koehn.com/apache/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.tar.gz
    sudo tar -xvzf apache-maven-3.5.0-bin.tar.gz
    sudo mv apache-maven-3.5.0 maven
    sudo touch /etc/profile.d/env.sh
    export PATH="/opt/maven/bin:$PATH"
    mvn -V > /dev/null 2>&1
    popd
}

function install_coverity_manual {
    wget http://cov.jf.intel.com/downloads/$COVERITY_VERSION.sh
    wget http://cov.jf.intel.com/downloads/license.zip
    sudo apt-get update -y
    sudo apt-get install unzip -y
    unzip license.zip
    chmod +x $COVERITY_VERSION.sh
    ./$COVERITY_VERSION.sh
    cp license.dat $COVERITY_VERSION/bin
    export PATH="'$(pwd)'/$COVERITY_VERSION/bin:$PATH"
}

function install_coverity {
    wget http://cov.jf.intel.com/downloads/$COVERITY_VERSION.tar.gz
    wget http://cov.jf.intel.com/downloads/license.zip
    sudo apt-get update -y
    sudo apt-get install unzip -y
    unzip license.zip
    tar xf $COVERITY_VERSION.tar.gz
    cp license.dat $COVERITY_VERSION/bin
    export PATH="'$(pwd)'/$COVERITY_VERSION/bin:$PATH"
}

cd ~/.m2/
wget https://wiki.onap.org/download/attachments/1015867/settings.xml
# Add proxy
git clone https://git.onap.org/vid
cd vid
#cov-build --dir cov --no-command --fs-capture-search ./
#cov-configure --java
cov-build --dir cov mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
cov-analyze --dir cov --concurrency --security --rule --enable-constraint-fpp --enable-fnptr --enable-virtual
cov-commit-defects --dir cov --host cov.jf.intel.com --user <circuit username> --password <circuit password> --stream "ONAP"
