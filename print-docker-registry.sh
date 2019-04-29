#!/bin/bash

# output markdown document

echo -e "# Docker Registry\n\n## repositories\nhttps://$HOST1:$PORT1/v2/"

repolist=($(echo "
catal=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/_catalog)
for repo in catal['repositories']:
    print repo
" |python -))

for x in ${repolist[@]}; do
    echo "
taglist=$(curl -s -k https://$USERN:$PASSW@$HOST1:$PORT1/v2/$x/tags/list)
print('### %s'%taglist['name'])
for t in taglist['tags']:
  print('%s\n'%(t))
" |python -
done

