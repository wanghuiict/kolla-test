#!/bin/bash

show_help_install() {
        echo -e "install TianNi Openstack.\nUsage:\n\t$myname [options]\nOptions:"
        echo -e "\t--help, -h              \tshow help."
        echo -e "\t--skip-bootstrap        \tskip kolla bootstrap."
        echo -e "\t--skip-pre              \tskip kolla prechecks."
        echo -e "\t--skip-deploy           \tskip kolla deploy."
        echo -e "\t--skip-post             \tskip kolla post-deploy."
        echo -e "\t--skip-extra            \tskip tasks in extras.yml"
        echo -e "\t--skip-all              \tskip kolla bootstrap, prechecks, deploy, post-deploy and extra"
        echo -e "\t--skip-install-kolla    \tskip install kolla."
        echo -e "\t--genpwd                \tcall kolla-genpwd."
        echo -e "\t--confdir, -d <dir>     \tdirectory of scratch passwords.yml, globals.yml and"
        echo -e "\t                        \tINVENTORY(e.g. multinode)"
        echo -e "Example:"
        echo -e "\t$myname --skip-install-kolla --confdir work/149_28 --skip-extra"
}

cmdopts=$(getopt --longoptions skip-bootstrap,skip-pre,skip-deploy,skip-post,skip-extra,skip-all,skip-install-kolla,genpwd,title:,confdir:,help \
                     --options +ht:d: -- "$@")
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
skip_extra=false
skip_install_kolla=false
myname=$0
gen_pwd=false
confdir=.

while true; do
  case "$1" in
    -h | --help )
        show_help_install
        exit ;;
   -t | --title )
        myname="$2"
        shift 2;;
   -d | --confdir )
        confdir="$2"
        shift 2;;
    --skip-install-kolla )
        skip_install_kolla=true
        shift ;;
    --genpwd )
        gen_pwd=true
        shift ;;
    --skip-bootstrap )
        skip_bootstrap=true; shift ;;
    --skip-pre )
        skip_pre=true; shift ;;
    --skip-deploy )
        skip_deploy=true; shift ;;
    --skip-post )
        skip_post=true; shift ;;
    --skip-extra )
        skip_extra=true; shift ;;
    --skip-all )
        skip_bootstrap=true
        skip_pre=true
        skip_deploy=true
        skip_post=true
        skip_extra=true
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

if $gen_pwd; then
    argstr1="$argstr1 --genpwd "
fi

. tn-openstack-common $argstr1 --confdir $confdir

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

if ! $skip_extra; then
    echo -e "\nansible-playbook -i $ETCKOLLA/$INVENTORY $argstr2 extras.yml"
    ansible-playbook -i $ETCKOLLA/$INVENTORY $argstr2 extras.yml || exit 5
fi
