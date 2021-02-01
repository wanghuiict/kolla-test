#!/bin/bash

detect_qemu_proc() {
    local host=$1
    local vmuuid=$2

    ssh -o "BatchMode yes" -n $host "hostname"
    if [ $? -ne 0 ]; then
        echo "ssh error" >&1
        exit -1
    fi
    ssh -o "BatchMode yes" -n $host "ps -ef |grep \"qemu-\" |grep [${vmuuid:0:1}]${vmuuid:1}"
    return $?
}

wait_vm_stop() {
    local host=$1
    local vmuuid=$2
    local force=$3
    local retry=100

    while true; do
      detect_qemu_proc $host $vmuuid
      if [ $? -eq 0 ];then
        echo "vm $vmuuid is running on $host"
        if [ "${force}" == "y" ]; then
          nova stop $vmuuid
        else
          echo "please stop instance $vmuuid" >&1
          exit 3
        fi
      else
        echo "$vmuuid qemu process not found on ${host}. instance shutoff."
        break
      fi
      if [ $retry -gt 0 ];then
        sleep 6
      else
        echo -e "timeout.\nexit" >&1
        exit 4
      fi
      ((retry--))
    done
    return 0
}

wait_vm_start() {
    local host=$1
    local vmuuid=$2
    local retry=100

    while true; do
      detect_qemu_proc $host $vmuuid
      if [ $? -eq 0 ];then
        echo "vm $vmuuid is running on $host"
        return 0
      fi
      if [ $retry -gt 0 ];then
        sleep 6
      else
        echo -e "timeout.\nexit" >&1
        exit 4
      fi
      ((retry--))
    done
    return 0
}

get_nova_conn() {
    local oldifs=$IFS
    local i=0
    local a=
    local str1=$(crudini --get /etc/nova/nova.conf database connection)
    # e.g. mysql+pymysql://nova:be247cdd33174a4b@10.10.144.6/nova
    str1=${str1/*\/\//}
    IFS=$':@/'
    for a in $str1;do
     case $i in
       0 ) #echo user $a
           NOVAUSER=$a
         ;;
       1 ) #echo password $a
           NOVAPASS=$a
         ;;
       2 ) #echo mysql server $a
           NOVADBADDR=$a
         ;;
       3 ) #echo mysql database $a
           NOVADBNAME=$a
         ;;
     esac 
     ((i++))
    done 
    IFS=$oldifs

    [[ -z "$NOVAUSER" || -z "$NOVADBADDR" || -z "$NOVADBNAME" ]] && { echo "check nova.conf"; exit -1; }
}

get_vm_host() {
  mysql -u $NOVAUSER  -p$NOVAPASS -h $NOVADBADDR << eof2
use $NOVADBNAME;
set @aid="${1}";
select display_name,host,vm_state,power_state,uuid from instances
WHERE 
  uuid = @aid and deleted = '0';
eof2
}

set_vm_host() {
 mysql -u $NOVAUSER  -p$NOVAPASS -h $NOVADBADDR << eof
use $NOVADBNAME;
set @aid="${1}";
set @hostn="${2}";

UPDATE instances SET
  host = @hostn, node = @hostn 
WHERE 
  uuid = @aid and deleted = '0';
commit;
exit
eof
}

if [ $# -eq 0 ];then
  echo move a VM instance to another Nova compute node.
  echo -n -e "Usage:\n\t$0 [-f] uuid|name <newnode>\n\t$0 -l node\n\t$0 -L\n"
  echo -e "Options:"
  echo -e "    -l\t\tlist vms on node."
  echo -e "    -L\t\tlist nova services"
  echo -e "    -f\t\tforced to stop and move vm"
  echo -e "Parameters:"
  echo -e "    uuid|name\tVM instance uuid or name"
  echo -e "    newnode  \ttarget compute node"
  echo -e "Example:"
  echo -e "\t$0 -f \"inst-1\" tncloud02"
  echo -e "Note:"
  echo -e "\t/var/lib/nova/instances must be shared between nodes."
  echo -e "\tbuild SSH trust between nodes."
  echo -e "\tconfirm vm has been shut down."
  echo -e "\tonly root can run $0."
  echo -e "\trun $0 on controller node."
  echo -e "\nThis program built for TianNi Cloud."
  exit
fi

forcemv="n"
onlylist="n"
listnode=""
listservice="n"

optind=$OPTIND
OPTIND=0
while getopts ":fl:L" opt; do
   case $opt in
        f ) forcemv="y";;
        l ) onlylist="y"
            listnode=$OPTARG
            ;;
        L ) listservice="y";;
        ? ) echo "error input"
            exit 1;;
   esac
done
shift $(($OPTIND - 1))
OPTIND=$optind

type openstack nova crudini || { exit -1; }

if [ "${listservice}" == "y" ];then
  openstack compute service list
  exit 0
fi

if [ "${onlylist}" == "y" ]; then
  nova list --host=${listnode}
  exit 0
fi

type mysql &>/dev/null
if [ $? -ne 0 ] ;then
  echo Please install mysql client. run: yum install -y mysql
  exit -1
fi

get_nova_conn
echo -e "NOVAUSER: $NOVAUSER\nNOVADBADDR: $NOVADBADDR\nNOVADBNAME: $NOVADBNAME"

vmuuid=$(nova list --all-tenants|grep -w " $1 "|head -n 1|awk '{print $2}')
if [ "$vmuuid" == "" ];then
 echo vm $1 not found!
 exit
fi
echo "vm uuid: $vmuuid"
openstack server show $vmuuid

vmhost=$(get_vm_host $vmuuid|tail -n 1|awk '{print $2}')
echo "$vmuuid is on $vmhost"

if [ $# -eq 1 ]; then
  get_vm_host $vmuuid
  openstack compute service list --service nova-compute
  echo -e "\nPlease select a compute node above, re-run $0 with newnode."
  exit 1
fi

if [ "${vmhost}" == "$2" ];then
  echo -e "dst-host = src-host.\nexit"
  exit 1
fi
dest="$2"
 
echo -e "import sys
li=$(openstack compute service list --service nova-compute -f json)
for x in li:
    if x['Host'] == \"${dest}\":
        if x['Status'] == 'enabled' and x['State'] == 'up':
            sys.exit(0)
        else:
            sys.exit(3)
sys.exit(2)" |python -
if [ $? -ne 0 ]; then
  echo $2 is invalid or disabled or status error.
  exit 2
fi

# try - detect vm status
wait_vm_stop $vmhost $vmuuid $forcemv

# XXX: obsolete
# try - ceph rbd test ,for cinder type 'type_rbd_vm' and volume "volumes"
grep "protocol=\"rbd\"" /var/lib/nova/instances/${vmuuid}/libvirt.xml > /dev/null 2>&1
if [ $? -eq 0 ]; then
  IFS=$'\n' # make newlines the only separator
  for line in `cinder list|grep $vmuuid|grep type_rbd_vm`;do 
    echo $line
    vol="volume-`echo $line|awk '{print $2}'`"
    echo $vol
    rbdheader="rbd_header.`rbd -p volumes info $vol|grep block_name_prefix|awk '{print $2}'|cut -d '.' -f 2`"
    echo $rbdheader
    res=`rados -p volumes listwatchers $rbdheader`
    if [ "${res:0:7}" == "watcher" ];then 
      echo volume has $res
      echo exit
      exit
    fi
  done
  unset IFS
fi

# TODO: for NFS, avoid the bad node to access nfs server. edit /etc/exports and reload ???

echo "set ${vmuuid} on ${dest}"
set_vm_host ${vmuuid} "${dest}"

nova reset-state --active $vmuuid
nova reboot --hard $vmuuid
echo "waiting for vm $vmuuid running on ${dest}"
wait_vm_start $dest $vmuuid
echo "waiting for vm $vmuuid stopped on ${dest}"
wait_vm_stop $dest $vmuuid y

echo "replace $vmuuid VIF"
replacevif.sh $vmuuid
echo "vm $vmuuid moved completed."
openstack server list --host "$dest"

echo "now reboot $vmuuid"
nova reboot --hard $vmuuid
echo "waiting for vm $vmuuid running on ${dest}"
wait_vm_start $dest $vmuuid
echo "Done."

