import py
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.baseobjspace import W_Root
from pypy.module._cffi_backend import ctypeobj, ctypeptr, cdataobj
from pypy.module._cffi_backend.hide_reveal import hide_reveal2
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib import objectmodel, jit

# ____________________________________________________________

@jit.dont_look_inside
def _newp_handle(space, w_ctype, w_x):
    # Allocate a handle as a nonmovable W_CDataHandle instance, which
    # we can cast to a plain CCHARP.  As long as the object is not freed,
    # we can cast the CCHARP back to a W_CDataHandle with reveal_gcref().
    new_cdataobj = objectmodel.instantiate(cdataobj.W_CDataHandle,
                                           nonmovable=True)
    _cdata = hide_reveal2().hide_object(rffi.CCHARP, new_cdataobj)
    cdataobj.W_CDataHandle.__init__(new_cdataobj, space, _cdata, w_ctype, w_x)
    return new_cdataobj

@unwrap_spec(w_ctype=ctypeobj.W_CType)
def newp_handle(space, w_ctype, w_x):
    if (not isinstance(w_ctype, ctypeptr.W_CTypePointer) or
        not w_ctype.is_void_ptr):
        raise oefmt(space.w_TypeError,
                    "needs 'void *', got '%s'", w_ctype.name)
    return _newp_handle(space, w_ctype, w_x)

@unwrap_spec(w_cdata=cdataobj.W_CData)
def from_handle(space, w_cdata):
    ctype = w_cdata.ctype
    if (not isinstance(ctype, ctypeptr.W_CTypePointer) or
        not ctype.is_voidchar_ptr):
        raise oefmt(space.w_TypeError,
                    "expected a 'cdata' object with a 'void *' out of "
                    "new_handle(), got '%s'", ctype.name)
    with w_cdata as ptr:
        return _reveal(space, ptr)

@jit.dont_look_inside
def _reveal(space, ptr):
    addr = rffi.cast(llmemory.Address, ptr)
    if not addr:
        raise oefmt(space.w_RuntimeError,
                    "cannot use from_handle() on NULL pointer")
    cd = hide_reveal2().reveal_object(cdataobj.W_CDataHandle, addr)
    if cd is None:
        raise oefmt(space.w_SystemError,
                    "ffi.from_handle(): dead or bogus object handle")
    return cd.w_keepalive
