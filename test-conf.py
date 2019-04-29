from oslo_config import cfg
from kolla.common import config as common_config
import sys

import pbr.version

version_info = pbr.version.VersionInfo('kolla')

print version_info.__dict__
print version_info.cached_version_string()

'''
test kolla conf options

e.g.:
# python test-conf.py --tag=rocky
'''

conf = cfg.ConfigOpts()
# read default settings
common_config.parse(conf, sys.argv[1:], prog='kolla-build')
print('tag is %s'%(conf.tag))

# call it to enable options.
conf()

for x in conf:
    print x

if False:
    print conf.__dict__
    print conf.items()

print '*'*79
for x in conf.iteritems():
    print('%s\n\t%s'%(x[0], x[1]))
    # print some <oslo_config.cfg.GroupAttr>
    if x[0] == 'ansible-user':
        for y in x[1]:
            print y

print '*'*79
print('tag is %s'%(conf.tag))
