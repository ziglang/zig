from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """ Opcode support module. """

    appleveldefs = {
    }

    interpleveldefs = {
        'stack_effect' : 'interp_opcode.stack_effect',
    }
