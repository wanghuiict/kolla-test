#!/bin/bash

show_help_mariadb_recovery() {
        echo -e "mariadb recovery on TianNi Openstack.\nUsage:\n\t$Usage\nOptions:"
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

Usage="$0 [options...|--] [-- kolla-ansible_options]"
skip_install_kolla=false

while true; do
  case "$1" in
    -h | --help )
        show_help_mariadb_recovery
        exit ;;
   --skip-install-kolla )
        skip_install_kolla=true
        shift ;;
   -t | --title )
        Usage="$2"
        shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if $skip_install_kolla;then
    . tn-openstack-common --skip-install-kolla
else
    . tn-openstack-common
fi

kolla-ansible -i $ETCKOLLA/$INVENTORY mariadb_recovery $@
