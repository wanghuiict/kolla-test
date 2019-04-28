import docker
from io import BytesIO

docker_kwargs = docker.utils.kwargs_from_env()
print docker_kwargs
dc = docker.APIClient(version='auto', **docker_kwargs)
print dc.version()

dockerfile = '''
FROM busybox:latest
CMD ["/bin/sh"]
'''

f = BytesIO(dockerfile.encode('utf-8'))

for line in dc.build(fileobj=f, rm=True, tag='busybox:latest'):
    print line

print '*'*79

for x in dc.history('busybox'):
    print x

print('run for test: %s'%("docker run -it --rm busybox"))
