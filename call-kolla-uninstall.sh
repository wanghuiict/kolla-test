#!/bin/bash

show_help_uninstall() {
        echo -e "uninstall TianNi Openstack.\nUsage:\n\t$myname destroy\nOptions:"
        echo -e "Parameters:"
        echo -e "\tdestroy                 \tuninstall openstack deployment"
}

cmdopts=$(getopt --longoptions title:,help \
                     --options +ht: -- "$@")
if [ $? -ne 0 ] ; then
  echo "Terminating..." 1>&2
  exit 1
fi

# set positional parameters
eval set -- "$cmdopts"

myname=$0

while true; do
  case "$1" in
    -h | --help )
        show_help_uninstall
        exit ;;
   -t | --title )
        myname="$2"
        shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

. tn-openstack-common

if [ "$1" == "destroy" ]; then
    # destroy --yes-i-really-really-mean-it
    kolla-ansible -i $ETCKOLLA/$INVENTORY $@
    exit
fi

