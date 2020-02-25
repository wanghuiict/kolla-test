#!/bin/bash

show_help_install() {
        echo -e "test kolla.\nUsage:\n\t$myname [options] <action> [ansible-playbook options...]"
        echo -e "Options:"
        echo -e "\t--help, -h              \tshow help."
        echo -e "\t--skip-install-kolla    \tskip install kolla."
        echo -e "Parameters:"
        echo -e "\taction                  \tkolla_acion: bootstrap-servers,prechecks,deploy,post-deploy"
        echo -e "Example:"
        echo -e "\t$myname --skip-install-kolla deploy"
        echo -e "\t$myname --skip-install-kolla deploy --tags=mariadb"
        echo -e "\t$myname --skip-install-kolla deploy --tags=mariadb --list-tasks --list-tags"
}

cmdopts=$(getopt --longoptions skip-install-kolla,title:,help \
                     --options +ht: -- "$@")
if [ $? -ne 0 ] ; then
  echo "Terminating..." 1>&2
  exit 1
fi

# set positional parameters
eval set -- "$cmdopts"

skip_install_kolla=false
myname=$0

while true; do
  case "$1" in
    -h | --help )
        show_help_install
        exit ;;
    -t | --title )
        myname="$2"
        shift 2;;
    --skip-install-kolla )
        skip_install_kolla=true
        shift ;;
    -- )
        shift
        break ;;
    * )
        echo "error input" 1>&2
        break ;;
  esac
done

action=$1
shift
if [ -z "$action" ]; then
    echo "no kolla_action found" >&1
    exit 1
fi
if [[ "$action" != "bootstrap-servers" && "$action" != "prechecks" && "$action" != "deploy" && "$action" != "post-deploy" ]]; then
    echo "error action" >&1
    exit 1
fi

if $skip_install_kolla; then
    . tn-openstack-common --skip-install-kolla
else
    . tn-openstack-common
fi

confd=$ETCKOLLA
kollad=$KOLLADIR

echo "ansible-playbook -i $confd/multinode -e @$confd/globals.yml -e @$confd/passwords.yml -e CONFIG_DIR=$confd -e kolla_action=$action $@ $kollad/ansible/site.yml"
ansible-playbook -i $confd/multinode -e @$confd/globals.yml -e @$confd/passwords.yml -e CONFIG_DIR=$confd -e kolla_action=$action $@ $kollad/ansible/site.yml

