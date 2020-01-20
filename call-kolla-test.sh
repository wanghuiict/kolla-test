#!/bin/bash

show_help_install() {
        echo -e "test kolla.\nUsage:\n\t$myname [options]\nOptions:"
        echo -e "\t--help, -h              \tshow help."
        echo -e "\t--skip-install-kolla    \tskip install kolla."
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

if $skip_install_kolla; then
    . tn-openstack-common --skip-install-kolla
else
    . tn-openstack-common
fi

confd=$ETCKOLLA
kollad=$KOLLADIR
ansible-playbook --tags=mariadb --list-tasks --list-tags -i $confd/multinode -e @$confd/globals.yml -e @$confd/passwords.yml -e CONFIG_DIR=$confd  -e kolla_action=deploy $kollad/ansible/site.yml
