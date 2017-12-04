#!/bin/bash

set -e

export NIC=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
export IP_ADDRESS=$(ifconfig $NIC | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2)

export RANCHER_URL=http://$IP_ADDRESS:8880
export RANCHER_VERSION=v0.6.5

function spinner {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function is_package_installed {
    if [[ -z "$@" ]]; then
        return 1
    fi
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            dpkg -s "$@" > /dev/null
        ;;
        rhel|centos|fedora)
        ;;
    esac
}

function remove_docker {
    if is_package_installed docker; then
        echo "[INFO] Removing any older version of Docker."
        docker stop $(docker ps -a -q)
        docker rm $(docker ps -a -q)

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
}

function setup_docker1.12 {
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

        login=$(sudo docker login -u docker -p docker nexus3.onap.org:10001)

        if [ "$login" == "Login Succeeded" ]; then
            install_rancher
            init_kubernetes
            install_helm
            install_onap
        else
            echo "Cannot reach Nexus Docker repo. Check network/proxy."
        fi
    else
        echo "Set socks_proxy env variable in root."
    fi
}

function install_rancher {
    echo "[INFO] Starting Rancher container."
    docker run -d --restart=unless-stopped -p 8880:8080 rancher/server
    echo "[INFO] Waiting for Rancher container to come up."
    sleep 5m
    spinner $!
    while true; do
        if curl --fail $RANCHER_URL; then
        break
        fi
    done
}

function init_kubernetes {
    echo "[INFO] Starting Kubernetes deployment."

    wget https://github.com/rancher/cli/releases/download/$RANCHER_VERSION/rancher-linux-amd64-$RANCHER_VERSION.tar.gz
    tar -xvzf rancher-linux-amd64-$RANCHER_VERSION.tar.gz
    rm -rf rancher-linux-amd64-$RANCHER_VERSION.tar.gz

    pushd rancher-$RANCHER_VERSION
    export RANCHER_ENVIRONMENT_ID=$(./rancher env create -t kubernetes onap_on_kubernetes)
    popd

    echo "[INFO] Waiting for Kubernetes to complete deployment. Takes 7+ minutes."
    $(install_host)
    install_kubectl
    sleep 7m
    spinner $!
    kubectl cluster-info
}

function install_helm {
    echo "[INFO] Installing Kubernetes Helm."
    wget http://storage.googleapis.com/kubernetes-helm/helm-v2.3.0-linux-amd64.tar.gz
    tar -zxvf helm-v2.3.0-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin/helm
    rm -rf helm-v2.3.0-linux-amd64.tar.gz
    rm -rf linux-amd64
    helm help
}

function install_onap {
    echo "[INFO] Installing ONAP deployment on Kubernetes."
    git clone http://gerrit.onap.org/r/oom
    pushd oom/kubernetes/oneclick
    source setenv.bash
    popd
    pushd oom/kubernetes/config
    cp onap-parameters-sample.yaml onap-parameters.yaml
    ./createConfig.sh -n onap
    popd
    echo "[INFO] Waiting for Config Pod to come up. Takes 5+ minutes"
    sleep 7m
    spinner $!
    pushd oom/kubernetes/oneclick
    ./createAll.bash
    echo "[INFO] Install ONAP all-in-one or individual components as required."
}

function install_kubectl {
    echo "[INFO] Installing kubectl CLI."
    rm -rf ~/.kube
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    mkdir ~/.kube
    pushd ~/.kube
    $(generate_kubectl_config)
    popd
}

function init_oom {
    echo "[INFO] ONAP on Kubernetes workflow: Rancher -> Kubernetes -> Kubectl -> ONAP"
    remove_docker
    setup_docker1.12
    setup_chameleon_proxy
}

function install_host {
    #echo "[INFO] Starting Kubernetes Host Instantiation."
    value=$(curl -X POST $RANCHER_URL/v1/projects/$RANCHER_ENVIRONMENT_ID/registrationtokens)
    curl -X GET $RANCHER_URL/v1/projects/$RANCHER_ENVIRONMENT_ID/registrationtokens?state=active | jq -r '.data[0].command'
}

function print {
#    Follow steps as show in https://wiki.onap.org/display/DW/ONAP+on+Kubernetesin (ONAP on Kubernetes) wiki to
#    install Kubernetes and deploy ONAP components on it.
#    After following the steps in the Wiki which includes running OOM, check if all pods are running
#    kubectl get pods --all-namespaces
#
#    # Reflecting changes on to ONAP on Kubernetes cluster
#
#    # Workflow: Edit code -> Make Changes to Docker build (If required) -> Build Docker image -> Update Kubernetes Deployment to pick up updated Docker image which contains the changed source code
#    # Make changes to component code base
#    # Edit the Docker image building for that component to make sure the source code which goes into the Docker container is from local changes and
#    # not nexus. This is necessary since some components clone source code directly from nexus and not from local. This needs to be changed so
#    # that the source gets picked up from local.
#    # Build the docker file.
#    # Check if docker image is built
#    docker images | grep <component name>
#
#    # Copy the docker image name
#    # Edit the kubernetes deployment file for that component and update the image name to the one as seen in the above step
#    kubectl edit deployment vfc-nslcm --namespace=<component name>
#
#    # Delete the specific pod of that component so that when kubernetes restarts it, it picks up the changed image
#    kubectl get pods --all-namespaces -o=wide
#    kubectl delete pod <Pod name> --namespace=<component name>
#
#    # Once the pod start running again, check the image used in the pod.
#    kubectl describe pod <New Pod name> --namespace=<Component name>
#
#    # Check logs to see if its working properly
#    kubectl logs <new Pod name> --namespace=<Component name> | less
#
#    # Edit values.yml with updated docker image in oom/kubernetes/<component> for persistence
    echo ""
}

function generate_kubectl_config {
#    curl -X -d '{"accountId":$RANCHER_ENVIRONMENT_ID, "name":"ONAP on Kubernetes", "description":"ONAP on Kubernetes", "publicValue":"string", "secretValue":"password"}' \
#                $RANCHER_URL/v1/projects/$RANCHER_ENVIRONMENT_ID/apikeys | jq -r '.data.'
    code=`python << END
import requests, os, base64

RANCHER_URL = str(os.environ['RANCHER_URL'])
RANCHER_ENVIRONMENT_ID = str(os.environ['RANCHER_ENVIRONMENT_ID'])

data = requests.post(RANCHER_URL + '/v1/projects/' + RANCHER_ENVIRONMENT_ID + '/apikeys',
                     {"accountId": RANCHER_ENVIRONMENT_ID,
                      "description": "ONAP on Kubernetes",
                      "name": "ONAP on Kubernetes",
                      "publicValue": "string",
                      "secretValue": "password"})
json_dct = data.json()

access_key = json_dct['publicValue']
secret_key = json_dct['secretValue']

auth_header = 'Basic ' + base64.b64encode(access_key + ':' + secret_key)
token = "\"" + str(base64.b64encode(auth_header)) + "\""

dct = \
"""
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    insecure-skip-tls-verify: true
    server: "{}/r/projects/{}/kubernetes:6443"
  name: "onap_on_kubernetes"
contexts:
- context:
    cluster: "onap_on_kubernetes"
    user: "onap_on_kubernetes"
  name: "onap_on_kubernetes"
current-context: "onap_on_kubernetes"
users:
- name: "onap_on_kubernetes"
  user:
    token: {}
""".format(RANCHER_URL, RANCHER_ENVIRONMENT_ID, token)

with open("config", "w") as file:
    file.write(dct)
END`

echo $code
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
else
  if [ "$socks_proxy" != "" ]; then
    init_oom
  else
    echo "Set socks_proxy env variable in Root user."
    exit
  fi
fi
