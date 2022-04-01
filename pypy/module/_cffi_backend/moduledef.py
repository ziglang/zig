import sys
from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib import rdynload, clibffi
from rpython.rtyper.lltypesystem import rffi

from . import VERSION

FFI_DEFAULT_ABI = clibffi.FFI_DEFAULT_ABI
try:
    FFI_STDCALL = clibffi.FFI_STDCALL
    has_stdcall = True
except AttributeError:
    has_stdcall = False
    FFI_STDCALL = None


class Module(MixedModule):

    appleveldefs = {
        }
    interpleveldefs = {
        '__version__': 'space.wrap("%s")' % VERSION,

        'load_library': 'libraryobj.load_library',

        'new_primitive_type': 'newtype.new_primitive_type',
        'new_pointer_type': 'newtype.new_pointer_type',
        'new_array_type': 'newtype.new_array_type',
        'new_struct_type': 'newtype.new_struct_type',
        'new_union_type': 'newtype.new_union_type',
        'complete_struct_or_union': 'newtype.complete_struct_or_union',
        'new_void_type': 'newtype.new_void_type',
        'new_enum_type': 'newtype.new_enum_type',
        'new_function_type': 'newtype.new_function_type',

        'newp': 'func.newp',
        'cast': 'func.cast',
        'callback': 'func.callback',
        'alignof': 'func.alignof',
        'sizeof': 'func.sizeof',
        'typeof': 'func.typeof',
        'typeoffsetof': 'func.typeoffsetof',
        'rawaddressof': 'func.rawaddressof',
        'getcname': 'func.getcname',
        'newp_handle': 'handle.newp_handle',
        'from_handle': 'handle.from_handle',
        '_get_types': 'func._get_types',
        '_get_common_types': 'func._get_common_types',
        'from_buffer': 'func.from_buffer',
        'gcp': 'func.gcp',

        '_offset_in_bytes': 'func.offset_in_bytes',

        'string': 'func.string',
        'unpack': 'func.unpack',
        'buffer': 'cbuffer.MiniBuffer',
        'memmove': 'func.memmove',
        'release': 'func.release',

        'get_errno': 'cerrno.get_errno',
        'set_errno': 'cerrno.set_errno',

        'FFI_DEFAULT_ABI': 'space.wrap(%d)' % FFI_DEFAULT_ABI,
        'FFI_CDECL':       'space.wrap(%d)' % FFI_DEFAULT_ABI,  # win32 name

        # types
        'FFI': 'ffi_obj.W_FFIObject',
        'Lib': 'lib_obj.W_LibObject',
        'CType': 'ctypeobj.W_CType',
        'CField': 'ctypestruct.W_CField',
        'CLibrary': 'libraryobj.W_Library',
        '_CDataBase': 'cdataobj.W_CData',
        '__FFIAllocator': 'allocator.W_Allocator',
        '__FFIGlobSupport': 'cglob.W_GlobSupport',
        '__CData_iterator': 'ctypearray.W_CDataIter',
        '__FFIFunctionWrapper': 'wrapper.W_FunctionWrapper',
        }
    if sys.platform == 'win32':
        interpleveldefs['getwinerror'] = 'cerrno.getwinerror'

    if has_stdcall:
        interpleveldefs['FFI_STDCALL'] = 'space.wrap(%d)' % FFI_STDCALL

    def __init__(self, space, *args):
        MixedModule.__init__(self, space, *args)
        #
        if (not space.config.objspace.disable_entrypoints and
            not space.config.objspace.disable_entrypoints_in_cffi):
            # import 'embedding', which has the side-effect of registering
            # the 'pypy_init_embedded_cffi_module' entry point
            from pypy.module._cffi_backend import embedding
            embedding.glob.space = space


def get_dict_rtld_constants():
    found = {}
    for name in ["RTLD_LAZY", "RTLD_NOW", "RTLD_GLOBAL", "RTLD_LOCAL",
                 "RTLD_NODELETE", "RTLD_NOLOAD", "RTLD_DEEPBIND"]:
        if getattr(rdynload.cConfig, name) is not None:
            found[name] = getattr(rdynload.cConfig, name)
    for name in ["RTLD_LAZY", "RTLD_NOW", "RTLD_GLOBAL", "RTLD_LOCAL"]:
        found.setdefault(name, 0)
    return found

for _name, _value in get_dict_rtld_constants().items():
    Module.interpleveldefs[_name] = 'space.wrap(%d)' % _value
