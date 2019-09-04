import docker
from io import BytesIO

docker_kwargs = docker.utils.kwargs_from_env()
print docker_kwargs
dc = docker.APIClient(version='auto', **docker_kwargs)
print dc.version()

dockerfile = '''
FROM centos:7
CMD ["/bin/sh"]
'''

f = BytesIO(dockerfile.encode('utf-8'))

for line in dc.build(fileobj=f, rm=True, tag='centos:mytest'):
    print line

print '*'*79

for x in dc.history('centos'):
    print x

print('run for test: %s'%("docker run -it --rm centos:mytest"))
