from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib.rvmprof import VMProfPlatformUnsupported
from rpython.translator.platform import CompilationError


class Module(MixedModule):
    """
    VMProf for PyPy: a statistical profiler
    """
    appleveldefs = {
    }

    interpleveldefs = {
        'enable': 'interp_vmprof.enable',
        'disable': 'interp_vmprof.disable',
        'is_enabled': 'interp_vmprof.is_enabled',
        'get_profile_path': 'interp_vmprof.get_profile_path',
        'stop_sampling': 'interp_vmprof.stop_sampling',
        'start_sampling': 'interp_vmprof.start_sampling',

        'VMProfError': 'space.fromcache(interp_vmprof.Cache).w_VMProfError',
    }


# Force the __extend__ hacks and method replacements to occur
# early.  Without this, for example, 'PyCode._init_ready' was
# already found by the annotator to be the original empty
# method, and the annotator doesn't notice that interp_vmprof.py
# (loaded later) replaces this method.
try:
    import pypy.module._vmprof.interp_vmprof
except VMProfPlatformUnsupported as e:
    pass
except CompilationError as e:
    import sys
    if sys.platform == 'win32':
        pass
    else:
        raise
