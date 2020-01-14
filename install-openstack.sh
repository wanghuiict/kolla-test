#!/bin/bash

TIANNI_SRC=/dev/sr0
TIANNI_DIR=/media/cdrom

WORKDIR="/home/kolla"
VENVDIR="usr"
KOLLADIR="${WORKDIR}/${VENVDIR}/share/kolla-ansible"
ETCKOLLA="/etc/kolla"
INVENTORY="multinode"

has_tianni() {
    [[ -z "$TIANNI_SRC" || -z "$TIANNI_DIR" ]] || mount $TIANNI_SRC $TIANNI_DIR &>/dev/null
    cat ${TIANNI_DIR}/VERSION |grep "^TianNi" &>/dev/null
}

install_kolla() {
    local upgrade=(pip setuptools)
    local install=(docker ansible kolla-ansible tox)

    has_tianni
    if [ $? -eq 0 ]; then
        pip install --upgrade --no-index --find-links ${TIANNI_DIR}/pip/ ${upgrade[@]}
        pip install --no-index --find-links ${TIANNI_DIR}/pip/ ${install[@]}
    else
        pip install --upgrade ${upgrade[@]}
        pip install ${install[@]}
    fi

    mkdir -p /etc/ansible
    cat > /etc/ansible/ansible.cfg << eof1
[defaults]
pipelining=True
forks=100
deprecation_warnings=False
eof1
}

config_kolla() {
    mkdir -p $ETCKOLLA
    cp -r ${KOLLADIR}/etc_examples/kolla/* $ETCKOLLA
    cp ${KOLLADIR}/ansible/inventory/* $ETCKOLLA
    [ -f ${ETCKOLLA}/passwords.yml ] || kolla-genpwd
}

ansible_ping_hosts() {
    ansible -i $ETCKOLLA/$INVENTORY all -m ping
}

type pip || { echo "pip not found" >&1; exit 1; }
type easy_install || { echo "please install python setuptools" >&1; exit 1; }

set -o xtrace
mkdir -p $WORKDIR
# copy settings 
cp globals.yml $INVENTORY passwords.yml $WORKDIR
cd $WORKDIR
virtualenv $VENVDIR || exit -1
source ${VENVDIR}/bin/activate
set +o xtrace
# install kolla in venv
install_kolla || exit -2

config_kolla || exit -3

cp globals.yml $INVENTORY passwords.yml $ETCKOLLA

#kolla-ansible -i $ETCKOLLA/$INVENTORY destroy --yes-i-really-really-mean-it
#exit

ansible_ping_hosts || exit -4

ansible-playbook --tags=mariadb --list-tasks --list-tags -i /etc/kolla/multinode -e @/etc/kolla/globals.yml -e @/etc/kolla/passwords.yml -e CONFIG_DIR=/etc/kolla  -e kolla_action=deploy /home/kolla/usr/share/kolla-ansible/ansible/site.yml
exit

kolla-ansible -i $ETCKOLLA/$INVENTORY bootstrap-servers && \
kolla-ansible -i $ETCKOLLA/$INVENTORY prechecks && \
kolla-ansible -i $ETCKOLLA/$INVENTORY deploy && \
kolla-ansible -i $ETCKOLLA/$INVENTORY post-deploy

