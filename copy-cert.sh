#!/bin/bash

#REGISTRY_DIR="/home/kolla-registry"

pushd $REGISTRY_DIR || exit 127

remote="$1"
[ -z "$remote" ] && { echo "please specify remote host"; exit 1; }

scp certs/registry.crt ${remote}:/etc/pki/ca-trust/source/anchors/ || { popd; exit 2; }
ssh $remote "update-ca-trust extract && systemctl restart docker" || { popd; exit 3; }

popd
