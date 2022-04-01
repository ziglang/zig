from rpython.jit.metainterp.resoperation import opname

for name in opname.values():
    name = name.lower()
    if not name.startswith('guard') and name != 'debug_merge_point':
        print '"%s"' % name,

