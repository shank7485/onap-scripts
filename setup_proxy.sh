#!/bin/bash

function remove_docker {
    if [ -x "/usr/bin/docker" ]; then
        docker_ps=$(docker ps -a -q)
        if [[ "$docker_ps" ]]; then
          docker stop $(docker ps -a -q)
          docker rm $(docker ps -a -q)
        fi

        var=$(docker -v | cut -d' ' -f3)
        version=${var:0:-3}
        if [ "$version" != "1.12" ]; then
            echo "[INFO] Removing any other version of Docker other than 1.12."

            sudo apt-get remove docker-engine -y
            sudo apt-get autoremove --purge docker-engine -y

            sudo apt-get remove docker -y
            sudo apt-get purge docker -y

            sudo apt-get remove docker-ce -y
            sudo apt-get purge docker-ce -y

            sudo apt-get autoremove --purge

            sudo umount /var/lib/docker/aufs
            sudo rm -rf /var/lib/docker
        fi
    fi
}

function setup_docker {
    echo "[INFO] Installing Docker 1.12."
    curl https://releases.rancher.com/install-docker/1.12.sh | sh
    sudo usermod -aG docker $USER
}

function setup_chameleon_proxy {
    echo "[INFO] Configuring Proxy."
    wget https://raw.githubusercontent.com/crops/chameleonsocks/master/chameleonsocks.sh
    chmod 755 chameleonsocks.sh
    if [ "$socks_proxy" != "" ]; then
        socks=$(echo $socks_proxy | sed -e "s/^.*\///" | sed -e "s/:.*$//")
        PROXY=$socks ./chameleonsocks.sh --install

        unset http_proxy
        unset HTTP_PROXY
        unset https_proxy
        unset HTTPS_PROXY
        unset no_proxy
        unset NO_PROXY
        unset socks_proxy
        unset SOCKS_PROXY
        unset ftp_proxy
        unset FTP_PROXY

        sudo docker login -u docker -p docker nexus3.onap.org:10001
    else
        echo "Set socks_proxy env variable in root."
    fi
}

remove_docker
setup_docker
setup_chameleon_proxy