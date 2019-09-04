#!/bin/bash

REGISTRY="$HOST1:$PORT1"

docker login -p $PASSW -u $USERN $REGISTRY || exit 1

repotag="$1"

IFS=$'\n'; for x in $(docker images $repotag |tail -n +2 |grep -v "^$REGISTRY");do
    unset IFS
    read repo tag dumb <<< $(echo $x)

    docker tag $repo:$tag $REGISTRY/$repo:$tag
    docker push $REGISTRY/$repo:$tag
    docker rmi $REGISTRY/$repo:$tag
    
done
