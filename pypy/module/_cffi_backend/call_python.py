import os
from rpython.rlib.objectmodel import specialize, instantiate
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import jit
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.annlowlevel import llhelper

from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import interp2app
from pypy.module._cffi_backend import parse_c_type
from pypy.module._cffi_backend import cerrno
from pypy.module._cffi_backend import cffi_opcode
from pypy.module._cffi_backend import realize_c_type
from pypy.module._cffi_backend.realize_c_type import getop, getarg


STDERR = 2
EXTERNPY_FN = lltype.FuncType([parse_c_type.PEXTERNPY, rffi.CCHARP],
                              lltype.Void)


def _cffi_call_python(ll_externpy, ll_args):
    """Invoked by the helpers generated from extern "Python" in the cdef.

       'externpy' is a static structure that describes which of the
       extern "Python" functions is called.  It has got fields 'name' and
       'type_index' describing the function, and more reserved fields
       that are initially zero.  These reserved fields are set up by
       ffi.def_extern(), which invokes externpy_deco() below.

       'args' is a pointer to an array of 8-byte entries.  Each entry
       contains an argument.  If an argument is less than 8 bytes, only
       the part at the beginning of the entry is initialized.  If an
       argument is 'long double' or a struct/union, then it is passed
       by reference.

       'args' is also used as the place to write the result to
       (directly, even if more than 8 bytes).  In all cases, 'args' is
       at least 8 bytes in size.
    """
    from pypy.module._cffi_backend.ccallback import reveal_callback
    from rpython.rlib import rgil

    rgil.acquire_maybe_in_new_thread()
    llop.gc_stack_bottom(lltype.Void)   # marker to enter RPython from C

    cerrno._errno_after(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)

    if not ll_externpy.c_reserved1:
        # Not initialized!  We don't have a space at all.
        # Write the error to the file descriptor stderr.
        try:
            funcname = rffi.charp2str(ll_externpy.c_name)
            msg = ("extern \"Python\": function %s() called, but no code was "
                   "attached to it yet with @ffi.def_extern().  "
                   "Returning 0.\n" % (funcname,))
            os.write(STDERR, msg)
        except:
            pass
        for i in range(intmask(ll_externpy.c_size_of_result)):
            ll_args[i] = '\x00'
    else:
        externpython = reveal_callback(ll_externpy.c_reserved1)
        # the same buffer is used both for passing arguments and
        # the result value
        externpython.invoke(ll_args, ll_args)

    cerrno._errno_before(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)

    rgil.release()


def get_ll_cffi_call_python():
    return llhelper(lltype.Ptr(EXTERNPY_FN), _cffi_call_python)


class KeepaliveCache:
    def __init__(self, space):
        self.cache_dict = {}


@jit.dont_look_inside
def externpy_deco(space, w_ffi, w_python_callable, w_name, w_error, w_onerror):
    from pypy.module._cffi_backend.ffi_obj import W_FFIObject
    from pypy.module._cffi_backend.ccallback import W_ExternPython

    ffi = space.interp_w(W_FFIObject, w_ffi)

    if space.is_w(w_name, space.w_None):
        w_name = space.getattr(w_python_callable, space.newtext('__name__'))
    name = space.text_w(w_name)

    ctx = ffi.ctxobj.ctx
    index = parse_c_type.search_in_globals(ctx, name)
    if index < 0:
        raise externpy_not_found(ffi, name)

    g = ctx.c_globals[index]
    if getop(g.c_type_op) != cffi_opcode.OP_EXTERN_PYTHON:
        raise externpy_not_found(ffi, name)

    w_ct = realize_c_type.realize_c_type(ffi, ctx.c_types, getarg(g.c_type_op))

    # make a W_ExternPython instance, which is nonmovable; then cast it
    # to a raw pointer and assign it to the field 'reserved1' of the
    # externpy object from C.  We must make sure to keep it alive forever,
    # or at least until ffi.def_extern() is used again to change the
    # binding.  Note that the W_ExternPython is never exposed to the user.
    externpy = rffi.cast(parse_c_type.PEXTERNPY, g.c_address)
    externpython = instantiate(W_ExternPython, nonmovable=True)
    cdata = rffi.cast(rffi.CCHARP, externpy)
    W_ExternPython.__init__(externpython, space, cdata,
                          w_ct, w_python_callable, w_error, w_onerror)

    key = rffi.cast(lltype.Signed, externpy)
    space.fromcache(KeepaliveCache).cache_dict[key] = externpython
    externpy.c_reserved1 = externpython.hide_object()

    # return the function object unmodified
    return w_python_callable


def externpy_not_found(ffi, name):
    raise oefmt(ffi.w_FFIError,
                "ffi.def_extern('%s'): no 'extern \"Python\"' "
                "function with this name", name)

@specialize.memo()
def get_generic_decorator(space):
    return interp2app(externpy_deco).spacebind(space)
