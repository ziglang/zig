from pypy.interpreter.mixedmodule import MixedModule
import os

class Module(MixedModule):

    interpleveldefs = {
        'types':   'interp_ffitype.W_types',
        'CDLL':    'interp_funcptr.W_CDLL',
        'FuncPtr': 'interp_funcptr.W_FuncPtr',
        'get_libc':'interp_funcptr.get_libc',
        '_StructDescr': 'interp_struct.W__StructDescr',
        'Field':     'interp_struct.W_Field',
    }
    if os.name == 'nt':
        interpleveldefs['WinDLL'] = 'interp_funcptr.W_WinDLL'
    appleveldefs = {
        'Structure': 'app_struct.Structure',
        }
