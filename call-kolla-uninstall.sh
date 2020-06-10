#!/bin/bash

show_help_uninstall() {
        echo -e "uninstall TianNi Openstack.\nUsage:\n\t$Usage\nOptions:"
        echo -e "\t--skip-install-kolla    \tskip install kolla."
        echo -e "Parameters:"
        echo -e "\tdestroy                 \tuninstall openstack deployment"
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
        show_help_uninstall
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

kolla-ansible -i $ETCKOLLA/$INVENTORY destroy $@

#if [ "$1" == "destroy" ]; then
#    # destroy --yes-i-really-really-mean-it
#    shift
#    kolla-ansible -i $ETCKOLLA/$INVENTORY destroy $@
#else
#    echo "error input" 1>&2
#    exit -2
#fi

