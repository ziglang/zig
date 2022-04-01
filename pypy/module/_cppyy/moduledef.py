from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    "This module bridges the cppyy frontend with its backend, through PyPy.\n\
    See http://cppyy.readthedocs.io/en/latest for full details."

    interpleveldefs = {
        '_resolve_name'          : 'interp_cppyy.resolve_name',
        '_scope_byname'          : 'interp_cppyy.scope_byname',
        '_is_static_data'        : 'interp_cppyy.is_static_data',
        '_is_template'           : 'interp_cppyy.is_template',
        '_std_string_name'       : 'interp_cppyy.std_string_name',
        '_set_class_generator'   : 'interp_cppyy.set_class_generator',
        '_set_function_generator': 'interp_cppyy.set_function_generator',
        '_register_class'        : 'interp_cppyy.register_class',
        '_get_nullptr'           : 'interp_cppyy.get_nullptr',
        'CPPInstance'            : 'interp_cppyy.W_CPPInstance',
        'addressof'              : 'interp_cppyy.addressof',
        '_bind_object'           : 'interp_cppyy._bind_object',
        'bind_object'            : 'interp_cppyy.bind_object',
        'move'                   : 'interp_cppyy.move',
        '_pin_type'              : 'interp_cppyy._pin_type',
    }

    appleveldefs = {
        '_post_import_startup'   : 'pythonify._post_import_startup',
        'Template'               : 'pythonify.CPPTemplate',
        'add_pythonization'      : 'pythonify.add_pythonization',
        'remove_pythonization'   : 'pythonify.remove_pythonization',
    }

    def __init__(self, space, *args):
        "NOT_RPYTHON"
        MixedModule.__init__(self, space, *args)

        # pythonization functions may be written in RPython, but the interp2app
        # code generation is not, so give it a chance to run now
        from pypy.module._cppyy import capi
        capi.register_pythonizations(space)
