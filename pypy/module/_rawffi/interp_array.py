
""" Interpreter-level implementation of array, exposing ll-structure
to app-level with apropriate interface
"""

from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty, interp_attrproperty_w
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib import rgc, clibffi
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.buffer import RawBufferView

from pypy.module._rawffi.interp_rawffi import (
    segfault_exception, W_DataShape, W_DataInstance, unwrap_value, wrap_value,
    TYPEMAP, size_alignment, unpack_shape_with_length, read_ptr, write_ptr,)
from pypy.module._rawffi.buffer import RawFFIBuffer


class W_Array(W_DataShape):
    def __init__(self, basicffitype, size):
        # A W_Array represent the C type '*T', which can also represent
        # the type of pointers to arrays of T.  So the following fields
        # are used to describe T only.  It is 'basicffitype' possibly
        # repeated until reaching the length 'size'.
        self.basicffitype = basicffitype
        self.size = size
        self.alignment = size_alignment(basicffitype)[1]

    def allocate(self, space, length, autofree=False):
        if autofree:
            return W_ArrayInstanceAutoFree(space, self, length)
        return W_ArrayInstance(space, self, length)

    def get_basic_ffi_type(self):
        return self.basicffitype

    @unwrap_spec(length=int, autofree=int)
    def descr_call(self, space, length, w_items=None, autofree=False):
        result = self.allocate(space, length, bool(autofree))
        if not space.is_none(w_items):
            items_w = space.unpackiterable(w_items)
            iterlength = len(items_w)
            if iterlength > length:
                raise oefmt(space.w_ValueError,
                            "too many items for specified array length")
            for num in range(iterlength):
                w_item = items_w[num]
                unwrap_value(space, write_ptr, result.ll_buffer, num,
                             self.itemcode, w_item)
        return result

    def descr_repr(self, space):
        return space.newtext("<_rawffi.Array '%s' (%d, %d)>" % (self.itemcode,
                                                                self.size,
                                                                self.alignment))

    @unwrap_spec(address=r_uint, length=int)
    def fromaddress(self, space, address, length):
        return W_ArrayInstance(space, self, length, address)

PRIMITIVE_ARRAY_TYPES = {}
for _code in TYPEMAP:
    PRIMITIVE_ARRAY_TYPES[_code] = W_Array(TYPEMAP[_code],
                                           size_alignment(TYPEMAP[_code])[0])
    PRIMITIVE_ARRAY_TYPES[_code].itemcode = _code
ARRAY_OF_PTRS = PRIMITIVE_ARRAY_TYPES['P']

def descr_new_array(space, w_type, w_shape):
    return unpack_shape_with_length(space, w_shape)

W_Array.typedef = TypeDef(
    'Array',
    __new__  = interp2app(descr_new_array),
    __call__ = interp2app(W_Array.descr_call),
    __repr__ = interp2app(W_Array.descr_repr),
    fromaddress = interp2app(W_Array.fromaddress),
    size_alignment = interp2app(W_Array.descr_size_alignment)
)
W_Array.typedef.acceptable_as_base_class = False


class W_ArrayInstance(W_DataInstance):
    def __init__(self, space, shape, length, address=r_uint(0)):
        memsize = shape.size * length
        # For W_ArrayInstances that are used as the result value of a
        # function call, ffi_call() writes 8 bytes into it even if the
        # function's result type asks for less.
        memsize = clibffi.adjust_return_size(memsize)
        W_DataInstance.__init__(self, space, memsize, address)
        self.length = length
        self.shape = shape
        self.fmt = shape.itemcode
        self.itemsize = shape.size

    def descr_repr(self, space):
        addr = rffi.cast(lltype.Unsigned, self.ll_buffer)
        return space.newtext("<_rawffi array %x of length %d>" % (addr,
                                                                  self.length))

    # This only allows non-negative indexes.  Arrays of shape 'c' also
    # support simple slices.

    def setitem(self, space, num, w_value):
        if not self.ll_buffer:
            raise segfault_exception(space, "setting element of freed array")
        if num >= self.length or num < 0:
            raise OperationError(space.w_IndexError, space.w_None)
        unwrap_value(space, write_ptr, self.ll_buffer, num, self.fmt, w_value)

    def descr_setitem(self, space, w_index, w_value):
        try:
            num = space.int_w(w_index)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
            self.setslice(space, w_index, w_value)
        else:
            self.setitem(space, num, w_value)

    def getitem(self, space, num):
        if not self.ll_buffer:
            raise segfault_exception(space, "accessing elements of freed array")
        if num >= self.length or num < 0:
            raise OperationError(space.w_IndexError, space.w_None)
        return wrap_value(space, read_ptr, self.ll_buffer, num, self.fmt)

    def descr_getitem(self, space, w_index):
        try:
            num = space.int_w(w_index)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
            return self.getslice(space, w_index)
        else:
            return self.getitem(space, num)

    def getlength(self, space):
        return space.newint(self.length)

    @unwrap_spec(num=int)
    def descr_itemaddress(self, space, num):
        ptr = rffi.ptradd(self.ll_buffer, self.itemsize * num)
        return space.newint(rffi.cast(lltype.Unsigned, ptr))

    def getrawsize(self):
        return self.itemsize * self.length

    def decodeslice(self, space, w_slice):
        if not space.isinstance_w(w_slice, space.w_slice):
            raise oefmt(space.w_TypeError, "index must be int or slice")
        if self.fmt != 'c':
            raise oefmt(space.w_TypeError, "only 'c' arrays support slicing")
        w_start = space.getattr(w_slice, space.newtext('start'))
        w_stop = space.getattr(w_slice, space.newtext('stop'))
        w_step = space.getattr(w_slice, space.newtext('step'))

        if space.is_w(w_start, space.w_None):
            start = 0
        else:
            start = space.int_w(w_start)
        if space.is_w(w_stop, space.w_None):
            stop = self.length
        else:
            stop = space.int_w(w_stop)
        if not space.is_w(w_step, space.w_None):
            step = space.int_w(w_step)
            if step != 1:
                raise oefmt(space.w_ValueError, "no step support")
        if not (0 <= start <= stop <= self.length):
            raise oefmt(space.w_ValueError, "slice out of bounds")
        if not self.ll_buffer:
            raise segfault_exception(space, "accessing a freed array")
        return start, stop

    def getslice(self, space, w_slice):
        start, stop = self.decodeslice(space, w_slice)
        ll_buffer = self.ll_buffer
        result = [ll_buffer[i] for i in range(start, stop)]
        return space.newbytes(''.join(result))

    def setslice(self, space, w_slice, w_value):
        start, stop = self.decodeslice(space, w_slice)
        value = space.bytes_w(w_value)
        if start + len(value) != stop:
            raise oefmt(space.w_ValueError, "cannot resize array")
        ll_buffer = self.ll_buffer
        for i in range(len(value)):
            ll_buffer[start + i] = value[i]

    def buffer_w(self, space, flags):
        return RawBufferView(
            RawFFIBuffer(self), self.shape.itemcode, self.shape.size,
            w_obj=self)


W_ArrayInstance.typedef = TypeDef(
    'ArrayInstance', None, None, "read-write",
    __repr__    = interp2app(W_ArrayInstance.descr_repr),
    __setitem__ = interp2app(W_ArrayInstance.descr_setitem),
    __getitem__ = interp2app(W_ArrayInstance.descr_getitem),
    __len__     = interp2app(W_ArrayInstance.getlength),
    buffer      = GetSetProperty(W_ArrayInstance.getbuffer),
    shape       = interp_attrproperty_w('shape', W_ArrayInstance),
    free        = interp2app(W_ArrayInstance.free),
    byptr       = interp2app(W_ArrayInstance.byptr),
    itemaddress = interp2app(W_ArrayInstance.descr_itemaddress),
)
W_ArrayInstance.typedef.acceptable_as_base_class = False


class W_ArrayInstanceAutoFree(W_ArrayInstance):
    def __init__(self, space, shape, length):
        W_ArrayInstance.__init__(self, space, shape, length, 0)

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.ll_buffer:
            self._free()


W_ArrayInstanceAutoFree.typedef = TypeDef(
    'ArrayInstanceAutoFree', None, None, "read-write",
    __repr__    = interp2app(W_ArrayInstance.descr_repr),
    __setitem__ = interp2app(W_ArrayInstance.descr_setitem),
    __getitem__ = interp2app(W_ArrayInstance.descr_getitem),
    __len__     = interp2app(W_ArrayInstance.getlength),
    buffer      = GetSetProperty(W_ArrayInstance.getbuffer),
    shape       = interp_attrproperty_w('shape', W_ArrayInstance),
    byptr       = interp2app(W_ArrayInstance.byptr),
    itemaddress = interp2app(W_ArrayInstance.descr_itemaddress),
)
W_ArrayInstanceAutoFree.typedef.acceptable_as_base_class = False
