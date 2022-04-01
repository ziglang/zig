from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.objspace.std.bytesobject import W_BytesObject
from pypy.objspace.std.complexobject import W_ComplexObject
from pypy.objspace.std.floatobject import W_FloatObject
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.unicodeobject import W_UnicodeObject
from rpython.rlib.rarithmetic import LONG_BIT
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.objectmodel import specialize
from rpython.rlib import jit
from rpython.rlib.rutf8 import codepoints_in_utf8
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.tool.sourcetools import func_with_new_name
from pypy.module.micronumpy import constants as NPY
from pypy.module.micronumpy.base import W_NDimArray, W_NumpyObject
from pypy.module.micronumpy.concrete import VoidBoxStorage
from pypy.module.micronumpy.flagsobj import W_FlagsObject
from pypy.module.micronumpy import support

MIXIN_32 = (W_IntObject.typedef,) if LONG_BIT == 32 else ()
MIXIN_64 = (W_IntObject.typedef,) if LONG_BIT == 64 else ()

#long_double_size = rffi.sizeof_c_type('long double', ignore_errors=True)
#import os
#if long_double_size == 8 and os.name == 'nt':
#    # this is a lie, or maybe a wish, MS fakes longdouble math with double
#    long_double_size = 12

# hardcode to 8 for now (simulate using normal double) until long double works
long_double_size = 8



def new_dtype_getter(num):
    @specialize.memo()
    def _get_dtype(space):
        from pypy.module.micronumpy.descriptor import num2dtype
        return num2dtype(space, num)

    def descr__new__(space, w_subtype, w_value=None):
        from pypy.module.micronumpy.ctors import array
        dtype = _get_dtype(space)
        if not space.is_none(w_value):
            w_arr = array(space, w_value, dtype, copy=False)
            if len(w_arr.get_shape()) != 0:
                return w_arr
            w_value = w_arr.get_scalar_value().item(space)
        return dtype.itemtype.coerce_subtype(space, w_subtype, w_value)

    def descr_reduce(self, space):
        return self.reduce(space)

    return (func_with_new_name(descr__new__, 'descr__new__%d' % num),
            staticmethod(_get_dtype),
            descr_reduce)


class Box(object):
    _mixin_ = True

    def reduce(self, space):
        _numpypy = space.getbuiltinmodule("_numpypy")
        assert isinstance(_numpypy, MixedModule)
        multiarray = _numpypy.get("multiarray")
        assert isinstance(multiarray, MixedModule)
        scalar = multiarray.get("scalar")

        ret = space.newtuple([scalar, space.newtuple(
            [self._get_dtype(space), space.newtext(self.raw_str())])])
        return ret


class PrimitiveBox(Box):
    _mixin_ = True
    _immutable_fields_ = ['value']

    def __init__(self, value):
        self.value = value

    def convert_to(self, space, dtype):
        return dtype.box(self.value)

    def __repr__(self):
        return '%s(%s)' % (self.__class__.__name__, self.value)

    def raw_str(self):
        value = lltype.malloc(rffi.CArray(lltype.typeOf(self.value)), 1, flavor="raw")
        value[0] = self.value

        builder = StringBuilder()
        builder.append_charpsize(rffi.cast(rffi.CCHARP, value),
                                 rffi.sizeof(lltype.typeOf(self.value)))
        ret = builder.build()

        lltype.free(value, flavor="raw")
        return ret


class ComplexBox(Box):
    _mixin_ = True
    _immutable_fields_ = ['real', 'imag']

    def __init__(self, real, imag=0.):
        self.real = real
        self.imag = imag

    def convert_to(self, space, dtype):
        return dtype.box_complex(self.real, self.imag)

    def convert_real_to(self, dtype):
        return dtype.box(self.real)

    def convert_imag_to(self, dtype):
        return dtype.box(self.imag)

    def raw_str(self):
        value = lltype.malloc(rffi.CArray(lltype.typeOf(self.real)), 2, flavor="raw")
        value[0] = self.real
        value[1] = self.imag

        builder = StringBuilder()
        builder.append_charpsize(rffi.cast(rffi.CCHARP, value),
                                 rffi.sizeof(lltype.typeOf(self.real)) * 2)
        ret = builder.build()

        lltype.free(value, flavor="raw")
        return ret


class W_GenericBox(W_NumpyObject):
    _attrs_ = ['w_flags']

    def descr__new__(space, w_subtype, __args__):
        raise oefmt(space.w_TypeError,
                    "cannot create '%N' instances", w_subtype)

    def get_dtype(self, space):
        return self._get_dtype(space)

    def is_scalar(self):
        return True

    def get_scalar_value(self):
        return self

    def get_flags(self):
        return (NPY.ARRAY_C_CONTIGUOUS | NPY.ARRAY_F_CONTIGUOUS |
                NPY.ARRAY_ALIGNED | NPY.ARRAY_OWNDATA)

    def item(self, space):
        return self.get_dtype(space).itemtype.to_builtin_type(space, self)

    def descr_item(self, space, args_w):
        if len(args_w) == 1 and space.isinstance_w(args_w[0], space.w_tuple):
            args_w = space.fixedview(args_w[0])
        if len(args_w) > 1:
            raise oefmt(space.w_ValueError,
                        "incorrect number of indices for array")
        elif len(args_w) == 1:
            try:
                idx = support.index_w(space, args_w[0])
            except OperationError:
                raise oefmt(space.w_TypeError, "an integer is required")
            if idx != 0:
                raise oefmt(space.w_IndexError,
                            "index %d is out of bounds for size 1", idx)
        return self.item(space)

    def descr_transpose(self, space, args_w):
        if len(args_w) == 1 and space.isinstance_w(args_w[0], space.w_tuple):
            args_w = space.fixedview(args_w[0])
        if len(args_w) >= 1:
            for w_arg in args_w:
                try:
                    support.index_w(space, w_arg)
                except OperationError:
                    raise oefmt(space.w_TypeError, "an integer is required")
            raise oefmt(space.w_ValueError, "axes don't match array")
        return self

    def descr_getitem(self, space, w_item):
        from pypy.module.micronumpy.base import convert_to_array
        if space.is_w(w_item, space.w_Ellipsis):
            return convert_to_array(space, self)
        elif (space.isinstance_w(w_item, space.w_tuple) and
                    space.len_w(w_item) == 0):
            return self
        raise oefmt(space.w_IndexError, "invalid index to scalar variable")

    def descr_iter(self, space):
        # Making numpy scalar non-iterable with a valid __getitem__ method
        raise oefmt(space.w_TypeError,
                    "'%T' object is not iterable", self)

    def descr_str(self, space):
        tp = self.get_dtype(space).itemtype
        return space.newtext(tp.str_format(self, add_quotes=False))

    def descr_repr(self, space):
        tp = self.get_dtype(space).itemtype
        return space.newtext(tp.str_format(self, add_quotes=True))

    def descr_format(self, space, w_spec):
        return space.format(self.item(space), w_spec)

    def descr_hash(self, space):
        return space.hash(self.item(space))

    def descr___array_priority__(self, space):
        return space.newfloat(0.0)

    def descr_index(self, space):
        return space.index(self.item(space))

    def descr_int(self, space):
        if isinstance(self, W_ComplexFloatingBox):
            box = self.descr_get_real(space)
        else:
            box = self
        return space.call_function(space.w_int, box.item(space))

    def descr_float(self, space):
        if isinstance(self, W_ComplexFloatingBox):
            box = self.descr_get_real(space)
        else:
            box = self
        return space.call_function(space.w_float, box.item(space))

    def descr_oct(self, space):
        return space.call_method(space.builtin, 'oct', self.descr_int(space))

    def descr_hex(self, space):
        return space.call_method(space.builtin, 'hex', self.descr_int(space))

    def descr_nonzero(self, space):
        return space.newbool(self.get_dtype(space).itemtype.bool(self))

    # TODO: support all kwargs in ufuncs like numpy ufunc_object.c
    sig = None
    cast = 'unsafe'
    extobj = None

    def _unaryop_impl(ufunc_name):
        def impl(self, space, w_out=None):
            from pypy.module.micronumpy import ufuncs
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [self, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "unaryop_%s_impl" % ufunc_name)

    def _binop_impl(ufunc_name):
        def impl(self, space, w_other, w_out=None):
            from pypy.module.micronumpy import ufuncs
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [self, w_other, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "binop_%s_impl" % ufunc_name)

    def _binop_right_impl(ufunc_name):
        def impl(self, space, w_other, w_out=None):
            from pypy.module.micronumpy import ufuncs
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [w_other, self, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "binop_right_%s_impl" % ufunc_name)

    descr_add = _binop_impl("add")
    descr_sub = _binop_impl("subtract")
    descr_mul = _binop_impl("multiply")
    descr_div = _binop_impl("divide")
    descr_truediv = _binop_impl("true_divide")
    descr_floordiv = _binop_impl("floor_divide")
    descr_mod = _binop_impl("mod")
    descr_pow = _binop_impl("power")
    descr_lshift = _binop_impl("left_shift")
    descr_rshift = _binop_impl("right_shift")
    descr_and = _binop_impl("bitwise_and")
    descr_or = _binop_impl("bitwise_or")
    descr_xor = _binop_impl("bitwise_xor")

    descr_eq = _binop_impl("equal")
    descr_ne = _binop_impl("not_equal")
    descr_lt = _binop_impl("less")
    descr_le = _binop_impl("less_equal")
    descr_gt = _binop_impl("greater")
    descr_ge = _binop_impl("greater_equal")

    descr_radd = _binop_right_impl("add")
    descr_rsub = _binop_right_impl("subtract")
    descr_rmul = _binop_right_impl("multiply")
    descr_rdiv = _binop_right_impl("divide")
    descr_rtruediv = _binop_right_impl("true_divide")
    descr_rfloordiv = _binop_right_impl("floor_divide")
    descr_rmod = _binop_right_impl("mod")
    descr_rpow = _binop_right_impl("power")
    descr_rlshift = _binop_right_impl("left_shift")
    descr_rrshift = _binop_right_impl("right_shift")
    descr_rand = _binop_right_impl("bitwise_and")
    descr_ror = _binop_right_impl("bitwise_or")
    descr_rxor = _binop_right_impl("bitwise_xor")

    descr_pos = _unaryop_impl("positive")
    descr_neg = _unaryop_impl("negative")
    descr_abs = _unaryop_impl("absolute")
    descr_invert = _unaryop_impl("invert")
    descr_conjugate = _unaryop_impl("conjugate")

    def descr_divmod(self, space, w_other):
        w_quotient = self.descr_div(space, w_other)
        w_remainder = self.descr_mod(space, w_other)
        return space.newtuple([w_quotient, w_remainder])

    def descr_rdivmod(self, space, w_other):
        w_quotient = self.descr_rdiv(space, w_other)
        w_remainder = self.descr_rmod(space, w_other)
        return space.newtuple([w_quotient, w_remainder])

    def descr_any(self, space):
        from pypy.module.micronumpy.descriptor import get_dtype_cache
        value = space.is_true(self)
        return get_dtype_cache(space).w_booldtype.box(value)

    def descr_all(self, space):
        from pypy.module.micronumpy.descriptor import get_dtype_cache
        value = space.is_true(self)
        return get_dtype_cache(space).w_booldtype.box(value)

    def descr_zero(self, space):
        from pypy.module.micronumpy.descriptor import get_dtype_cache
        return get_dtype_cache(space).w_longdtype.box(0)

    def descr_ravel(self, space):
        from pypy.module.micronumpy.base import convert_to_array
        w_values = space.newtuple([self])
        return convert_to_array(space, w_values)

    @unwrap_spec(decimals=int)
    def descr_round(self, space, decimals=0, w_out=None):
        if not space.is_none(w_out):
            raise oefmt(space.w_NotImplementedError, "out not supported")
        return self.get_dtype(space).itemtype.round(self, decimals)

    def descr_astype(self, space, w_dtype):
        from pypy.module.micronumpy.descriptor import W_Dtype
        dtype = space.interp_w(W_Dtype,
            space.call_function(space.gettypefor(W_Dtype), w_dtype))
        return self.convert_to(space, dtype)

    def descr_view(self, space, w_dtype):
        from pypy.module.micronumpy.descriptor import W_Dtype
        try:
            subclass = space.issubtype_w(w_dtype,
                                         space.gettypefor(W_NDimArray))
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                subclass = False
            else:
                raise
        if subclass:
            dtype = self.get_dtype(space)
        else:
            dtype = space.interp_w(W_Dtype,
                space.call_function(space.gettypefor(W_Dtype), w_dtype))
            if dtype.elsize == 0:
                raise oefmt(space.w_TypeError, "data-type must not be 0-sized")
            if dtype.elsize != self.get_dtype(space).elsize:
                raise oefmt(space.w_ValueError,
                            "new type not compatible with array.")
        if dtype.is_record():
            raise oefmt(space.w_NotImplementedError,
                        "viewing scalar as record not implemented")
        else:
            return dtype.runpack_str(space, self.raw_str())

    def descr_self(self, space):
        return self

    def descr_get_dtype(self, space):
        return self.get_dtype(space)

    def descr_get_size(self, space):
        return space.newint(1)

    def descr_get_itemsize(self, space):
        return space.newint(self.get_dtype(space).elsize)

    def descr_get_shape(self, space):
        return space.newtuple([])

    def descr_get_ndim(self, space):
        return space.newint(0)

    def descr_copy(self, space):
        return self.convert_to(space, self.get_dtype(space))

    def buffer_w(self, space, flags):
        return self.descr_ravel(space).buffer_w(space, flags)

    def descr_byteswap(self, space):
        return self.get_dtype(space).itemtype.byteswap(self)

    def descr_tostring(self, space, __args__):
        w_meth = space.getattr(self.descr_ravel(space), space.newtext('tostring'))
        return space.call_args(w_meth, __args__)

    def descr_reshape(self, space, __args__):
        w_meth = space.getattr(self.descr_ravel(space), space.newtext('reshape'))
        w_res = space.call_args(w_meth, __args__)
        if isinstance(w_res, W_NDimArray) and len(w_res.get_shape()) == 0:
            return w_res.get_scalar_value()
        return w_res

    def descr_nd_nonzero(self, space, __args__):
        w_meth = space.getattr(self.descr_ravel(space), space.newtext('nonzero'))
        return space.call_args(w_meth, __args__)

    def descr_get_real(self, space):
        return self.get_dtype(space).itemtype.real(self)

    def descr_get_imag(self, space):
        return self.get_dtype(space).itemtype.imag(self)

    w_flags = None

    def descr_get_flags(self, space):
        if self.w_flags is None:
            self.w_flags = W_FlagsObject(self)
        return self.w_flags

    @unwrap_spec(axis1=int, axis2=int)
    def descr_swapaxes(self, space, axis1, axis2):
        raise oefmt(space.w_ValueError, 'bad axis1 argument to swapaxes')

    def descr_fill(self, space, w_value):
        self.get_dtype(space).coerce(space, w_value)

class W_BoolBox(W_GenericBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.BOOL)

class W_NumberBox(W_GenericBox):
    pass

class W_IntegerBox(W_NumberBox):
    def _int_w(self, space):
        return space.int_w(self.descr_int(space))

class W_SignedIntegerBox(W_IntegerBox):
    pass

class W_UnsignedIntegerBox(W_IntegerBox):
    pass

class W_Int8Box(W_SignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.BYTE)

class W_UInt8Box(W_UnsignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.UBYTE)

class W_Int16Box(W_SignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.SHORT)

class W_UInt16Box(W_UnsignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.USHORT)

class W_Int32Box(W_SignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.INT)

class W_UInt32Box(W_UnsignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.UINT)

class W_LongBox(W_SignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.LONG)

class W_ULongBox(W_UnsignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.ULONG)

class W_Int64Box(W_SignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.LONGLONG)

class W_UInt64Box(W_UnsignedIntegerBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.ULONGLONG)

class W_InexactBox(W_NumberBox):
    pass

class W_FloatingBox(W_InexactBox):
    pass

class W_Float16Box(W_FloatingBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.HALF)

class W_Float32Box(W_FloatingBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.FLOAT)

class W_Float64Box(W_FloatingBox, PrimitiveBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.DOUBLE)

    def descr_as_integer_ratio(self, space):
        return space.call_method(self.item(space), 'as_integer_ratio')

class W_ComplexFloatingBox(W_InexactBox):
    pass

class W_Complex64Box(ComplexBox, W_ComplexFloatingBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.CFLOAT)

class W_Complex128Box(ComplexBox, W_ComplexFloatingBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.CDOUBLE)

if long_double_size in (8, 12, 16):
    class W_FloatLongBox(W_FloatingBox, PrimitiveBox):
        descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.LONGDOUBLE)

    class W_ComplexLongBox(ComplexBox, W_ComplexFloatingBox):
        descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.CLONGDOUBLE)

class W_FlexibleBox(W_GenericBox):
    _attrs_ = ['arr', 'ofs', 'dtype']
    _immutable_fields_ = ['arr', 'ofs', 'dtype']

    def __init__(self, arr, ofs, dtype):
        self.arr = arr # we have to keep array alive
        self.ofs = ofs
        self.dtype = dtype

    def get_dtype(self, space):
        return self.dtype

    @jit.unroll_safe
    def raw_str(self):
        builder = StringBuilder()
        i = self.ofs
        end = i + self.dtype.elsize
        with self.arr as storage:
            while i < end:
                assert isinstance(storage[i], str)
                if storage[i] == '\x00':
                    break
                builder.append(storage[i])
                i += 1
            return builder.build()


class W_VoidBox(W_FlexibleBox):
    def descr_getitem(self, space, w_item):
        if space.isinstance_w(w_item, space.w_text):
            item = space.text_w(w_item)
        elif space.isinstance_w(w_item, space.w_bytes):
            item = space.bytes_w(w_item)   # XXX should it be supported?
        elif space.isinstance_w(w_item, space.w_int):
            indx = space.int_w(w_item)
            try:
                item = self.dtype.names[indx][0]
            except IndexError:
                if indx < 0:
                    indx += len(self.dtype.names)
                raise oefmt(space.w_IndexError, "invalid index (%d)", indx)
        else:
            raise oefmt(space.w_IndexError, "invalid index")
        try:
            ofs, dtype = self.dtype.fields[item]
        except KeyError:
            raise oefmt(space.w_ValueError, "no field of name %s", item)

        from pypy.module.micronumpy.types import VoidType
        if isinstance(dtype.itemtype, VoidType):
            read_val = dtype.itemtype.readarray(self.arr, self.ofs, ofs, dtype)
        else:
            read_val = dtype.read(self.arr, self.ofs, ofs)
        if isinstance (read_val, W_StringBox):
            # StringType returns a str
            return space.newbytes(dtype.itemtype.to_str(read_val))
        return read_val

    def descr_iter(self, space):
        return space.newseqiter(self)

    def descr_setitem(self, space, w_item, w_value):
        if space.isinstance_w(w_item, space.w_text):
            item = space.text_w(w_item)
        elif space.isinstance_w(w_item, space.w_bytes):
            item = space.bytes_w(w_item)   # XXX should it be supported?
        elif space.isinstance_w(w_item, space.w_int):
            indx = space.int_w(w_item)
            try:
                item = self.dtype.names[indx][0]
            except IndexError:
                if indx < 0:
                    indx += len(self.dtype.names)
                raise oefmt(space.w_IndexError, "invalid index (%d)", indx)
        else:
            raise oefmt(space.w_IndexError, "invalid index")
        try:
            ofs, dtype = self.dtype.fields[item]
        except KeyError:
            raise oefmt(space.w_IndexError, "only integers, slices (`:`), "
                "ellipsis (`...`), numpy.newaxis (`None`) and integer or "
                "boolean arrays are valid indices")
        dtype.store(self.arr, self.ofs, ofs,
                             dtype.coerce(space, w_value))

    def convert_to(self, space, dtype):
        # if we reach here, the record fields are guarenteed to match.
        return self

class W_CharacterBox(W_FlexibleBox):
    def convert_to(self, space, dtype):
        # XXX should be newbytes?
        return dtype.coerce(space, space.newtext(self.raw_str()))

    def descr_len(self, space):
        return space.len(self.item(space))

class W_StringBox(W_CharacterBox):
    def descr__new__string_box(space, w_subtype, w_arg):
        from pypy.module.micronumpy.descriptor import new_string_dtype
        arg = space.text_w(space.str(w_arg))
        arr = VoidBoxStorage(len(arg), new_string_dtype(space, len(arg)))
        for i in range(len(arg)):
            arr.storage[i] = arg[i]
        return W_StringBox(arr, 0, arr.dtype)

class W_UnicodeBox(W_CharacterBox):
    def __init__(self, value):
        self._value = value

    def convert_to(self, space, dtype):
        if dtype.is_unicode():
            return self
        elif dtype.is_object():
            return W_ObjectBox(space.newutf8(self._value,
                               codepoints_in_utf8(self._value)))
        else:
            raise oefmt(space.w_NotImplementedError,
                        "Conversion from unicode not implemented yet")

    def get_dtype(self, space):
        from pypy.module.micronumpy.descriptor import new_unicode_dtype
        return new_unicode_dtype(space, len(self._value))

    def descr__new__unicode_box(space, w_subtype, w_arg):
        value = space.utf8_w(space.unicode_from_object(w_arg))
        return W_UnicodeBox(value)

class W_ObjectBox(W_GenericBox):
    descr__new__, _get_dtype, descr_reduce = new_dtype_getter(NPY.OBJECT)

    def __init__(self, w_obj):
        self.w_obj = w_obj

    def convert_to(self, space, dtype):
        if dtype.is_bool():
            return W_BoolBox(space.bool_w(self.w_obj))
        return self # XXX

    def descr__getattr__(self, space, w_key):
        return space.getattr(self.w_obj, w_key)

W_GenericBox.typedef = TypeDef("numpy.generic", None, None, "read-write",
    __new__ = interp2app(W_GenericBox.descr__new__.im_func),

    __getitem__ = interp2app(W_GenericBox.descr_getitem),
    __iter__ = interp2app(W_GenericBox.descr_iter),
    __str__ = interp2app(W_GenericBox.descr_str),
    __repr__ = interp2app(W_GenericBox.descr_repr),
    __format__ = interp2app(W_GenericBox.descr_format),
    __int__ = interp2app(W_GenericBox.descr_int),
    __float__ = interp2app(W_GenericBox.descr_float),
    __bool__ = interp2app(W_GenericBox.descr_nonzero),
    __oct__ = interp2app(W_GenericBox.descr_oct),
    __hex__ = interp2app(W_GenericBox.descr_hex),

    __add__ = interp2app(W_GenericBox.descr_add),
    __sub__ = interp2app(W_GenericBox.descr_sub),
    __mul__ = interp2app(W_GenericBox.descr_mul),
    __div__ = interp2app(W_GenericBox.descr_div),
    __truediv__ = interp2app(W_GenericBox.descr_truediv),
    __floordiv__ = interp2app(W_GenericBox.descr_floordiv),
    __mod__ = interp2app(W_GenericBox.descr_mod),
    __divmod__ = interp2app(W_GenericBox.descr_divmod),
    __pow__ = interp2app(W_GenericBox.descr_pow),
    __lshift__ = interp2app(W_GenericBox.descr_lshift),
    __rshift__ = interp2app(W_GenericBox.descr_rshift),
    __and__ = interp2app(W_GenericBox.descr_and),
    __or__ = interp2app(W_GenericBox.descr_or),
    __xor__ = interp2app(W_GenericBox.descr_xor),

    __radd__ = interp2app(W_GenericBox.descr_radd),
    __rsub__ = interp2app(W_GenericBox.descr_rsub),
    __rmul__ = interp2app(W_GenericBox.descr_rmul),
    __rdiv__ = interp2app(W_GenericBox.descr_rdiv),
    __rtruediv__ = interp2app(W_GenericBox.descr_rtruediv),
    __rfloordiv__ = interp2app(W_GenericBox.descr_rfloordiv),
    __rmod__ = interp2app(W_GenericBox.descr_rmod),
    __rdivmod__ = interp2app(W_GenericBox.descr_rdivmod),
    __rpow__ = interp2app(W_GenericBox.descr_rpow),
    __rlshift__ = interp2app(W_GenericBox.descr_rlshift),
    __rrshift__ = interp2app(W_GenericBox.descr_rrshift),
    __rand__ = interp2app(W_GenericBox.descr_rand),
    __ror__ = interp2app(W_GenericBox.descr_ror),
    __rxor__ = interp2app(W_GenericBox.descr_rxor),

    __eq__ = interp2app(W_GenericBox.descr_eq),
    __ne__ = interp2app(W_GenericBox.descr_ne),
    __lt__ = interp2app(W_GenericBox.descr_lt),
    __le__ = interp2app(W_GenericBox.descr_le),
    __gt__ = interp2app(W_GenericBox.descr_gt),
    __ge__ = interp2app(W_GenericBox.descr_ge),

    __pos__ = interp2app(W_GenericBox.descr_pos),
    __neg__ = interp2app(W_GenericBox.descr_neg),
    __abs__ = interp2app(W_GenericBox.descr_abs),
    __invert__ = interp2app(W_GenericBox.descr_invert),

    __hash__ = interp2app(W_GenericBox.descr_hash),

    __array_priority__ = GetSetProperty(W_GenericBox.descr___array_priority__),

    tolist = interp2app(W_GenericBox.item),
    item = interp2app(W_GenericBox.descr_item),
    transpose = interp2app(W_GenericBox.descr_transpose),
    min = interp2app(W_GenericBox.descr_self),
    max = interp2app(W_GenericBox.descr_self),
    argmin = interp2app(W_GenericBox.descr_zero),
    argmax = interp2app(W_GenericBox.descr_zero),
    sum = interp2app(W_GenericBox.descr_self),
    prod = interp2app(W_GenericBox.descr_self),
    any = interp2app(W_GenericBox.descr_any),
    all = interp2app(W_GenericBox.descr_all),
    ravel = interp2app(W_GenericBox.descr_ravel),
    round = interp2app(W_GenericBox.descr_round),
    conjugate = interp2app(W_GenericBox.descr_conjugate),
    conj = interp2app(W_GenericBox.descr_conjugate),
    astype = interp2app(W_GenericBox.descr_astype),
    view = interp2app(W_GenericBox.descr_view),
    squeeze = interp2app(W_GenericBox.descr_self),
    copy = interp2app(W_GenericBox.descr_copy),
    byteswap = interp2app(W_GenericBox.descr_byteswap),
    tostring = interp2app(W_GenericBox.descr_tostring),
    tobytes = interp2app(W_GenericBox.descr_tostring),
    reshape = interp2app(W_GenericBox.descr_reshape),
    swapaxes = interp2app(W_GenericBox.descr_swapaxes),
    nonzero = interp2app(W_GenericBox.descr_nd_nonzero),
    fill = interp2app(W_GenericBox.descr_fill),

    dtype = GetSetProperty(W_GenericBox.descr_get_dtype),
    size = GetSetProperty(W_GenericBox.descr_get_size),
    itemsize = GetSetProperty(W_GenericBox.descr_get_itemsize),
    nbytes = GetSetProperty(W_GenericBox.descr_get_itemsize),
    shape = GetSetProperty(W_GenericBox.descr_get_shape),
    strides = GetSetProperty(W_GenericBox.descr_get_shape),
    ndim = GetSetProperty(W_GenericBox.descr_get_ndim),
    T = GetSetProperty(W_GenericBox.descr_self),
    real = GetSetProperty(W_GenericBox.descr_get_real),
    imag = GetSetProperty(W_GenericBox.descr_get_imag),
    flags = GetSetProperty(W_GenericBox.descr_get_flags),
)

W_BoolBox.typedef = TypeDef("numpy.bool_", W_GenericBox.typedef,
    __new__ = interp2app(W_BoolBox.descr__new__.im_func),
    __index__ = interp2app(W_BoolBox.descr_index),
    __reduce__ = interp2app(W_BoolBox.descr_reduce),
)

W_NumberBox.typedef = TypeDef("numpy.number", W_GenericBox.typedef,
)

W_IntegerBox.typedef = TypeDef("numpy.integer", W_NumberBox.typedef,
)

W_SignedIntegerBox.typedef = TypeDef("numpy.signedinteger", W_IntegerBox.typedef,
)

W_UnsignedIntegerBox.typedef = TypeDef("numpy.unsignedinteger", W_IntegerBox.typedef,
)

W_Int8Box.typedef = TypeDef("numpy.int8", W_SignedIntegerBox.typedef,
    __new__ = interp2app(W_Int8Box.descr__new__.im_func),
    __index__ = interp2app(W_Int8Box.descr_index),
    __reduce__ = interp2app(W_Int8Box.descr_reduce),
)

W_UInt8Box.typedef = TypeDef("numpy.uint8", W_UnsignedIntegerBox.typedef,
    __new__ = interp2app(W_UInt8Box.descr__new__.im_func),
    __index__ = interp2app(W_UInt8Box.descr_index),
    __reduce__ = interp2app(W_UInt8Box.descr_reduce),
)

W_Int16Box.typedef = TypeDef("numpy.int16", W_SignedIntegerBox.typedef,
    __new__ = interp2app(W_Int16Box.descr__new__.im_func),
    __index__ = interp2app(W_Int16Box.descr_index),
    __reduce__ = interp2app(W_Int16Box.descr_reduce),
)

W_UInt16Box.typedef = TypeDef("numpy.uint16", W_UnsignedIntegerBox.typedef,
    __new__ = interp2app(W_UInt16Box.descr__new__.im_func),
    __index__ = interp2app(W_UInt16Box.descr_index),
    __reduce__ = interp2app(W_UInt16Box.descr_reduce),
)

W_Int32Box.typedef = TypeDef("numpy.int32", (W_SignedIntegerBox.typedef,) + MIXIN_32,
    __new__ = interp2app(W_Int32Box.descr__new__.im_func),
    __index__ = interp2app(W_Int32Box.descr_index),
    __reduce__ = interp2app(W_Int32Box.descr_reduce),
)

W_UInt32Box.typedef = TypeDef("numpy.uint32", W_UnsignedIntegerBox.typedef,
    __new__ = interp2app(W_UInt32Box.descr__new__.im_func),
    __index__ = interp2app(W_UInt32Box.descr_index),
    __reduce__ = interp2app(W_UInt32Box.descr_reduce),
)

W_Int64Box.typedef = TypeDef("numpy.int64", (W_SignedIntegerBox.typedef,) + MIXIN_64,
    __new__ = interp2app(W_Int64Box.descr__new__.im_func),
    __index__ = interp2app(W_Int64Box.descr_index),
    __reduce__ = interp2app(W_Int64Box.descr_reduce),
)

W_UInt64Box.typedef = TypeDef("numpy.uint64", W_UnsignedIntegerBox.typedef,
    __new__ = interp2app(W_UInt64Box.descr__new__.im_func),
    __index__ = interp2app(W_UInt64Box.descr_index),
    __reduce__ = interp2app(W_UInt64Box.descr_reduce),
)

W_LongBox.typedef = TypeDef("numpy.int%d" % LONG_BIT,
    (W_SignedIntegerBox.typedef, W_IntObject.typedef),
    __new__ = interp2app(W_LongBox.descr__new__.im_func),
    __index__ = interp2app(W_LongBox.descr_index),
    __reduce__ = interp2app(W_LongBox.descr_reduce),
)

W_ULongBox.typedef = TypeDef("numpy.uint%d" % LONG_BIT, W_UnsignedIntegerBox.typedef,
    __new__ = interp2app(W_ULongBox.descr__new__.im_func),
    __index__ = interp2app(W_ULongBox.descr_index),
    __reduce__ = interp2app(W_ULongBox.descr_reduce),
)

W_InexactBox.typedef = TypeDef("numpy.inexact", W_NumberBox.typedef,
)

W_FloatingBox.typedef = TypeDef("numpy.floating", W_InexactBox.typedef,
)

W_Float16Box.typedef = TypeDef("numpy.float16", W_FloatingBox.typedef,
    __new__ = interp2app(W_Float16Box.descr__new__.im_func),
    __reduce__ = interp2app(W_Float16Box.descr_reduce),
)

W_Float32Box.typedef = TypeDef("numpy.float32", W_FloatingBox.typedef,
    __new__ = interp2app(W_Float32Box.descr__new__.im_func),
    __reduce__ = interp2app(W_Float32Box.descr_reduce),
)

W_Float64Box.typedef = TypeDef("numpy.float64", (W_FloatingBox.typedef, W_FloatObject.typedef),
    __new__ = interp2app(W_Float64Box.descr__new__.im_func),
    __reduce__ = interp2app(W_Float64Box.descr_reduce),
    as_integer_ratio = interp2app(W_Float64Box.descr_as_integer_ratio),
)

W_ComplexFloatingBox.typedef = TypeDef("numpy.complexfloating", W_InexactBox.typedef,
)

W_Complex64Box.typedef = TypeDef("numpy.complex64", (W_ComplexFloatingBox.typedef),
    __new__ = interp2app(W_Complex64Box.descr__new__.im_func),
    __reduce__ = interp2app(W_Complex64Box.descr_reduce),
    __complex__ = interp2app(W_GenericBox.item),
)

W_Complex128Box.typedef = TypeDef("numpy.complex128", (W_ComplexFloatingBox.typedef, W_ComplexObject.typedef),
    __new__ = interp2app(W_Complex128Box.descr__new__.im_func),
    __reduce__ = interp2app(W_Complex128Box.descr_reduce),
)

if long_double_size in (8, 12, 16):
    W_FloatLongBox.typedef = TypeDef("numpy.float%d" % (long_double_size * 8), (W_FloatingBox.typedef),
        __new__ = interp2app(W_FloatLongBox.descr__new__.im_func),
        __reduce__ = interp2app(W_FloatLongBox.descr_reduce),
    )

    W_ComplexLongBox.typedef = TypeDef("numpy.complex%d" % (long_double_size * 16), (W_ComplexFloatingBox.typedef, W_ComplexObject.typedef),
        __new__ = interp2app(W_ComplexLongBox.descr__new__.im_func),
        __reduce__ = interp2app(W_ComplexLongBox.descr_reduce),
        __complex__ = interp2app(W_GenericBox.item),
    )

W_FlexibleBox.typedef = TypeDef("numpy.flexible", W_GenericBox.typedef,
)

W_VoidBox.typedef = TypeDef("numpy.void", W_FlexibleBox.typedef,
    __new__ = interp2app(W_VoidBox.descr__new__.im_func),
    __getitem__ = interp2app(W_VoidBox.descr_getitem),
    __setitem__ = interp2app(W_VoidBox.descr_setitem),
    __iter__ = interp2app(W_VoidBox.descr_iter),
)

W_CharacterBox.typedef = TypeDef("numpy.character", W_FlexibleBox.typedef,
)

W_StringBox.typedef = TypeDef("numpy.bytes_", (W_CharacterBox.typedef, W_BytesObject.typedef),
    __new__ = interp2app(W_StringBox.descr__new__string_box.im_func),
    __len__ = interp2app(W_StringBox.descr_len),
)

W_UnicodeBox.typedef = TypeDef("numpy.str_", (W_CharacterBox.typedef, W_UnicodeObject.typedef),
    __new__ = interp2app(W_UnicodeBox.descr__new__unicode_box.im_func),
    __len__ = interp2app(W_UnicodeBox.descr_len),
)

W_ObjectBox.typedef = TypeDef("numpy.object_", W_ObjectBox.typedef,
    __new__ = interp2app(W_ObjectBox.descr__new__.im_func),
    __getattr__ = interp2app(W_ObjectBox.descr__getattr__),
)
