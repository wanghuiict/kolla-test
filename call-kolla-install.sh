#!/bin/bash

show_help_install() {
        echo -e "install TianNi Openstack.\nUsage:\n\t$myname [options]\nOptions:"
        echo -e "\t--help, -h              \tshow help."
        echo -e "\t--skip-bootstrap        \tskip kolla bootstrap."
        echo -e "\t--skip-pre              \tskip kolla prechecks."
        echo -e "\t--skip-deploy           \tskip kolla deploy."
        echo -e "\t--skip-post             \tskip kolla post-deploy."
        echo -e "\t--skip-all              \tskip kolla bootstrap, prechecks, deploy, post-deploy."
        echo -e "\t--skip-install-kolla    \tskip install kolla."
        echo -e "\t--genpwd <password.yml> \tcall kolla-genpwd."
}

cmdopts=$(getopt --longoptions skip-bootstrap,skip-pre,skip-deploy,skip-post,skip-all,skip-install-kolla,genpwd:,title:,help \
                     --options +ht: -- "$@")
if [ $? -ne 0 ] ; then
  echo "Terminating..." 1>&2
  exit 1
fi

# set positional parameters
eval set -- "$cmdopts"

skip_bootstrap=false
skip_pre=false
skip_deploy=false
skip_post=false
skip_install_kolla=false
myname=$0
pwdfile=

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
    --genpwd )
        pwdfile="$2"
        shift 2;;
    --skip-bootstrap )
        skip_bootstrap=true; shift ;;
    --skip-pre )
        skip_pre=true; shift ;;
    --skip-deploy )
        skip_deploy=true; shift ;;
    --skip-post )
        skip_post=true; shift ;;
    --skip-all )
        skip_bootstrap=true
        skip_pre=true
        skip_deploy=true
        skip_post=true
        shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

argstr1=
argstr2=$@

if $skip_install_kolla; then
    argstr1="--skip-install-kolla "
fi

if [ ! -z "$pwdfile" ]; then
    argstr1="$argstr1 --genpwd $pwdfile "
fi

. tn-openstack-common $argstr1

if ! $skip_bootstrap; then
    kolla-ansible -i $ETCKOLLA/$INVENTORY $argstr2 bootstrap-servers || exit 1
fi

if ! $skip_pre; then
    kolla-ansible -i $ETCKOLLA/$INVENTORY $argstr2 prechecks || exit 2
fi

if ! $skip_deploy; then
    kolla-ansible -i $ETCKOLLA/$INVENTORY $argstr2 deploy || exit 3
fi

if ! $skip_post; then
    kolla-ansible -i $ETCKOLLA/$INVENTORY $argstr2 post-deploy || exit 4
fi

