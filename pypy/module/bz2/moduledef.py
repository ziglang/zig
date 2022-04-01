from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    # The private part of the bz2 module.

    applevel_name = '_bz2'

    interpleveldefs = {
        'BZ2Compressor': 'interp_bz2.W_BZ2Compressor',
        'BZ2Decompressor': 'interp_bz2.W_BZ2Decompressor',
    }

    appleveldefs = {
    }
