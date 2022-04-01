from pypy.interpreter.mixedmodule import MixedModule 

class Module(MixedModule):
    applevel_name = '_crypt'

    interpleveldefs = {
        'crypt'    : 'interp_crypt.crypt',
    }

    appleveldefs = {
    }
