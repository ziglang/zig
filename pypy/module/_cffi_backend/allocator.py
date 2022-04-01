from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rgc


class W_Allocator(W_Root):
    _immutable_ = True

    def __init__(self, ffi, w_alloc, w_free, should_clear_after_alloc):
        self.ffi = ffi    # may be None
        self.w_alloc = w_alloc
        self.w_free = w_free
        self.should_clear_after_alloc = should_clear_after_alloc

    def allocate(self, space, datasize, ctype, length=-1):
        from pypy.module._cffi_backend import cdataobj, ctypeptr
        if self.w_alloc is None:
            if self.should_clear_after_alloc:
                ptr = lltype.malloc(rffi.CCHARP.TO, datasize,
                                    flavor='raw', zero=True)
            else:
                ptr = lltype.malloc(rffi.CCHARP.TO, datasize,
                                    flavor='raw', zero=False)
            w_res = cdataobj.W_CDataNewStd(space, ptr, ctype, length)
            rgc.add_memory_pressure(datasize, w_res)
            return w_res
        else:
            w_raw_cdata = space.call_function(self.w_alloc,
                                              space.newint(datasize))
            if not isinstance(w_raw_cdata, cdataobj.W_CData):
                raise oefmt(space.w_TypeError,
                            "alloc() must return a cdata object (got %T)",
                            w_raw_cdata)
            if not isinstance(w_raw_cdata.ctype, ctypeptr.W_CTypePtrOrArray):
                raise oefmt(space.w_TypeError,
                            "alloc() must return a cdata pointer, not '%s'",
                            w_raw_cdata.ctype.name)
            #
            ptr = w_raw_cdata.unsafe_escaping_ptr()
            if not ptr:
                raise oefmt(space.w_MemoryError, "alloc() returned NULL")
            #
            if self.should_clear_after_alloc:
                rffi.c_memset(rffi.cast(rffi.VOIDP, ptr), 0,
                              rffi.cast(rffi.SIZE_T, datasize))
            #
            res = cdataobj.W_CDataNewNonStd(space, ptr, ctype, length)
            res.w_raw_cdata = w_raw_cdata
            if self.w_free is not None:
                res.w_free = self.w_free
                res.register_finalizer(space)
            rgc.add_memory_pressure(datasize, res)
            return res

    @unwrap_spec(w_init=WrappedDefault(None))
    def descr_call(self, space, w_arg, w_init):
        ffi = self.ffi
        assert ffi is not None
        w_ctype = ffi.ffi_type(w_arg, ffi.ACCEPT_STRING | ffi.ACCEPT_CTYPE)
        return w_ctype.newp(w_init, self)


W_Allocator.typedef = TypeDef(
        '_cffi_backend.__FFIAllocator',
        __call__ = interp2app(W_Allocator.descr_call),
        )
W_Allocator.typedef.acceptable_as_base_class = False


def new_allocator(ffi, w_alloc, w_free, should_clear_after_alloc):
    space = ffi.space
    if space.is_none(w_alloc):
        w_alloc = None
    if space.is_none(w_free):
        w_free = None
    if w_alloc is None and w_free is not None:
        raise oefmt(space.w_TypeError, "cannot pass 'free' without 'alloc'")
    alloc = W_Allocator(ffi, w_alloc, w_free, bool(should_clear_after_alloc))
    return alloc


default_allocator = W_Allocator(None, None, None, should_clear_after_alloc=True)
nonzero_allocator = W_Allocator(None, None, None,should_clear_after_alloc=False)
