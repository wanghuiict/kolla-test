#!/bin/bash

USERN="username"
PASSW="password"
HOST1="1.2.3.4"
PORT1="5000"
REGISTRY_DIR="/home/kolla-registry"

# override above settings
. ~/.kollatest_rc

type openssl docker update-ca-trust ss ||exit 1

eval $(systemctl show --property=SubState docker)
[ "$SubState" == "running" ] || { echo "docker service not runing"; exit 2; }


docker image ls |grep -w "^registry" &>/dev/null
[ $? -eq 0 ] || { echo "docker pull registry"; docker pull registry ||exit 1; }

mkdir -p registry/certs registry/auth
pushd registry

[[ -f ./certs/registry.key && -f ./certs/registry.crt ]] || {
    openssl req -newkey rsa:4096 -nodes -sha256 \
        -keyout ./certs/registry.key -x509 \
        -days 365 -out ./certs/registry.crt || exit 3
    cp ./certs/registry.crt /etc/pki/ca-trust/source/anchors/
    update-ca-trust extract;
}

[[ -f ./auth/htpasswd ]] || {
    docker run --entrypoint htpasswd registry -Bbn $USERN $PASSW > ./auth/htpasswd || exit 4;
}

ss -ltn |grep -w $PORT1
[[ $? -eq 0 ]] || {
    mkdir -p $REGISTRY_DIR
    docker run -d -p ${PORT1}:5000 --restart=always --name registry \
        -v $(pwd)/auth:/root/registry/auth \
        -e "REGISTRY_AUTH=htpasswd" \
        -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
        -e "REGISTRY_AUTH_HTPASSWD_PATH=/root/registry/auth/htpasswd" \
        -v $(pwd)/certs:/root/registry/certs \
        -e "REGISTRY_HTTP_TLS_CERTIFICATE=/root/registry/certs/registry.crt" \
        -e "REGISTRY_HTTP_TLS_KEY=/root/registry/certs/registry.key" \
        -v $REGISTRY_DIR:/var/lib/registry \
        registry || { echo "failed to run registry container"; exit 5; }
    systemctl restart docker;
}

popd

