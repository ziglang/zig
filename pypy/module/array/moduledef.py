from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    interpleveldefs = {
        'array': 'interp_array.W_ArrayBase',
        'ArrayType': 'interp_array.W_ArrayBase',
        '_array_reconstructor': 'reconstructor.array_reconstructor',
    }

    appleveldefs = {
    }
