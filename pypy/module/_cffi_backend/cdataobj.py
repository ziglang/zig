import operator

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef, make_weakref_descr

from rpython.rlib import rgc
from rpython.rlib.objectmodel import keepalive_until_here, specialize
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.tool.sourcetools import func_with_new_name

from pypy.module._cffi_backend import misc


class W_CData(W_Root):
    _attrs_ = ['space', '_ptr', 'ctype', '_lifeline_']
    _immutable_fields_ = ['_ptr', 'ctype']
    _ptr = lltype.nullptr(rffi.CCHARP.TO)

    def __init__(self, space, ptr, ctype):
        from pypy.module._cffi_backend import ctypeobj
        assert lltype.typeOf(ptr) == rffi.CCHARP
        assert isinstance(ctype, ctypeobj.W_CType)
        self.space = space
        self._ptr = ptr    # don't access directly!  use "with cdata as ptr:"
        self.ctype = ctype

    def __enter__(self):
        """Use 'with cdata as ptr:' to access the raw memory.  It will
        stay alive at least until the end of the 'with' block.
        """
        return self._ptr

    def __exit__(self, *args):
        keepalive_until_here(self)

    def unsafe_escaping_ptr(self):
        """Generally unsafe: escape the pointer to raw memory.
        If 'self' is a subclass that frees the pointer in a destructor,
        it may be freed under your feet at any time.
        """
        return self._ptr

    def _repr_extra(self):
        with self as ptr:
            extra = self.ctype.extra_repr(ptr)
        return extra

    def _repr_extra_owning(self):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePointer
        ctype = self.ctype
        if isinstance(ctype, W_CTypePointer):
            num_bytes = ctype.ctitem.size
        else:
            num_bytes = self._sizeof()
        return 'owning %d bytes' % num_bytes

    def repr(self):
        extra2 = self._repr_extra()
        extra1 = ''
        if not isinstance(self, W_CDataNewOwning):
            # it's slightly confusing to get "<cdata 'struct foo' 0x...>"
            # because the struct foo is not owned.  Trying to make it
            # clearer, write in this case "<cdata 'struct foo &' 0x...>".
            from pypy.module._cffi_backend import ctypestruct
            if isinstance(self.ctype, ctypestruct.W_CTypeStructOrUnion):
                extra1 = ' &'
        return self.space.newtext("<cdata '%s%s' %s>" % (
            self.ctype.name, extra1, extra2))

    def bool(self):
        with self as ptr:
            nonzero = self.ctype.nonzero(ptr)
        return self.space.newbool(nonzero)

    def int(self, space):
        with self as ptr:
            w_result = self.ctype.cast_to_int(ptr)
        return w_result

    def float(self):
        with self as ptr:
            w_result = self.ctype.float(ptr)
        return w_result

    def complex(self):
        with self as ptr:
            w_result = self.ctype.complex(ptr)
        return w_result

    def len(self):
        from pypy.module._cffi_backend import ctypearray
        space = self.space
        if isinstance(self.ctype, ctypearray.W_CTypeArray):
            return space.newint(self.get_array_length())
        raise oefmt(space.w_TypeError,
                    "cdata of type '%s' has no len()", self.ctype.name)

    def _compare_mode(self, w_other):
        from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitive
        zero = rffi.cast(lltype.Unsigned, 0)
        self_is_ptr = not isinstance(self.ctype, W_CTypePrimitive)
        other_is_ptr = (isinstance(w_other, W_CData) and
                           not isinstance(w_other.ctype, W_CTypePrimitive))
        if other_is_ptr and self_is_ptr:
            with self as ptr1, w_other as ptr2:
                ptr1 = rffi.cast(lltype.Unsigned, ptr1)
                ptr2 = rffi.cast(lltype.Unsigned, ptr2)
            return (0, ptr1, ptr2, None, None)
        elif other_is_ptr or self_is_ptr:
            return (-1, zero, zero, None, None)
        else:
            w_ob1 = self.convert_to_object()
            if isinstance(w_other, W_CData):
                w_ob2 = w_other.convert_to_object()
            else:
                w_ob2 = w_other
            return (1, zero, zero, w_ob1, w_ob2)

    def _make_comparison(name):
        op = getattr(operator, name)
        #
        def _cmp(self, w_other):
            space = self.space
            mode, adr1, adr2, w_ob1, w_ob2 = self._compare_mode(w_other)
            if mode == 0:
                return space.newbool(op(adr1, adr2))
            elif mode == 1:
                return getattr(space, name)(w_ob1, w_ob2)
            else:
                return space.w_NotImplemented
        #
        return func_with_new_name(_cmp, name)

    lt = _make_comparison('lt')
    le = _make_comparison('le')
    eq = _make_comparison('eq')
    ne = _make_comparison('ne')
    gt = _make_comparison('gt')
    ge = _make_comparison('ge')

    def hash(self):
        from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitive
        if isinstance(self.ctype, W_CTypePrimitive):
            w_ob = self.convert_to_object()
            if not isinstance(w_ob, W_CData):
                return self.space.hash(w_ob)
        ptr = self.unsafe_escaping_ptr()
        h = rffi.cast(lltype.Signed, ptr)
        # To hash pointers in dictionaries.  Assumes that h shows some
        # alignment (to 4, 8, maybe 16 bytes), so we use the following
        # formula to avoid the trailing bits being always 0.
        h = h ^ (h >> 4)
        return self.space.newint(h)

    def getitem(self, w_index):
        space = self.space
        if space.isinstance_w(w_index, space.w_slice):
            w_o = self._do_getslice(w_index)
        else:
            i = space.getindex_w(w_index, space.w_IndexError)
            ctype = self.ctype._check_subscript_index(self, i)
            w_o = self._do_getitem(ctype, i)
        return w_o

    def _do_getitem(self, ctype, i):
        ctitem = ctype.ctitem
        with self as ptr:
            return ctitem.convert_to_object(
                rffi.ptradd(ptr, i * ctitem.size))

    def setitem(self, w_index, w_value):
        space = self.space
        if space.isinstance_w(w_index, space.w_slice):
            with self as ptr:
                self._do_setslice(w_index, w_value, ptr)
        else:
            i = space.getindex_w(w_index, space.w_IndexError)
            ctype = self.ctype._check_subscript_index(self, i)
            ctitem = ctype.ctitem
            with self as ptr:
                ctitem.convert_from_object(
                    rffi.ptradd(ptr, i * ctitem.size),
                    w_value)

    def _do_getslicearg(self, w_slice):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePointer
        from pypy.objspace.std.sliceobject import W_SliceObject
        assert isinstance(w_slice, W_SliceObject)
        space = self.space
        #
        if space.is_w(w_slice.w_start, space.w_None):
            raise oefmt(space.w_IndexError, "slice start must be specified")
        start = space.int_w(w_slice.w_start)
        #
        if space.is_w(w_slice.w_stop, space.w_None):
            raise oefmt(space.w_IndexError, "slice stop must be specified")
        stop = space.int_w(w_slice.w_stop)
        #
        if not space.is_w(w_slice.w_step, space.w_None):
            raise oefmt(space.w_IndexError, "slice with step not supported")
        #
        if start > stop:
            raise oefmt(space.w_IndexError, "slice start > stop")
        #
        ctype = self.ctype._check_slice_index(self, start, stop)
        assert isinstance(ctype, W_CTypePointer)
        #
        return ctype, start, stop - start

    def _do_getslice(self, w_slice):
        ctptr, start, length = self._do_getslicearg(w_slice)
        #
        space = self.space
        ctarray = ctptr.cache_array_type
        if ctarray is None:
            from pypy.module._cffi_backend import newtype
            ctarray = newtype.new_array_type(space, ctptr, space.w_None)
            ctptr.cache_array_type = ctarray
        #
        ptr = self.unsafe_escaping_ptr()
        ptr = rffi.ptradd(ptr, start * ctarray.ctitem.size)
        return W_CDataSliced(space, ptr, ctarray, length)

    def _do_setslice(self, w_slice, w_value, ptr):
        ctptr, start, length = self._do_getslicearg(w_slice)
        ctitem = ctptr.ctitem
        ctitemsize = ctitem.size
        target = rffi.ptradd(ptr, start * ctitemsize)
        #
        if isinstance(w_value, W_CData):
            from pypy.module._cffi_backend import ctypearray
            ctv = w_value.ctype
            if (isinstance(ctv, ctypearray.W_CTypeArray) and
                ctv.ctitem is ctitem and
                w_value.get_array_length() == length):
                # fast path: copying from exactly the correct type
                with w_value as source:
                    source = rffi.cast(rffi.VOIDP, source)
                    target = rffi.cast(rffi.VOIDP, target)
                    size = rffi.cast(rffi.SIZE_T, ctitemsize * length)
                    rffi.c_memcpy(target, source, size)
                return
        #
        # A fast path for <char[]>[0:N] = "somestring" or some bytearray.
        from pypy.module._cffi_backend import ctypeprim
        space = self.space
        if isinstance(ctitem, ctypeprim.W_CTypePrimitive) and ctitem.size == 1:
            if space.isinstance_w(w_value, space.w_bytes):
                from rpython.rtyper.annlowlevel import llstr
                from rpython.rtyper.lltypesystem.rstr import copy_string_to_raw
                value = space.bytes_w(w_value)
                if len(value) != length:
                    raise oefmt(space.w_ValueError,
                                "need a string of length %d, got %d",
                                length, len(value))
                copy_string_to_raw(llstr(value), target, 0, length)
                return
            if space.isinstance_w(w_value, space.w_bytearray):
                value = w_value.bytearray_list_of_chars_w(space)
                if len(value) != length:
                    raise oefmt(space.w_ValueError,
                                "need a bytearray of length %d, got %d",
                                length, len(value))
                self._copy_list_of_chars_to_raw(value, target, length)
                return
        #
        self._do_setslice_iterate(space, ctitem, w_value, target, ctitemsize,
                                  length)

    @staticmethod
    def _do_setslice_iterate(space, ctitem, w_value, target, ctitemsize,
                             length):
        # general case, contains a loop
        # (XXX is it worth adding a jitdriver here?)
        w_iter = space.iter(w_value)
        for i in range(length):
            try:
                w_item = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise
                raise oefmt(space.w_ValueError,
                            "need %d values to unpack, got %d", length, i)
            ctitem.convert_from_object(target, w_item)
            target = rffi.ptradd(target, ctitemsize)
        try:
            space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
        else:
            raise oefmt(space.w_ValueError,
                        "got more than %d values to unpack", length)

    @staticmethod
    def _copy_list_of_chars_to_raw(value, target, length):
        # contains a loop, moved out of _do_setslice()
        for i in range(length):
            target[i] = value[i]

    def _add_or_sub(self, w_other, sign):
        space = self.space
        i = sign * space.getindex_w(w_other, space.w_OverflowError)
        ptr = self.unsafe_escaping_ptr()
        return self.ctype.add(ptr, i)

    def add(self, w_other):
        return self._add_or_sub(w_other, +1)

    def sub(self, w_other):
        space = self.space
        if isinstance(w_other, W_CData):
            from pypy.module._cffi_backend import ctypeptr, ctypearray
            ct = w_other.ctype
            if isinstance(ct, ctypearray.W_CTypeArray):
                ct = ct.ctptr
            #
            if (ct is not self.ctype or
                   not isinstance(ct, ctypeptr.W_CTypePointer) or
                   (ct.ctitem.size <= 0 and not ct.is_void_ptr)):
                raise oefmt(space.w_TypeError,
                            "cannot subtract cdata '%s' and cdata '%s'",
                            self.ctype.name, ct.name)
            #
            itemsize = ct.ctitem.size
            with self as ptr1, w_other as ptr2:
                diff = (rffi.cast(lltype.Signed, ptr1) -
                        rffi.cast(lltype.Signed, ptr2))
            if itemsize > 1:
                if diff % itemsize:
                    raise oefmt(space.w_ValueError,
                        "pointer subtraction: the distance between the two "
                        "pointers is not a multiple of the item size")
                diff //= itemsize
            return space.newint(diff)
        #
        return self._add_or_sub(w_other, -1)

    def getcfield(self, w_attr, mode):
        space = self.space
        attr = space.text_w(w_attr)
        try:
            cfield = self.ctype.getcfield(attr)
        except KeyError:
            raise oefmt(space.w_AttributeError, "cdata '%s' has no field '%s'",
                        self.ctype.name, attr)
        if cfield is None:
            raise oefmt(space.w_AttributeError,
                        "cdata '%s' points to an opaque type: cannot %s fields",
                        self.ctype.name, mode)
        return cfield

    def getattr(self, w_attr):
        cfield = self.getcfield(w_attr, mode="read")
        with self as ptr:
            w_res = cfield.read(ptr, self)
        return w_res

    def setattr(self, w_attr, w_value):
        cfield = self.getcfield(w_attr, mode="write")
        with self as ptr:
            cfield.write(ptr, w_value)

    def call(self, args_w):
        with self as ptr:
            w_result = self.ctype.call(ptr, args_w)
        return w_result

    def iter(self):
        return self.ctype.iter(self)

    def unpackiterable_int(self, space):
        from pypy.module._cffi_backend import ctypearray
        ctype = self.ctype
        if isinstance(ctype, ctypearray.W_CTypeArray):
            length = self.get_array_length()
            with self as ptr:
                return ctype.ctitem.unpack_list_of_int_items(ptr, length)
        return None

    def unpackiterable_float(self, space):
        from pypy.module._cffi_backend import ctypearray
        ctype = self.ctype
        if isinstance(ctype, ctypearray.W_CTypeArray):
            length = self.get_array_length()
            with self as ptr:
                return ctype.ctitem.unpack_list_of_float_items(ptr, length)
        return None

    @specialize.argtype(1)
    def write_raw_signed_data(self, source):
        with self as ptr:
            misc.write_raw_signed_data(ptr, source, self.ctype.size)

    @specialize.argtype(1)
    def write_raw_unsigned_data(self, source):
        with self as ptr:
            misc.write_raw_unsigned_data(ptr, source, self.ctype.size)

    def write_raw_float_data(self, source):
        with self as ptr:
            misc.write_raw_float_data(ptr, source, self.ctype.size)

    def write_raw_complex_data(self, real, imag):
        with self as ptr:
            halfsize = self.ctype.size >> 1
            ptr2 = rffi.ptradd(ptr, halfsize)
            misc.write_raw_float_data(ptr, real, halfsize)
            misc.write_raw_float_data(ptr2, imag, halfsize)

    def convert_to_object(self):
        with self as ptr:
            w_obj = self.ctype.convert_to_object(ptr)
        return w_obj

    def get_array_length(self):
        from pypy.module._cffi_backend import ctypearray
        ctype = self.ctype
        assert isinstance(ctype, ctypearray.W_CTypeArray)
        length = ctype.length
        assert length >= 0
        return length

    def _sizeof(self):
        return self.ctype.size

    def with_gc(self, w_destructor, size=0):
        space = self.space
        if space.is_none(w_destructor):
            if isinstance(self, W_CDataGCP):
                self.detach_destructor()
                w_res = space.w_None
            else:
                raise oefmt(space.w_TypeError,
                            "Can remove destructor only on a object "
                            "previously returned by ffi.gc()")
        else:
            with self as ptr:
                w_res = W_CDataGCP(space, ptr, self.ctype, self, w_destructor)
        if size != 0:
            if isinstance(w_res, W_CDataGCP):
                rgc.add_memory_pressure(size, w_res)
            else:
                rgc.add_memory_pressure(size, self)
        return w_res

    def unpack(self, length):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePtrOrArray
        space = self.space
        if not self.ctype.is_nonfunc_pointer_or_array:
            raise oefmt(space.w_TypeError,
                        "expected a pointer or array, got '%s'",
                        self.ctype.name)
        if length < 0:
            raise oefmt(space.w_ValueError, "'length' cannot be negative")
        ctype = self.ctype
        assert isinstance(ctype, W_CTypePtrOrArray)
        with self as ptr:
            if not ptr:
                raise oefmt(space.w_RuntimeError,
                            "cannot use unpack() on %R",
                            self)
            w_result = ctype.ctitem.unpack_ptr(ctype, ptr, length)
        return w_result

    def dir(self, space):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePointer
        ct = self.ctype
        if isinstance(ct, W_CTypePointer):
            ct = ct.ctitem
        lst = ct.cdata_dir()
        return space.newlist([space.newtext(s) for s in lst])

    def get_structobj(self):
        return None

    def enter_exit(self, exit_now):
        raise oefmt(self.space.w_ValueError,
            "only 'cdata' object from ffi.new(), ffi.gc(), ffi.from_buffer() "
            "or ffi.new_allocator()() can be used with the 'with' keyword or "
            "ffi.release()")

    def descr_enter(self):
        self.enter_exit(False)
        return self

    def descr_exit(self, args_w):
        self.enter_exit(True)


class W_CDataMem(W_CData):
    """This is used only by the results of cffi.cast('int', x)
    or other primitive explicitly-casted types."""
    _attrs_ = []

    def __init__(self, space, ctype):
        cdata = lltype.malloc(rffi.CCHARP.TO, ctype.size, flavor='raw',
                              zero=False)
        W_CData.__init__(self, space, cdata, ctype)

    @rgc.must_be_light_finalizer
    def __del__(self):
        lltype.free(self._ptr, flavor='raw')


class W_CDataNewOwning(W_CData):
    """This is the abstract base class used for cdata objects created
    by newp().  They create and free their own memory according to an
    allocator."""

    # the 'allocated_length' is >= 0 for arrays; for var-sized
    # structures it is the total size in bytes; otherwise it is -1.
    _attrs_ = ['allocated_length']
    _immutable_fields_ = ['allocated_length']

    def __init__(self, space, cdata, ctype, length=-1):
        W_CData.__init__(self, space, cdata, ctype)
        self.allocated_length = length

    def _repr_extra(self):
        return self._repr_extra_owning()

    def _sizeof(self):
        ctype = self.ctype
        if self.allocated_length >= 0:
            from pypy.module._cffi_backend import ctypearray
            if isinstance(ctype, ctypearray.W_CTypeArray):
                return self.allocated_length * ctype.ctitem.size
            else:
                return self.allocated_length    # var-sized struct size
        else:
            return ctype.size

    def get_array_length(self):
        from pypy.module._cffi_backend import ctypearray
        assert isinstance(self.ctype, ctypearray.W_CTypeArray)
        return self.allocated_length

    def get_structobj(self):
        return self

    def enter_exit(self, exit_now):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePtrOrArray
        if not isinstance(self.ctype, W_CTypePtrOrArray):
            W_CData.enter_exit(self, exit_now)
        elif exit_now:
            self._do_exit()

    def _do_exit(self):
        raise NotImplementedError


class W_CDataNewStd(W_CDataNewOwning):
    """Subclass using the standard allocator, lltype.malloc()/lltype.free()"""
    _attrs_ = ['explicitly_freed']
    explicitly_freed = False

    @rgc.must_be_light_finalizer
    def __del__(self):
        if not self.explicitly_freed:
            lltype.free(self._ptr, flavor='raw')

    def _do_exit(self):
        if not self.explicitly_freed:
            rgc.add_memory_pressure(-self._sizeof(), self)
            self.explicitly_freed = True
            rgc.may_ignore_finalizer(self)
            lltype.free(self._ptr, flavor='raw')


class W_CDataNewNonStd(W_CDataNewOwning):
    """Subclass using a non-standard allocator"""
    _attrs_ = ['w_raw_cdata', 'w_free']

    def _finalize_(self):
        if self.w_free is not None:
            self.space.call_function(self.w_free, self.w_raw_cdata)

    def _do_exit(self):
        w_free = self.w_free
        if w_free is not None:
            rgc.add_memory_pressure(-self._sizeof(), self)
            self.w_free = None
            self.may_unregister_rpython_finalizer(self.space)
            self.space.call_function(w_free, self.w_raw_cdata)


class W_CDataPtrToStructOrUnion(W_CData):
    """This subclass is used for the pointer returned by new('struct foo *').
    It has a strong reference to a W_CDataNewOwning that really owns the
    struct, which is the object returned by the app-level expression 'p[0]'.
    But it is not itself owning any memory, although its repr says so;
    it is merely a co-owner."""
    _attrs_ = ['structobj']
    _immutable_fields_ = ['structobj']

    def __init__(self, space, cdata, ctype, structobj):
        W_CData.__init__(self, space, cdata, ctype)
        self.structobj = structobj

    def _repr_extra(self):
        return self.structobj._repr_extra_owning()

    def _do_getitem(self, ctype, i):
        assert i == 0
        return self.structobj

    def get_structobj(self):
        structobj = self.structobj
        if isinstance(structobj, W_CDataNewOwning):
            return structobj
        else:
            return None

    def enter_exit(self, exit_now):
        if exit_now:
            structobj = self.structobj
            if isinstance(structobj, W_CDataNewOwning):
                structobj._do_exit()


class W_CDataSliced(W_CData):
    """Subclass with an explicit length, for slices."""
    _attrs_ = ['length']
    _immutable_fields_ = ['length']

    def __init__(self, space, cdata, ctype, length):
        W_CData.__init__(self, space, cdata, ctype)
        self.length = length

    def _repr_extra(self):
        return "sliced length %d" % (self.length,)

    def get_array_length(self):
        return self.length

    def _sizeof(self):
        from pypy.module._cffi_backend.ctypeptr import W_CTypePtrOrArray
        ctype = self.ctype
        assert isinstance(ctype, W_CTypePtrOrArray)
        return self.length * ctype.ctitem.size


class W_CDataHandle(W_CData):
    _attrs_ = ['w_keepalive']
    _immutable_fields_ = ['w_keepalive']

    def __init__(self, space, cdata, ctype, w_keepalive):
        W_CData.__init__(self, space, cdata, ctype)
        self.w_keepalive = w_keepalive

    def _repr_extra(self):
        w_repr = self.space.repr(self.w_keepalive)
        return "handle to %s" % (self.space.text_w(w_repr),)


class W_CDataFromBuffer(W_CData):
    _attrs_ = ['buf', 'length', 'w_keepalive']
    _immutable_fields_ = ['buf', 'length']

    def __init__(self, space, cdata, length, ctype, buf, w_object):
        W_CData.__init__(self, space, cdata, ctype)
        self.buf = buf
        self.length = length
        self.w_keepalive = w_object

    def get_array_length(self):
        return self.length

    def _sizeof(self):
        from pypy.module._cffi_backend import ctypearray
        ctype = self.ctype
        if isinstance(ctype, ctypearray.W_CTypeArray):
            return self.length * ctype.ctitem.size
        else:
            return W_CData._sizeof(self)

    def _repr_extra(self):
        from pypy.module._cffi_backend import ctypearray
        if self.w_keepalive is None:
            return "buffer RELEASED"
        obj_tp_name = self.space.type(self.w_keepalive).name
        if isinstance(self.ctype, ctypearray.W_CTypeArray):
            return "buffer len %d from '%s' object" % (self.length, obj_tp_name)
        else:
            return "buffer from '%s' object" % (obj_tp_name,)

    def enter_exit(self, exit_now):
        # for now, limited effect on PyPy
        if exit_now:
            self.w_keepalive = None


class W_CDataGCP(W_CData):
    """For ffi.gc()."""
    _attrs_ = ['w_original_cdata', 'w_destructor']
    _immutable_fields_ = ['w_original_cdata']

    def __init__(self, space, cdata, ctype, w_original_cdata, w_destructor):
        W_CData.__init__(self, space, cdata, ctype)
        self.w_original_cdata = w_original_cdata
        self.w_destructor = w_destructor
        self.register_finalizer(space)

    def _finalize_(self):
        self.invoke_finalizer()

    def invoke_finalizer(self):
        w_destructor = self.w_destructor
        if w_destructor is not None:
            self.w_destructor = None
            self.space.call_function(w_destructor, self.w_original_cdata)

    def detach_destructor(self):
        self.w_destructor = None
        self.may_unregister_rpython_finalizer(self.space)

    def enter_exit(self, exit_now):
        if exit_now:
            self.may_unregister_rpython_finalizer(self.space)
            self.invoke_finalizer()


W_CData.typedef = TypeDef(
    '_cffi_backend._CDataBase',
    __doc__ = "The internal base type for CData objects.  Use FFI.CData to "
              "access it.  Always check with isinstance(): subtypes are "
              "sometimes returned on CPython, for performance reasons.",
    __module__ = '_cffi_backend',   # attribute also visible on instances
    __name__ = '<cdata>',           # attribute also visible on instances
    __repr__ = interp2app(W_CData.repr),
    __bool__ = interp2app(W_CData.bool),
    __int__ = interp2app(W_CData.int),
    __float__ = interp2app(W_CData.float),
    __complex__ = interp2app(W_CData.complex),
    __len__ = interp2app(W_CData.len),
    __lt__ = interp2app(W_CData.lt),
    __le__ = interp2app(W_CData.le),
    __eq__ = interp2app(W_CData.eq),
    __ne__ = interp2app(W_CData.ne),
    __gt__ = interp2app(W_CData.gt),
    __ge__ = interp2app(W_CData.ge),
    __hash__ = interp2app(W_CData.hash),
    __getitem__ = interp2app(W_CData.getitem),
    __setitem__ = interp2app(W_CData.setitem),
    __add__ = interp2app(W_CData.add),
    __radd__ = interp2app(W_CData.add),
    __sub__ = interp2app(W_CData.sub),
    __getattr__ = interp2app(W_CData.getattr),
    __setattr__ = interp2app(W_CData.setattr),
    __call__ = interp2app(W_CData.call),
    __iter__ = interp2app(W_CData.iter),
    __weakref__ = make_weakref_descr(W_CData),
    __dir__ = interp2app(W_CData.dir),
    __enter__ = interp2app(W_CData.descr_enter),
    __exit__ = interp2app(W_CData.descr_exit),
    )
W_CData.typedef.acceptable_as_base_class = False
