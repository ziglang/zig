from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    appleveldefs = {}

    interpleveldefs = {
        'Random'          : 'interp_random.W_Random',
    }
