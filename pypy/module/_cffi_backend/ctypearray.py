"""
Arrays.
"""

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import ovfcheck

from pypy.module._cffi_backend import cdataobj
from pypy.module._cffi_backend.ctypeptr import W_CTypePtrOrArray, W_CTypePointer
from pypy.module._cffi_backend import ctypeprim


class W_CTypeArray(W_CTypePtrOrArray):
    _attrs_            = ['ctptr']
    _immutable_fields_ = ['ctptr']
    kind = "array"
    is_nonfunc_pointer_or_array = True

    def __init__(self, space, ctptr, length, arraysize, extra):
        assert isinstance(ctptr, W_CTypePointer)
        W_CTypePtrOrArray.__init__(self, space, arraysize, extra, 0,
                                   ctptr.ctitem)
        self.length = length    # -1 if no length is given, e.g. 'int[]'
        self.ctptr = ctptr

    def _alignof(self):
        return self.ctitem.alignof()

    def newp(self, w_init, allocator):
        space = self.space
        datasize = self.size
        #
        if datasize < 0:
            w_init, length = self.get_new_array_length(w_init)
            try:
                datasize = ovfcheck(length * self.ctitem.size)
            except OverflowError:
                raise oefmt(space.w_OverflowError,
                            "array size would overflow a ssize_t")
        else:
            length = self.length
        #
        cdata = allocator.allocate(space, datasize, self, length)
        #
        if not space.is_w(w_init, space.w_None):
            with cdata as ptr:
                self.convert_from_object(ptr, w_init)
        return cdata

    def get_new_array_length(self, w_value):
        space = self.space
        if (space.isinstance_w(w_value, space.w_list) or
            space.isinstance_w(w_value, space.w_tuple)):
            return (w_value, space.int_w(space.len(w_value)))
        elif space.isinstance_w(w_value, space.w_bytes):
            # from a string, we add the null terminator
            s = space.bytes_w(w_value)
            return (w_value, len(s) + 1)
        elif space.isinstance_w(w_value, space.w_unicode):
            from pypy.module._cffi_backend import wchar_helper
            w_u = space.convert_arg_to_w_unicode(w_value)
            if self.ctitem.size == 2:
                length = wchar_helper.utf8_size_as_char16(w_u._utf8)
            else:
                length = w_u._len()
            return (w_value, length + 1)
        else:
            try:
                explicitlength = space.getindex_w(w_value,
                                                  space.w_OverflowError)
            except OperationError as e:
                if e.match(space, space.w_TypeError):
                    raise oefmt(space.w_TypeError,
                        "expected new array length or list/tuple/str, "
                        "not %T", w_value)
                raise
            if explicitlength < 0:
                raise oefmt(space.w_ValueError, "negative array length")
            return (space.w_None, explicitlength)

    def _check_subscript_index(self, w_cdata, i):
        space = self.space
        if i < 0:
            raise oefmt(space.w_IndexError, "negative index")
        if i >= w_cdata.get_array_length():
            raise oefmt(space.w_IndexError,
                        "index too large for cdata '%s' (expected %d < %d)",
                        self.name, i, w_cdata.get_array_length())
        return self

    def _check_slice_index(self, w_cdata, start, stop):
        space = self.space
        if start < 0:
            raise oefmt(space.w_IndexError, "negative index")
        if stop > w_cdata.get_array_length():
            raise oefmt(space.w_IndexError,
                        "index too large (expected %d <= %d)",
                        stop, w_cdata.get_array_length())
        return self.ctptr

    def convert_from_object(self, cdata, w_ob):
        if isinstance(w_ob, cdataobj.W_CData) and w_ob.ctype is self:
            length = w_ob.get_array_length()
            with w_ob as source:
                source = rffi.cast(rffi.VOIDP, source)
                target = rffi.cast(rffi.VOIDP, cdata)
                size = rffi.cast(rffi.SIZE_T, self.ctitem.size * length)
                rffi.c_memcpy(target, source, size)
        else:
            self.convert_array_from_object(cdata, w_ob)

    def convert_to_object(self, cdata):
        if self.length < 0:
            # we can't return a <cdata 'int[]'> here, because we don't
            # know the length to give it.  As a compromize, returns
            # <cdata 'int *'> in this case.
            self = self.ctptr
        #
        return cdataobj.W_CData(self.space, cdata, self)

    def add(self, cdata, i):
        p = rffi.ptradd(cdata, i * self.ctitem.size)
        return cdataobj.W_CData(self.space, p, self.ctptr)

    def iter(self, cdata):
        return W_CDataIter(self.space, self.ctitem, cdata)

    def get_vararg_type(self):
        return self.ctptr

    def _fget(self, attrchar):
        if attrchar == 'i':     # item
            return self.ctitem
        if attrchar == 'l':     # length
            if self.length >= 0:
                return self.space.newint(self.length)
            else:
                return self.space.w_None
        return W_CTypePtrOrArray._fget(self, attrchar)

    def typeoffsetof_index(self, index):
        return self.ctptr.typeoffsetof_index(index)


class W_CDataIter(W_Root):
    _immutable_fields_ = ['ctitem', 'cdata', '_stop']    # but not '_next'

    def __init__(self, space, ctitem, cdata):
        self.space = space
        self.ctitem = ctitem
        self.cdata = cdata
        length = cdata.get_array_length()
        self._next = cdata.unsafe_escaping_ptr()
        self._stop = rffi.ptradd(self._next, length * ctitem.size)

    def iter_w(self):
        return self

    def next_w(self):
        result = self._next
        if result == self._stop:
            raise OperationError(self.space.w_StopIteration, self.space.w_None)
        self._next = rffi.ptradd(result, self.ctitem.size)
        return self.ctitem.convert_to_object(result)

W_CDataIter.typedef = TypeDef(
    '_cffi_backend.__CData_iterator',
    __iter__ = interp2app(W_CDataIter.iter_w),
    __next__ = interp2app(W_CDataIter.next_w),
    )
W_CDataIter.typedef.acceptable_as_base_class = False
