import pkg_resources

named_objects = {}
for ep in pkg_resources.iter_entry_points(group='oslo.config.opts'):
    named_objects.update({ep.name: ep.load()})
for x in  named_objects['kolla']():
    print '\n%s'%x[0]
    for y in x[1]:
            print '\t%18s: %s\n\t%s  %s\n\t%s  default: %s'%(y.name, y.help, ' '*18, y.type, ' '*18, y.default)
