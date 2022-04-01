from pypy.interpreter.mixedmodule import MixedModule 

class Module(MixedModule):
    """Built-in functions, exceptions, and other objects."""

    appleveldefs = {
    }

    interpleveldefs = {
        'cell_new'     : 'maker.cell_new',
        'code_new'     : 'maker.code_new',
        'func_new'     : 'maker.func_new',
        'module_new'   : 'maker.module_new',
        'method_new'   : 'maker.method_new',
        'builtin_method_new'   : 'maker.builtin_method_new',
        'dictiter_surrogate_new' : 'maker.dictiter_surrogate_new',
        'frame_new'    : 'maker.frame_new',
        'traceback_new' : 'maker.traceback_new',
        'generator_new' : 'maker.generator_new',
        'coroutine_new' : 'maker.coroutine_new',
        'longrangeiter_new': 'maker.longrangeiter_new',
        'intrangeiter_new': 'maker.intrangeiter_new',
        'builtin_code': 'maker.builtin_code',
        'builtin_function' : 'maker.builtin_function',
    }
