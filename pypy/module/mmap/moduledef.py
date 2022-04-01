from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    interpleveldefs = {
        'PAGESIZE': 'space.wrap(interp_mmap.PAGESIZE)',
        'ALLOCATIONGRANULARITY': 'space.wrap(interp_mmap.ALLOCATIONGRANULARITY)',
        'ACCESS_READ' : 'space.wrap(interp_mmap.ACCESS_READ)',
        'ACCESS_DEFAULT' : 'space.wrap(interp_mmap.ACCESS_DEFAULT)',
        'ACCESS_WRITE': 'space.wrap(interp_mmap.ACCESS_WRITE)',
        'ACCESS_COPY' : 'space.wrap(interp_mmap.ACCESS_COPY)',
        'mmap': 'interp_mmap.W_MMap',
        'error': 'space.w_OSError',
    }

    appleveldefs = {
    }

    def buildloaders(cls):
        from rpython.rlib import rmmap
        for constant, value in rmmap.constants.iteritems():
            if isinstance(value, (int, long)):
                Module.interpleveldefs[constant] = "space.wrap(%r)" % value
        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)
