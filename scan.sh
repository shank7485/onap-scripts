#!/bin/bash

# Example usage:
# ./scan.sh appc/ <circuit username> <circuit password> "ONAP"

BUILD=$1
USERNAME=$2
PASSWORD=$3
STREAM=$4
DIR=$5

if [ -z "$BUILD" ] || [ -z "$DIR" ] || [ -z "$USERNAME"  ] || [ -z "$PASSWORD" ] || [ -z "$STREAM" ] ; then
    echo "Need more arguements. Usage: ./scan.sh <--java||--python> <circuit username> <circuit password> <Covertiy Stream name> <Directory>"
else
    if [ $BUILD = "--java" ] ; then
    	cd $DIR

        # Source environment variables
        source /etc/profile.d/env.sh
        # Maven Build
        # mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
        # Configure Java compiler
        cov-configure --java
        # Coverity Build
        cov-build --dir cov mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
        # Coverity Analyse
        cov-analyze --dir cov --concurrency --security --rule --enable-constraint-fpp --enable-fnptr --enable-virtual
        # Coverity Commit
        cov-commit-defects --dir cov --host cov.jf.intel.com --user $USERNAME --password $PASSWORD --stream $STREAM
        echo "Scan results available at: https://cov.ostc.intel.com with stream name: "$STREAM
    elif [ $BUILD = "--python" ] ; then
	echo "python"
        echo "Scan results available at:  https://cov.ostc.intel.com with stream name: "$STREAM
    else
        echo "Unrecognized build "$BUILD
        echo "Please use: "java" or "python""
    fi
fi