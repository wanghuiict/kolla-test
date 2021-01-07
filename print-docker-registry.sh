#!/bin/bash

# output markdown or NAME:TAG

output_markdown() {
    last=
    
    echo -e "\n# Docker Registry\n\n## repositories\nhttps://$HOST1:$PORT1/v2/"
    
    while true; do
            if [ ! -z "$last" ]; then
                lstr="?last=$last"
            else
                lstr=
            fi
            
            repolist=($(echo "
catal=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/_catalog$lstr)
for repo in catal['repositories']:
    print repo
" |python -))
            
            if [ ${#repolist[@]} -eq 0 ]; then
                break
            fi
            
            for x in ${repolist[@]}; do
                echo "
taglist=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/$x/tags/list)
print('### %s'%taglist['name'])
for t in taglist['tags']:
  print('%s\n'%(t))
" |python -
            done
            
            last=$(echo ${x//\//%2F})
            ##echo $last
    done
}

output_value() {
    last=
    
    echo -e "Docker Registry https://$HOST1:$PORT1/v2/"

    while true; do
            if [ ! -z "$last" ]; then
                lstr="?last=$last"
            else
                lstr=
            fi
            
            repolist=($(echo "
catal=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/_catalog$lstr)
for repo in catal['repositories']:
    print repo
" |python -))
            
            if [ ${#repolist[@]} -eq 0 ]; then
                break
            fi
            
            for x in ${repolist[@]}; do
                echo "
taglist=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/$x/tags/list)
for t in taglist['tags']:
  print('%s:%s'%(taglist['name'], t))
" |python -
            done
            
            last=$(echo ${x//\//%2F})
            ##echo $last
    done
}

if [ "$1" == "value" ]; then
  format="value"
  output_value
else
  format="markdown"
  output_markdown
fi

