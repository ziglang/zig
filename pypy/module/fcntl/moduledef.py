from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib.rarithmetic import intmask

class Module(MixedModule):
    interpleveldefs = {
        'fcntl': 'interp_fcntl.fcntl',
        'flock': 'interp_fcntl.flock',
        'lockf': 'interp_fcntl.lockf',
        'ioctl': 'interp_fcntl.ioctl'
    }

    appleveldefs = {
        '__doc__': 'app_fcntl.__doc__'
    }

    def buildloaders(cls):
        from pypy.module.fcntl import interp_fcntl
        for constant, value in interp_fcntl.constants.iteritems():
            value = intmask(value)
            Module.interpleveldefs[constant] = "space.wrap(%r)" % value
        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)
