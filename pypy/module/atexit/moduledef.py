from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """Allow programmer to define multiple exit functions to be
    executed upon normal program termination.

    Two public functions, register and unregister, are defined.
    """

    interpleveldefs = {
        }

    appleveldefs = {
        'register': 'app_atexit.register',
        'unregister': 'app_atexit.unregister',
        '_clear': 'app_atexit.clear',
        '_run_exitfuncs': 'app_atexit.run_exitfuncs',
        '_ncallbacks': 'app_atexit.ncallbacks',
        }

