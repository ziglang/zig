from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import jit

from pypy.interpreter.error import oefmt
from pypy.interpreter.module import Module
from pypy.module import _cffi_backend
from pypy.module._cffi_backend import parse_c_type
from pypy.module._cffi_backend.ffi_obj import W_FFIObject
from pypy.module._cffi_backend.lib_obj import W_LibObject


VERSION_MIN    = 0x2601
VERSION_MAX    = 0x28FF

VERSION_EXPORT = 0x0A03

INITFUNCPTR = lltype.Ptr(lltype.FuncType([rffi.VOIDPP], lltype.Void))

@jit.dont_look_inside
def load_cffi1_module(space, name, path, initptr):
    # This is called from pypy.module.cpyext.api.load_extension_module()
    from pypy.module._cffi_backend.call_python import get_ll_cffi_call_python

    initfunc = rffi.cast(INITFUNCPTR, initptr)
    with lltype.scoped_alloc(rffi.VOIDPP.TO, 16, zero=True) as p:
        p[0] = rffi.cast(rffi.VOIDP, VERSION_EXPORT)
        p[1] = rffi.cast(rffi.VOIDP, get_ll_cffi_call_python())
        initfunc(p)
        version = rffi.cast(lltype.Signed, p[0])
        if not (VERSION_MIN <= version <= VERSION_MAX):
            raise oefmt(space.w_ImportError,
                "cffi extension module '%s' uses an unknown version tag %s. "
                "This module might need a more recent version of PyPy. "
                "The current PyPy provides CFFI %s.",
                name, hex(version), _cffi_backend.VERSION)
        src_ctx = rffi.cast(parse_c_type.PCTX, p[1])

    ffi = W_FFIObject(space, src_ctx)
    lib = W_LibObject(ffi, name)
    if src_ctx.c_includes:
        lib.make_includes_from(src_ctx.c_includes)

    w_name = space.newtext(name)
    module = Module(space, w_name)
    if path is not None:
        module.setdictvalue(space, '__file__', space.newfilename(path))
    module.setdictvalue(space, 'ffi', ffi)
    module.setdictvalue(space, 'lib', lib)
    w_modules_dict = space.sys.get('modules')
    space.setitem(w_modules_dict, w_name, module)
    space.setitem(w_modules_dict, space.newtext(name + '.lib'), lib)
    return module
