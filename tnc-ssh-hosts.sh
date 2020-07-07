#!/bin/bash

. functions

myname=$0

print_help() {
  local hostfileexample="\t#comment line\n\t10.10.150.8 tncloud01\n\t10.10.150.8 tncloud01-ssd\n\t10.10.150.9 tncloud02\n\t10.10.150.10 tncloud03"
  echo -e "Build SSH trust among many hosts, using current user."
  echo -e "Usage:"
  echo -e "    $myname build [-f <ssh host file>] [password]"
  echo -e "    $myname test [-f <ssh host file>] [-r redofile]"
  echo -e "    $myname exec [-f <ssh host file>] cmd"
  echo -e "Hosts:\n  filename : default is sshosts, or specify by -f .\n  content  : ipaddr and one hostname on each line.\n    e.g.\n${hostfileexample}"
}

ssh_keygen_rsa() {
    cat > ta$$.sh << eof1
#!/usr/bin/expect
set timeout 600
spawn ssh-keygen -t rsa
expect {
 "file in which to save the key*): " { send "\r"; }
}
expect {
 "Overwrite (y/n)\\?" { send "n\r"; }
 "(empty for no passphrase): " { send "\r"; }
}
expect {
 "(empty for no passphrase): " { send "\r"; }
 "same passphrase again: " { send "\r"; }
 eof {
  lassign [wait] pid spawnid os_error_flag value
  if {\$os_error_flag == 0} {
      exit \$value
  } else {
      exit 255
  }
 }
}
expect {
 "same passphrase again: " { send "\r"; }
 eof {
  lassign [wait] pid spawnid os_error_flag value
  if {\$os_error_flag == 0} {
      exit \$value
  } else {
      exit 255
  }
 }
}
expect eof {
  lassign [wait] pid spawnid os_error_flag value
  if {\$os_error_flag == 0} {
      exit \$value
  } else {
      exit 255
  }
}
eof1
    expect -f ta$$.sh
    local ret=$?
    rm ta$$.sh
    return $ret
}

# Parameters: user home pass remoteHost
ssh_copy_id_rsa() {
    cat > tb$$.sh << eof1
#!/usr/bin/expect
set timeout 600
set arg1 [lindex \$argv 0]
set presskey 0
#log_user 0
spawn ssh-copy-id -i ${2}/.ssh/id_rsa.pub ${1}@\$arg1
expect {
 "yes/no*" { send "yes\r"; exp_continue }
  "Permission denied, please try again." {
      set presskey 1
      exp_continue
  }
  "password:" {
      if { [set presskey] == 0 } {
        send "${3}\r"
        exp_continue
      } else {
          interact eof
      }
  }
  eof {
    lassign [wait] pid spawnid os_error_flag value
    if {\$os_error_flag == 0} {
        exit \$value
    } else {
        exit 255
   }
 }
}
puts "interact eof reach here"
lassign [wait] pid spawnid os_error_flag value
if {\$os_error_flag == 0} {
    exit \$value
} else {
    exit 255
}
eof1
    expect -f tb$$.sh ${4}
    local ret=$?
    rm tb$$.sh
    return $ret
}

_do_scp_rsa_key_once() {
    local x=$1
    expect -f tc$$.sh $x &
    wait $!
    local ret=$?
    if [ $ret -eq 0 ]; then
        echogreen ${x} scp copy rsa SUCCESS
    else
        echored ${x} scp copy rsa FAILED
    fi
    return $ret
}

# Parameters: user home pass hostarr hostself
scp_rsa_keys() {
    cat > tc$$.sh << eof1
#!/usr/bin/expect
set timeout 600
set arg1 [lindex \$argv 0]
set presskey 0
spawn scp -r ${2}/.ssh ${1}@\$arg1:${2}
expect {
 "yes/no" { send "yes\r"; exp_continue }
  "Permission denied, please try again." {
      set presskey 1;
      exp_continue
  }
  "password:" {
      if { [set presskey] == 0 } {
        send "${3}\r"; exp_continue
      } else {
          interact eof
      }
  }
  eof {
    lassign [wait] pid spawnid os_error_flag value
    if {\$os_error_flag == 0} {
        exit \$value
    } else {
        exit 255
    }
 }
}
puts "interact eof reach here"
lassign [wait] pid spawnid os_error_flag value
if {\$os_error_flag == 0} {
    exit \$value
} else {
    exit 255
}
eof1
    local arr=${!4}
    for x in ${arr[@]};do
        if [ "$x" != "$5" ]; then
            _do_scp_rsa_key_once $x #&
            local ret=$?
            if [ $ret -ne 0 ]; then # return if any error
                rm tc$$.sh
                return $ret
            fi
        fi
    done
    #wait
    rm tc$$.sh
    return $ret
}

_do_scp_host_once() {
    local x=$1
    expect -f td$$.sh $x $2 $3 &
    wait $!
    local ret=$?
    if [ $ret -eq 0 ]; then
        echogreen ${x} scp $2 $3 SUCCESS
    else
        echored ${x} scp $2 $3 FAILED
    fi
    return $ret
}

# Parameters: user home pass hostarr hostself
scp_hosts() {
  if [ ! -f td$$.sh ]; then
    cat > td$$.sh << eof1
#!/usr/bin/expect
set timeout 600
set arg1 [lindex \$argv 0]
set arg2 [lindex \$argv 1]
set arg3 [lindex \$argv 2]
set presskey 0
spawn scp \$arg2 ${1}@\$arg1:\$arg3
expect {
 "yes/no" { send "yes\r"; exp_continue }
  "Permission denied, please try again." {
      set presskey 1;
      exp_continue
  }
  "password:" {
      if { [set presskey] == 0 } {
        send "${3}\r"; exp_continue
      } else {
          interact eof
      }
  }
  eof {
    lassign [wait] pid spawnid os_error_flag value
    if {\$os_error_flag == 0} {
        exit \$value
    } else {
        exit 255
    }
 }
}
puts "interact eof reach here"
lassign [wait] pid spawnid os_error_flag value
if {\$os_error_flag == 0} {
    exit \$value
} else {
    exit 255
}
eof1
fi
    local arr=${!4}
    local ret=
    for x in ${arr[@]};do
        if [ "$x" != "$5" ]; then
            _do_scp_host_once $x ${2}/.ssh/known_hosts ${2}/.ssh/ #&
            ret=$?
            if [ $ret -ne 0 ]; then # return if any error
                rm td$$.sh
                return $ret
            fi
        fi
    done
    #wait
    for x in ${arr[@]};do
        if [ "$x" != "$5" ]; then
            _do_scp_host_once $x /etc/hosts /etc/ #&
            ret=$?
            if [ $ret -ne 0 ]; then # return if any error
                rm td$$.sh
                return $ret
            fi
        fi
    done
    #wait
    rm td$$.sh
    for x in ${arr[@]};do
        ssh -n $x "hostnamectl set-hostname $x"
        ret=$?
        if [ $ret -ne 0 ]; then
            echored FAILED: hostnamectl set-hostname $x
            return $ret
        fi
    done
}

do_build() {
    local pass1=
    local user1=$(whoami)
    local homedir=$HOME
    local ipself=
    local hostself=
    local hostarr=()

    local optind=$OPTIND
    OPTIND=0
    while getopts ":f:" opt; do
       case $opt in
            f ) sshosts=$OPTARG
                ;;
            ? ) echo "error input"
                exit 1;;
       esac
    done
    shift $(($OPTIND - 1))
    OPTIND=$optind

    if [ $# -eq 0 ]; then
        echored "no password input" >&2
        read -s -p "ssh login password:" pass1
        [ -n "$pass1" ] || exit 1
    else
        pass1=$1
    fi

    if [ ! -f $sshosts ];then
        echored "ssh hostfile $sshosts not found" >&2
        exit 1
    fi

    local i=0
    while read ip host; do
        # comment line
        if [ "${ip:0:1}" == "#" ]; then
            continue
        fi
        if [ "$host" == ""  ]; then
            continue
        fi
        echo $ip $host
        if [ "$user1" == "root" ]; then
            sed -i '/^'${ip}'/d' /etc/hosts
            echo "$ip $host" >> /etc/hosts
        fi
        if [ -z $ipself ]; then
            ip -f inet addr show |grep -w "$ip" &>/dev/null
            if [ $? -eq 0 ]; then
                ipself=$ip
                hostself=$host
            fi
        fi
        hostarr[$i]=$host
        ((i++))
    done < $sshosts

    if [ -z $ipself ]; then
        echored "Please set localip in $sshosts" >&2
        exit 1
    fi

    ssh_keygen_rsa
    ssh_copy_id_rsa $user1 $homedir $pass1 $hostself ||exit 1
    scp_rsa_keys $user1 $homedir $pass1 hostarr[@] $hostself ||exit 1
    scp_hosts $user1 $homedir $pass1 hostarr[@] $hostself ||exit 1

    echogreen "\nCompleted Successfully!"
    echo -e "Please run following command to test:\n$(basename $0) test"
    return 0
}

do_test() {
    local redolast=
    local opt1=
    local optind=$OPTIND
    OPTIND=0
    while getopts ":f:r:" opt1; do
       case $opt1 in
            f ) sshosts=$OPTARG
                ;;
            r ) redolast=$OPTARG
                ;;
            ? ) echo "error input"
                exit 1;;
       esac
    done
    shift $(($OPTIND - 1))
    OPTIND=$optind

    local user1=$(whoami)
    local homedir=$HOME
    local results="/tmp/result.$$"
    local redo="/tmp/redo.$$"
    echo -e "\n\nnow test ssh trusts among all nodes.\n"
    echo -n "" > ${results}

    if [ -f "$redolast" ]; then
        while read a b;do
            echo "$a -----------> $b"
            ssh -n -o "BatchMode yes" $a "sh -c \"ssh -n -o \\\"BatchMode yes\\\" $b \\\"exit 0\\\";if [ \\\$? -eq 0 ];then echo -n -e \\\".\\\"; else echo -e \\\"\nfailed $a -> $b\\\"; fi\" \&;" |tee -a $results &
        done < $redolast
    else
        if [ ! -f $sshosts ];then
            echo "ssh hostfile $sshosts not found"
            exit 1
        fi
        local hostarr=()
        local i=0
        while read ip host; do
            if [ "${ip:0:1}" == "#" ]; then
                continue
            fi
            if [ "$host" == ""  ]; then
                continue
            fi
            echo $ip $host
            hostarr[$i]=$host
            ((i++))
        done < $sshosts

        for x in ${hostarr[@]};do
            ssh -n -o "BatchMode yes" $x "for y in ${hostarr[@]};do sh -c \"ssh -n -o \\\"BatchMode yes\\\" \$y \\\"exit 0\\\";if [ \\\$? -eq 0 ];then echo -n -e \\\".\\\"; else echo -e \\\"\nfailed $x -> \$y\\\"; fi\" \&;done" |tee -a $results &
        done
    fi
    wait
    echo -e "\nTest Result:"
    cat ${results}|grep "^failed"|sort
    
    cat ${results}|grep "^failed" &>/dev/null
    if [ $? -eq 0 ];then
        echo -n "" > ${redo}
        cat ${results} |grep "^failed "|while read dumb host1 dumb host2;do
            echo "$host1 $host2" >> ${redo}
        done
        echo -e "\nrun following command to test failed hosts again:\n$0 test -r ${redo}"
        retval="1"
    else
        echo "All is ok!"
        retval="0"
    fi
    rm -f ${results}
    exit ${retval}
}

do_exec() {
    local host1=
    local optind=$OPTIND
    OPTIND=0
    while getopts ":f:h:" opt; do
       case $opt in
            f ) sshosts=$OPTARG
                shift 2;;
            h ) host1=$OPTARG
                shift 2;;
            ? ) echo "error input"
                exit 1;;
       esac
    done
    shift $(($OPTIND - 1))
    OPTIND=$optind

    if [ $# -eq 0 ]; then
        echo "no shell command input"
        exit 1
    fi
    if [ ! -f $sshosts ];then
        echo "ssh hostfile $sshosts not found"
        exit 1
    fi
    local hostarr=()
    local i=0
    while read ip host; do
        if [ "${ip:0:1}" == "#" ]; then
            continue
        fi
        if [ "$host" == ""  ]; then
            continue
        fi
        hostarr[$i]=$host
        ((i++))
    done < $sshosts

    local t="/tmp/tnc-ssh.$$"
    echo "$*;r=\$?;rm $t;return \$r" > $t
    for x in ${hostarr[@]};do
        scp $t $x:$t &
    done
    wait
    for x in ${hostarr[@]};do
        echogreen "[$x]# $*"
        ssh -n -o "BatchMode yes" $x "source $t"
    done
}

while getopts ":t:" opt; do
   case $opt in
        t ) myname=$OPTARG
            ;;
        ? ) echo "error input"
            exit 1;;
   esac
done
shift $(($OPTIND - 1))

action=$1
[ -z "$action" ] && action="-h"
shift

while true; do
  case "$action" in
    -h | --help )
        print_help
        exit 0;;
    build )
        sshosts="sshosts"
        do_build $*
        exit $?
        ;;
    test )
        sshosts="sshosts"
        do_test $*
        exit
        ;;
    exec )
        sshosts="sshosts"
        echo do_exec $*
        do_exec $*
        exit
        ;;
    -- ) shift; break ;;
    * ) printf "error input\n"; exit ;;
  esac
done
