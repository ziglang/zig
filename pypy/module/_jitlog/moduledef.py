from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib.rvmprof import VMProfPlatformUnsupported

class Module(MixedModule):
    """ JitLog the new logging facility """
    appleveldefs = {
    }

    interpleveldefs = {
        'enable': 'interp_jitlog.enable',
        'disable': 'interp_jitlog.disable',
        'JitlogError': 'space.fromcache(interp_jitlog.Cache).w_JitlogError',
    }
