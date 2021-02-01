#!/bin/bash

if [ $# -eq 0 ];then
  echo "rebuild ports associate with nova instance."
  echo -e "Usage:"
  if [ "$(basename $0)" == "tnc-neutron-vif" ];then # from upper script called
      cmd0="$0 replace"
  else
      cmd0="$0"
  fi
  echo -e "\t${cmd0} <vmuuid>                   replace instance's vif"
  exit 0
fi

while getopts ":dv" opt; do
   case $opt in
        ? ) echo "error input"
            exit 1;;
   esac
done
shift $(($OPTIND - 1))

. functions

### VM instance
VMUUID=${1}
if [ -z $VMUUID ];then
    echo "ERROR: vmuuid not found" >&2
    exit 1
fi
echogreen "vmuuid: $VMUUID"
openstack server show $VMUUID || exit 1

PROJUUID=$(openstack server show -f value -c project_id $VMUUID)
[ -z "$PROJUUID" ] && exit 1

stop_vm() {
    local vmuuid=$1
    local a=
    local loop=30

    openstack server stop $vmuuid &>/dev/null
    while true; do
        a=$(openstack server show $vmuuid -f value -c status)
        if [ "$a" != "SHUTOFF" ];then
            ((loop--))
            if ((loop==0)); then
                return 1
            fi
            echo "VM status $a. wait 2 seconds"
            sleep 2
        else
            return 0
        fi
    done
}

### Neutron network
tmpn=$(mktemp /tmp/XXXXX)
[ -z "$tmpn" ] && exit 1

PORTINFO=${tmpn}_port
NETINFO=${tmpn}_net
FIPINFO=${tmpn}_fip
MYINFO=${tmpn}

_cleanup() {
  rm ${tmpn}*
}

trap '_cleanup' HUP INT TERM EXIT

get_myinfo() {
    local portid=
    local netid=
    local netid2=
    local subnets=
    local mac=
    local fixedip=
    local fid=
    local fip=
    local fixed2=
    local port=
    local ip_address=
    local floatingip=
    local floatingid=

    # XXX: port network:dhcp may contain 2 ip_address
    { openstack port list -c "ID" -c "MAC Address" -c "Fixed IP Addresses" -f value --project $PROJUUID; ret=$?; } > ${PORTINFO}
    [ $ret -eq 0 ] || return 1
    
    { openstack network list -c "ID" -c "Subnets" --project $PROJUUID -f value; ret=$?; } > ${NETINFO}
    [ $ret -eq 0 ] || return 1
    
    { openstack floating ip list -c "ID" -c "Floating IP Address" -c "Fixed IP Address" -c "Port" --project $PROJUUID -f value; ret=$?; } > ${FIPINFO}
    [ $ret -eq 0 ] || return 1
    
    echo -n "" > ${MYINFO}

    IFS=$'\n'; for y in $(< $PORTINFO); do
        unset IFS
        read portid mac fixedip <<< $y

        # e.g. ip_address='192.168.192.2', subnet_id='d30b3f1d-f0d3-4d4c-a212-c0696a276fc5' 
        eval ${fixedip}
        ip_address=$(echo $ip_address |tr -d ",")
        netid2=
        IFS=$'\n'; for x in $(< $NETINFO); do
            unset IFS
            read netid subnets <<< $x
            echo $subnets |grep $subnet_id &>/dev/null
            if [ $? -eq 0 ]; then
                netid2=$netid
                break
            fi
        done
        if [ -z "$netid2" ]; then
            echored "network uuid not found."
            return 1
        fi

        floatingip=
        floatingid=
        IFS=$'\n';for x in $(< $FIPINFO); do
            unset IFS
            read fid fip fixed2 port <<< $x 
            if [ "$portid" == "$port" ]; then
                floatingip=$fip
                floatingid=$fid
                break
            fi
        done
        echo "$netid2 $subnet_id $portid $ip_address $floatingip $floatingid" >> $MYINFO
    done
    return 0
}

delete_port() {
    local portid=$1
    local loop=30
    local n=
            
    echogreen "openstack port delete $portid"
    openstack port delete $portid
    [ $? -eq 0 ] || return 1

    while true; do
      n=$(openstack port list|grep $portid|wc -l)
      if [ $n -eq 0 ]; then
          return 0
      else
          ((loop--))
          if ((loop==0)); then
              return 1
          fi
          echo "port exist,wait 2 seconds"
          sleep 2
      fi
    done
}

disassociate_fip() {
    local fid=$1
    echogreen "openstack floating ip unset --port $fid"
    openstack floating ip unset --port $fid
}

associate_fip() {
    local fid=$1
    local port=$2
    echogreen "openstack floating ip set --port $port $fid"
    openstack floating ip set --port $port $fid
}

attach_port_instance() {
    local port=$1
    local vmuuid=$2
    local retry=3
    local ret=

    echogreen "nova interface-attach --port-id $port $vmuuid"
    while ((retry>0)); do
        nova interface-attach --port-id $port $vmuuid
        ret=$?
        if [ $ret -ne 0 ]; then
            ((retry--))
            sleep 5
        else
            break
        fi
    done
    return $ret
}

NEWPORT=
rebuild_port() {
    local portid=$1
    local subid=$2
    local netid=$3
    local fixedip=$4
    local i=0
    local x=
    local k=
    declare -a sg

    local ret=0
    for x in $(openstack port show ${portid} -f value -c security_group_ids; ret=$?; if [ $ret -ne 0 ]; then echo ret=$ret; fi);do
        if [ "${x:0:4}" == "ret=" ]; then
            eval $x
            return $ret
        fi
        sg[$i]=$(echo $x|tr -d ",")
        ((i++))
    done

    delete_port $portid || return 1

    set -o xtrace &>/dev/null
    NEWPORT=$(openstack port create -f value -c id \
        --network $netid \
        --fixed-ip subnet=$subid,ip-address=$fixedip \
        $(for k in ${sg[@]};do echo -n "--security-group $k ";done) \
        --project $PROJUUID "")
    ret=$?
    set +o xtrace
    return $ret
}

# XXX: overlapped fixed ip address
find_port_by_fixedip() {
    local fixedip=$1
    openstack port list -c "ID" -c "Fixed IP Addresses" -f value --project $PROJUUID |grep -w $fixedip |awk '{print $1}'
}

### Main
get_myinfo || exit 1
stop_vm $VMUUID || exit 1

declare -a vmips
i=0
for x in $(openstack server show $VMUUID -c addresses -f value); do
    # e.g. net_icttest_201804121702=192.168.2.10, 10.83.8.41; net_icttest_20180412153135=192.168.0.100, 192.168.0.101, 192.168.1.4, 10.83.8.35, 10.83.8.40
    ipaddr=$(echo $(echo $x|tr -d ',')|cut -d '=' -f 2)
    echogreen "get vm ipaddr [$ipaddr]"
    vmips[$i]=$ipaddr
    ((i++))
done

for x in ${vmips[@]}; do
    IFS=$'\n'; for y in $(< $MYINFO);do
        unset IFS
        read netid subid portid fixedip fip fid <<< $y
        if [ "$x" == "$fixedip" ]; then # XXX: ip may be overlapped, i.e. same ip in different subnets.
            echogreen "vmuuid: $VMUUID\nport: $portid\nfixed ip: $fixedip\nsubnet: $subid\nnetwork: $netid\nfloating ip: $fip"
            if [ ! -z "$fip" ]; then
                found=false
                for z in ${vmips[@]}; do
                    if [ "$fip" == "$z" ]; then
                        found=true
                        break
                    fi
                done
                if ! $found; then
                    echored "$fip not attached to vm $VMUUID, skip"
                    continue
                fi
                disassociate_fip $fid
            fi
            rebuild_port $portid $subid $netid $fixedip || break
            newport=$NEWPORT
            [ -z "$newport" ] && break
            attach_port_instance $newport $VMUUID
            if [ ! -z "$fip" ]; then
                associate_fip $fid $newport
            fi
            break
        fi
    done
done

