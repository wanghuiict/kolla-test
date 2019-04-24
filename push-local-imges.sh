#!/bin/bash

# note: docker login at first

REGISTRY="10.10.153.116:5001"

IFS=$'\n'; for x in $(docker image ls |tail -n +2 |grep -v "^$REGISTRY");do
    unset IFS
    read repo tag dumb <<< $(echo $x)

    docker tag $repo:$tag $REGISTRY/$repo:$tag
    docker push $REGISTRY/$repo:$tag
    docker rmi $REGISTRY/$repo:$tag
    
done
