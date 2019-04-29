#!/bin/bash

USERN="username"
PASSW="password"
HOST1="1.2.3.4"
PORT1="5000"

. ~/.kollatest_rc

REGISTRY="$HOST1:$PORT1"

docker login -p $PASSW -u $USERN $REGISTRY

IFS=$'\n'; for x in $(docker image ls |tail -n +2 |grep -v "^$REGISTRY");do
    unset IFS
    read repo tag dumb <<< $(echo $x)

    docker tag $repo:$tag $REGISTRY/$repo:$tag
    docker push $REGISTRY/$repo:$tag
    docker rmi $REGISTRY/$repo:$tag
    
done
