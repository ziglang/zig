from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef
from pypy.module._cffi_backend.cdataobj import W_CData
from pypy.module._cffi_backend import newtype
from rpython.rlib import rgil
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo


class W_GlobSupport(W_Root):
    _immutable_fields_ = ['w_ctype', 'ptr', 'fetch_addr']

    def __init__(self, space, name, w_ctype, ptr=lltype.nullptr(rffi.CCHARP.TO),
                 fetch_addr=lltype.nullptr(rffi.VOIDP.TO)):
        self.space = space
        self.name = name
        self.w_ctype = w_ctype
        self.ptr = ptr
        self.fetch_addr = fetch_addr

    def fetch_global_var_addr(self):
        if self.ptr:
            result = self.ptr
        else:
            if not we_are_translated():
                FNPTR = rffi.CCallback([], rffi.VOIDP)
                fetch_addr = rffi.cast(FNPTR, self.fetch_addr)
                rgil.release()
                result = fetch_addr()
                rgil.acquire()
            else:
                # careful in translated versions: we need to call fetch_addr,
                # but in a GIL-releasing way.  The easiest is to invoke a
                # llexternal() helper.
                result = pypy__cffi_fetch_var(self.fetch_addr)
            result = rffi.cast(rffi.CCHARP, result)
        if not result:
            from pypy.module._cffi_backend import ffi_obj
            ffierror = ffi_obj.get_ffi_error(self.space)
            raise oefmt(ffierror, "global variable '%s' is at address NULL",
                        self.name)
        return result

    def read_global_var(self):
        return self.w_ctype.convert_to_object(self.fetch_global_var_addr())

    def write_global_var(self, w_newvalue):
        self.w_ctype.convert_from_object(self.fetch_global_var_addr(),
                                         w_newvalue)

    def address(self):
        w_ctypeptr = newtype.new_pointer_type(self.space, self.w_ctype)
        return W_CData(self.space, self.fetch_global_var_addr(), w_ctypeptr)

W_GlobSupport.typedef = TypeDef("_cffi_backend.__FFIGlobSupport")
W_GlobSupport.typedef.acceptable_as_base_class = False


eci = ExternalCompilationInfo(post_include_bits=["""
static void *pypy__cffi_fetch_var(void *fetch_addr) {
    return ((void*(*)(void))fetch_addr)();
}
"""])

pypy__cffi_fetch_var = rffi.llexternal(
    "pypy__cffi_fetch_var", [rffi.VOIDP], rffi.VOIDP,
    compilation_info=eci)
