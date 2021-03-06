# test opensatck kolla

test kolla on CentOS 7.x

## install-openstack.sh

deploy opentack 

## update private registry taglist

```
# ./kollatest print > registry.md
# git add registry.md && git commit -m "update regisrty.md"
# git push origin master
```

## kollatest

a tool for creating/pushing/printing docker registry

```
# ./kollatest 
create/push/print docker registry.
Usage:
        ./kollatest [options...] create|push|print|cp-cert [PARAMETERS...]

Examples:
    create docker registry (must be run on the registry host)
        # ./kollatest [-u username] [-p password] [-h host] [-P port] [-d registry_directory] create

    push local docker imges to registry host
        # ./kollatest [-u username] [-p password] [-h host] [-P port] push [[REPOSITORY[:TAG]]]

    print repositories w/ tags in docker registry
        # ./kollatest [-u username] [-p password] [-h host] [-P port] print
    copy certificate to remote host (must be run on the registry host after 'create')
        # ./kollatest [-d registry_directory] cp-cert <remote>

Options:
    -h host                  docker registry hostname or ip address
    -P port                  docker registry service listen port
    -u username              docker registry login username
    -p password              docker registry password (WARNING: plain text!!!)
    -d registry_directory    docker registry root directory

FILE:
    ~/.kollatest_rc

  e.g.
        USERN="testuser"
        PASSW="password"
        HOST1="10.10.153.116"
        PORT1="5001"
        REGISTRY_DIR="/home/kolla-registry"
```

## patch openstack example (deprecated)

```
ansible-playbook -v -i multinode patch-openstack.yml 
```

## apply keystone update

```
ansible-playbook -i multinode apply-updates.yml 
```
