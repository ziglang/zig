""" Low-level interface to clibffi
"""

from pypy.interpreter.mixedmodule import MixedModule
from pypy.module._rawffi.alt.moduledef import Module as AltModule

class Module(MixedModule):
    interpleveldefs = {
        'CDLL'               : 'interp_rawffi.W_CDLL',
        'FuncPtr'            : 'interp_rawffi.W_FuncPtr',
        'Structure'          : 'structure.W_Structure',
        'StructureInstance'  : 'structure.W_StructureInstance',
        'StructureInstanceAutoFree' : 'structure.W_StructureInstanceAutoFree',
        'Array'              : 'interp_array.W_Array',
        'ArrayInstance'      : 'interp_array.W_ArrayInstance',
        'ArrayInstanceAutoFree': 'interp_array.W_ArrayInstanceAutoFree',
        'sizeof'             : 'interp_rawffi.sizeof',
        'alignment'          : 'interp_rawffi.alignment',
        'charp2string'       : 'interp_rawffi.charp2string',
        'wcharp2unicode'     : 'interp_rawffi.wcharp2unicode',
        'charp2rawstring'    : 'interp_rawffi.charp2rawstring',
        'wcharp2rawunicode'  : 'interp_rawffi.wcharp2rawunicode',
        'rawstring2charp'    : 'interp_rawffi.rawstring2charp',
        'CallbackPtr'        : 'callback.W_CallbackPtr',
        '_num_of_allocated_objects': 'tracker.num_of_allocated_objects',
        'get_libc'           : 'interp_rawffi.get_libc',
        'get_errno'          : 'interp_rawffi.get_errno',
        'set_errno'          : 'interp_rawffi.set_errno',
        'get_last_error'     : 'interp_rawffi.get_last_error',
        'set_last_error'     : 'interp_rawffi.set_last_error',
        'SegfaultException'  : 'space.new_exception_class("_rawffi.SegfaultException")',
        'exit'               : 'interp_exit.exit',
    }

    appleveldefs = {
    }

    submodules = {
        'alt': AltModule,
    }

    def buildloaders(cls):
        from pypy.module._rawffi import interp_rawffi

        if hasattr(interp_rawffi, 'FormatError'):
            Module.interpleveldefs['FormatError'] = 'interp_rawffi.FormatError'
        if hasattr(interp_rawffi, 'check_HRESULT'):
            Module.interpleveldefs['check_HRESULT'] = 'interp_rawffi.check_HRESULT'

        from rpython.rlib import clibffi
        for name in ['FUNCFLAG_STDCALL', 'FUNCFLAG_CDECL', 'FUNCFLAG_PYTHONAPI',
                     'FUNCFLAG_USE_ERRNO', 'FUNCFLAG_USE_LASTERROR',
                     ]:
            if hasattr(clibffi, name):
                Module.interpleveldefs[name] = "space.wrap(%r)" % getattr(clibffi, name)

        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)
