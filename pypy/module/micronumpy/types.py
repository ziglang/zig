import functools
import math
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rutf8 import Utf8StringIterator, codepoints_in_utf8, Utf8StringBuilder
from pypy.interpreter.error import OperationError, oefmt
from pypy.objspace.std.floatobject import float2string
from pypy.objspace.std.complexobject import str_format
from pypy.interpreter.baseobjspace import W_Root, ObjSpace
from rpython.rlib import clibffi, jit, rfloat, rcomplex
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rlib.rarithmetic import widen, byteswap, r_ulonglong, \
    most_neg_value_of, LONG_BIT
from rpython.rlib.rawstorage import (alloc_raw_storage,
    raw_storage_getitem_unaligned, raw_storage_setitem_unaligned)
from rpython.rlib.rstring import StringBuilder, UnicodeBuilder
from rpython.rlib.rstruct.ieee import (float_pack, float_unpack, unpack_float,
                                       pack_float80, unpack_float80)
from rpython.rlib.rstruct.nativefmttable import native_is_bigendian
from rpython.rlib.rstruct.runpack import runpack
from rpython.rtyper.annlowlevel import cast_instance_to_gcref,\
     cast_gcref_to_instance
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.tool.sourcetools import func_with_new_name
from pypy.module.micronumpy import boxes, support
from pypy.module.micronumpy.concrete import SliceArray, VoidBoxStorage, V_OBJECTSTORE
from pypy.module.micronumpy.strides import calc_strides
from . import constants as NPY

degToRad = math.pi / 180.0
log2 = math.log(2)
log2e = 1. / log2
log10 = math.log(10)

'''
if not we_are_translated():
    _raw_storage_setitem_unaligned = raw_storage_setitem_unaligned
    _raw_storage_getitem_unaligned = raw_storage_getitem_unaligned
    def raw_storage_setitem_unaligned(storage, offset, value):
        assert offset >=0
        try:
            assert offset < storage._obj.getlength()
        except AttributeError:
            pass
        return _raw_storage_setitem_unaligned(storage, offset, value)

    def raw_storage_getitem_unaligned(T, storage, offset):
        assert offset >=0
        try:
            assert offset < storage._obj.getlength()
        except AttributeError:
            pass
        return _raw_storage_getitem_unaligned(T, storage, offset)
'''

def simple_unary_op(func):
    specialize.argtype(1)(func)
    @functools.wraps(func)
    def dispatcher(self, v):
        return self.box(
            func(
                self,
                self.for_computation(self.unbox(v)),
            )
        )
    return dispatcher

def complex_unary_op(func):
    specialize.argtype(1)(func)
    @functools.wraps(func)
    def dispatcher(self, v):
        return self.box_complex(
            *func(
                self,
                self.for_computation(self.unbox(v))
            )
        )
    return dispatcher

def complex_to_real_unary_op(func):
    specialize.argtype(1)(func)
    @functools.wraps(func)
    def dispatcher(self, v):
        return self.box_component(
            func(
                self,
                self.for_computation(self.unbox(v))
            )
        )
    return dispatcher

def raw_unary_op(func):
    specialize.argtype(1)(func)
    @functools.wraps(func)
    def dispatcher(self, v):
        return func(
            self,
            self.for_computation(self.unbox(v))
        )
    return dispatcher

def simple_binary_op(func):
    specialize.argtype(1, 2)(func)
    @functools.wraps(func)
    def dispatcher(self, v1, v2):
        return self.box(
            func(
                self,
                self.for_computation(self.unbox(v1)),
                self.for_computation(self.unbox(v2)),
            )
        )
    return dispatcher

def complex_binary_op(func):
    specialize.argtype(1, 2)(func)
    @functools.wraps(func)
    def dispatcher(self, v1, v2):
        return self.box_complex(
            *func(
                self,
                self.for_computation(self.unbox(v1)),
                self.for_computation(self.unbox(v2)),
            )
        )
    return dispatcher

def raw_binary_op(func):
    specialize.argtype(1, 2)(func)
    @functools.wraps(func)
    def dispatcher(self, v1, v2):
        return func(self,
            self.for_computation(self.unbox(v1)),
            self.for_computation(self.unbox(v2))
        )
    return dispatcher

class BaseType(object):
    _immutable_fields_ = ['space']
    strlen = 0  # chars needed to print any possible value of the type

    def __init__(self, space):
        assert isinstance(space, ObjSpace)
        self.space = space

    def __repr__(self):
        return self.__class__.__name__

    def malloc(self, size, zero=True):
        if zero:
            return alloc_raw_storage(size, track_allocation=False, zero=True)
        else:
            return alloc_raw_storage(size, track_allocation=False, zero=False)

    @classmethod
    def basesize(cls):
        return rffi.sizeof(cls.T)

class Primitive(object):
    _mixin_ = True

    def get_element_size(self):
        return rffi.sizeof(self.T)

    @specialize.argtype(1)
    def box(self, value):
        return self.BoxType(rffi.cast(self.T, value))

    @specialize.argtype(1, 2)
    def box_complex(self, real, imag):
        #XXX this is the place to display a warning
        return self.box(real)

    def box_raw_data(self, data):
        # For pickle
        array = rffi.cast(rffi.CArrayPtr(self.T), data)
        return self.box(array[0])

    def unbox(self, box):
        if isinstance(box, self.BoxType):
            return box.value
        elif isinstance(box,  boxes.W_ObjectBox):
            return self._coerce(self.space, box).value
        else:
            raise oefmt(self.space.w_NotImplementedError,
                "%s dtype cannot unbox %s", str(self), str(box))

    def coerce(self, space, dtype, w_item):
        if isinstance(w_item, self.BoxType):
            return w_item
        return self.coerce_subtype(space, space.gettypefor(self.BoxType), w_item)

    def coerce_subtype(self, space, w_subtype, w_item):
        # XXX: ugly
        w_obj = space.allocate_instance(self.BoxType, w_subtype)
        assert isinstance(w_obj, self.BoxType)
        w_obj.__init__(self._coerce(space, w_item).value)
        return w_obj

    def to_builtin_type(self, space, box):
        raise NotImplementedError("has to be provided by subclass")

    def _coerce(self, space, w_item):
        raise NotImplementedError

    def default_fromstring(self, space):
        raise NotImplementedError

    def _read(self, storage, i, offset, native):
        res = raw_storage_getitem_unaligned(self.T, storage, i + offset)
        if not native:
            res = byteswap(res)
        return res

    def _write(self, storage, i, offset, value, native):
        if not native:
            value = byteswap(value)
        raw_storage_setitem_unaligned(storage, i + offset, value)

    def read(self, arr, i, offset, dtype):
        with arr as storage:
            return self.box(self._read(storage, i, offset, dtype.is_native()))

    def read_bool(self, arr, i, offset, dtype):
        with arr as storage:
            return bool(self.for_computation(
                self._read(storage, i, offset, dtype.is_native())))

    def store(self, arr, i, offset, box, native):
        with arr as storage:
            self._write(storage, i, offset, self.unbox(box), native)

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        value = self.unbox(box)
        for i in xrange(start, stop, width):
            self._write(storage, i, offset, value, native)

    def runpack_str(self, space, s, native):
        v = rffi.cast(self.T, runpack(self.format_code, s))
        if not native:
            v = byteswap(v)
        return self.box(v)

    @simple_binary_op
    def add(self, v1, v2):
        return v1 + v2

    @simple_binary_op
    def sub(self, v1, v2):
        return v1 - v2

    @simple_binary_op
    def mul(self, v1, v2):
        return v1 * v2

    @simple_unary_op
    def pos(self, v):
        return +v

    @simple_unary_op
    def neg(self, v):
        return -v

    def byteswap(self, w_v):
        # no for_computation here
        return self.box(byteswap(self.unbox(w_v)))

    @simple_unary_op
    def conj(self, v):
        return v

    @simple_unary_op
    def real(self, v):
        return v

    @simple_unary_op
    def imag(self, v):
        return 0

    @simple_unary_op
    def abs(self, v):
        return abs(v)

    @raw_unary_op
    def isnan(self, v):
        return False

    @raw_unary_op
    def isinf(self, v):
        return False

    @raw_binary_op
    def eq(self, v1, v2):
        return v1 == v2

    @raw_binary_op
    def ne(self, v1, v2):
        return v1 != v2

    @raw_binary_op
    def lt(self, v1, v2):
        return v1 < v2

    @raw_binary_op
    def le(self, v1, v2):
        return v1 <= v2

    @raw_binary_op
    def gt(self, v1, v2):
        return v1 > v2

    @raw_binary_op
    def ge(self, v1, v2):
        return v1 >= v2

    @raw_binary_op
    def logical_and(self, v1, v2):
        if bool(v1) and bool(v2):
            return Bool._True
        return Bool._False

    @raw_binary_op
    def logical_or(self, v1, v2):
        if bool(v1) or bool(v2):
            return Bool._True
        return Bool._False

    @raw_unary_op
    def logical_not(self, v):
        return not bool(v)

    @raw_binary_op
    def logical_xor(self, v1, v2):
        a = bool(v1)
        b = bool(v2)
        return (not b and a) or (not a and b)

    @raw_unary_op
    def bool(self, v):
        return bool(v)

    @simple_binary_op
    def max(self, v1, v2):
        return max(v1, v2)

    @simple_binary_op
    def min(self, v1, v2):
        return min(v1, v2)

    @raw_binary_op
    def argmax(self, v1, v2):
        return v1 >= v2

    @raw_binary_op
    def argmin(self, v1, v2):
        return v1 <= v2

    @raw_unary_op
    def rint(self, v):
        float64 = Float64(self.space)
        return float64.rint(float64.box(v))

class Bool(BaseType, Primitive):
    T = lltype.Bool
    num = NPY.BOOL
    kind = NPY.GENBOOLLTR
    char = NPY.BOOLLTR
    BoxType = boxes.W_BoolBox
    format_code = "?"
    strlen = 5  # "False"

    _True = BoxType(True)
    _False = BoxType(False)

    @specialize.argtype(1)
    def box(self, value):
        boolean = rffi.cast(self.T, value)
        if boolean:
            return self._True
        else:
            return self._False

    @specialize.argtype(1, 2)
    def box_complex(self, real, imag):
        box = Primitive.box(self, real)
        if box.value:
            return self._True
        box = Primitive.box(self, imag)
        if box.value:
            return self._True
        return self._False

    def coerce_subtype(self, space, w_subtype, w_item):
        # Doesn't return subclasses so it can return the constants.
        return self._coerce(space, w_item)

    def _coerce(self, space, w_item):
        if space.is_none(w_item):
            return self.box(False)
        return self.box(space.is_true(w_item))

    def to_builtin_type(self, space, w_item):
        return space.newbool(self.unbox(w_item))

    def str_format(self, box, add_quotes=True):
        return "True" if self.unbox(box) else "False"

    @staticmethod
    def for_computation(v):
        return int(v)

    def default_fromstring(self, space):
        return self.box(True)

    @simple_binary_op
    def lshift(self, v1, v2):
        return v1 << v2

    @simple_binary_op
    def rshift(self, v1, v2):
        return v1 >> v2

    @simple_binary_op
    def bitwise_and(self, v1, v2):
        return v1 & v2

    @simple_binary_op
    def bitwise_or(self, v1, v2):
        return v1 | v2

    @simple_binary_op
    def bitwise_xor(self, v1, v2):
        return v1 ^ v2

    @simple_unary_op
    def invert(self, v):
        return not v

    @raw_unary_op
    def isfinite(self, v):
        return True

    @raw_unary_op
    def signbit(self, v):
        return False

    @simple_unary_op
    def reciprocal(self, v):
        if v:
            return 1
        return 0

    @specialize.argtype(1)
    def round(self, v, decimals=0):
        if decimals == 0:
            return Float64(self.space).box(self.unbox(v))
        # numpy 1.10 compatibility
        raise oefmt(self.space.w_TypeError, "ufunc casting failure")



class Integer(Primitive):
    _mixin_ = True
    signed = True

    def to_builtin_type(self, space, box):
        return space.newint(self.for_computation(self.unbox(box)))

    def _base_coerce(self, space, w_item):
        if w_item is None:
            return self.box(0)
        return self.box(space.int_w(space.call_function(space.w_int, w_item)))

    def _coerce(self, space, w_item):
        return self._base_coerce(space, w_item)

    def str_format(self, box, add_quotes=True):
        return str(self.for_computation(self.unbox(box)))

    @staticmethod
    def for_computation(v):
        return widen(v)

    def default_fromstring(self, space):
        return self.box(0)

    @specialize.argtype(1, 2)
    def div(self, b1, b2):
        v1 = self.for_computation(self.unbox(b1))
        v2 = self.for_computation(self.unbox(b2))
        if v2 == 0:
            return self.box(0)
        if (self.T is rffi.SIGNEDCHAR or self.T is rffi.SHORT or self.T is rffi.INT or
                self.T is rffi.LONG or self.T is rffi.LONGLONG):
            if v2 == -1 and v1 == self.for_computation(most_neg_value_of(self.T)):
                return self.box(0)
        return self.box(v1 / v2)

    @specialize.argtype(1, 2)
    def floordiv(self, b1, b2):
        v1 = self.for_computation(self.unbox(b1))
        v2 = self.for_computation(self.unbox(b2))
        if v2 == 0:
            return self.box(0)
        if (self.T is rffi.SIGNEDCHAR or self.T is rffi.SHORT or self.T is rffi.INT or
                self.T is rffi.LONG or self.T is rffi.LONGLONG):
            if v2 == -1 and v1 == self.for_computation(most_neg_value_of(self.T)):
                return self.box(0)
        return self.box(v1 / v2)

    @simple_binary_op
    def mod(self, v1, v2):
        return v1 % v2

    @simple_binary_op
    @jit.look_inside_iff(lambda self, v1, v2: jit.isconstant(v2))
    def pow(self, v1, v2):
        if v2 < 0:
            return 0
        res = 1
        while v2 > 0:
            if v2 & 1:
                res *= v1
            v2 >>= 1
            if v2 == 0:
                break
            v1 *= v1
        return res

    @simple_binary_op
    def lshift(self, v1, v2):
        return v1 << v2

    @simple_binary_op
    def rshift(self, v1, v2):
        return v1 >> v2

    @simple_unary_op
    def sign(self, v):
        if v > 0:
            return 1
        elif v < 0:
            return -1
        else:
            assert v == 0
            return 0

    @raw_unary_op
    def isfinite(self, v):
        return True

    @raw_unary_op
    def isnan(self, v):
        return False

    @raw_unary_op
    def isinf(self, v):
        return False

    @simple_binary_op
    def bitwise_and(self, v1, v2):
        return v1 & v2

    @simple_binary_op
    def bitwise_or(self, v1, v2):
        return v1 | v2

    @simple_binary_op
    def bitwise_xor(self, v1, v2):
        return v1 ^ v2

    @simple_unary_op
    def invert(self, v):
        return ~v

    @specialize.argtype(1)
    def reciprocal(self, v):
        raw = self.for_computation(self.unbox(v))
        ans = 0
        if raw == 0:
            # XXX good place to warn
            if self.T is rffi.INT or self.T is rffi.LONG or self.T is rffi.LONGLONG:
                ans = most_neg_value_of(self.T)
        elif abs(raw) == 1:
            ans = raw
        return self.box(ans)

    @specialize.argtype(1)
    def round(self, v, decimals=0):
        raw = self.for_computation(self.unbox(v))
        if decimals < 0:
            # No ** in rpython
            factor = 1
            for i in xrange(-decimals):
                factor *=10
            #int does floor division, we want toward zero
            if raw < 0:
                ans = - (-raw / factor * factor)
            else:
                ans = raw / factor * factor
        else:
            ans = raw
        return self.box(ans)

    @raw_unary_op
    def signbit(self, v):
        return v < 0

class Int8(BaseType, Integer):
    T = rffi.SIGNEDCHAR
    num = NPY.BYTE
    kind = NPY.SIGNEDLTR
    char = NPY.BYTELTR
    BoxType = boxes.W_Int8Box
    format_code = "b"

class UInt8(BaseType, Integer):
    T = rffi.UCHAR
    num = NPY.UBYTE
    kind = NPY.UNSIGNEDLTR
    char = NPY.UBYTELTR
    BoxType = boxes.W_UInt8Box
    format_code = "B"
    signed = False

class Int16(BaseType, Integer):
    T = rffi.SHORT
    num = NPY.SHORT
    kind = NPY.SIGNEDLTR
    char = NPY.SHORTLTR
    BoxType = boxes.W_Int16Box
    format_code = "h"

class UInt16(BaseType, Integer):
    T = rffi.USHORT
    num = NPY.USHORT
    kind = NPY.UNSIGNEDLTR
    char = NPY.USHORTLTR
    BoxType = boxes.W_UInt16Box
    format_code = "H"
    signed = False

class Int32(BaseType, Integer):
    T = rffi.INT
    num = NPY.INT
    kind = NPY.SIGNEDLTR
    char = NPY.INTLTR
    BoxType = boxes.W_Int32Box
    format_code = "i"

class UInt32(BaseType, Integer):
    T = rffi.UINT
    num = NPY.UINT
    kind = NPY.UNSIGNEDLTR
    char = NPY.UINTLTR
    BoxType = boxes.W_UInt32Box
    format_code = "I"
    signed = False

def _int64_coerce(self, space, w_item):
    try:
        return self._base_coerce(space, w_item)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
    bigint = space.bigint_w(w_item)
    try:
        value = bigint.tolonglong()
    except OverflowError:
        raise OperationError(space.w_OverflowError, space.w_None)
    return self.box(value)

class Int64(BaseType, Integer):
    T = rffi.LONGLONG
    num = NPY.LONGLONG
    kind = NPY.SIGNEDLTR
    char = NPY.LONGLONGLTR
    BoxType = boxes.W_Int64Box
    format_code = "q"

    if LONG_BIT == 32:
        _coerce = func_with_new_name(_int64_coerce, '_coerce')

def _uint64_coerce(self, space, w_item):
    try:
        return self._base_coerce(space, w_item)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
    bigint = space.bigint_w(w_item)
    try:
        value = bigint.toulonglong()
    except OverflowError:
        raise OperationError(space.w_OverflowError, space.w_None)
    return self.box(value)

class UInt64(BaseType, Integer):
    T = rffi.ULONGLONG
    num = NPY.ULONGLONG
    kind = NPY.UNSIGNEDLTR
    char = NPY.ULONGLONGLTR
    BoxType = boxes.W_UInt64Box
    format_code = "Q"
    signed = False

    _coerce = func_with_new_name(_uint64_coerce, '_coerce')

class Long(BaseType, Integer):
    T = rffi.LONG
    num = NPY.LONG
    kind = NPY.SIGNEDLTR
    char = NPY.LONGLTR
    BoxType = boxes.W_LongBox
    format_code = "l"

def _ulong_coerce(self, space, w_item):
    try:
        return self._base_coerce(space, w_item)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
    bigint = space.bigint_w(w_item)
    try:
        value = bigint.touint()
    except OverflowError:
        raise OperationError(space.w_OverflowError, space.w_None)
    return self.box(value)

class ULong(BaseType, Integer):
    T = rffi.ULONG
    num = NPY.ULONG
    kind = NPY.UNSIGNEDLTR
    char = NPY.ULONGLTR
    BoxType = boxes.W_ULongBox
    format_code = "L"
    signed = False

    _coerce = func_with_new_name(_ulong_coerce, '_coerce')

class Float(Primitive):
    _mixin_ = True
    strlen = 32

    def to_builtin_type(self, space, box):
        return space.newfloat(self.for_computation(self.unbox(box)))

    def _coerce(self, space, w_item):
        if w_item is None:
            return self.box(0.0)
        if space.is_none(w_item):
            return self.box(rfloat.NAN)
        return self.box(space.float_w(space.call_function(space.w_float, w_item)))

    def str_format(self, box, add_quotes=True):
        return float2string(self.for_computation(self.unbox(box)), "g",
                            rfloat.DTSF_STR_PRECISION)

    @staticmethod
    def for_computation(v):
        return float(v)

    def default_fromstring(self, space):
        return self.box(-1.0)

    @simple_binary_op
    def div(self, v1, v2):
        try:
            return v1 / v2
        except ZeroDivisionError:
            if v1 == v2 == 0.0:
                return rfloat.NAN
            return math.copysign(rfloat.INFINITY, v1 * v2)

    @simple_binary_op
    def floordiv(self, v1, v2):
        try:
            return math.floor(v1 / v2)
        except ZeroDivisionError:
            if v1 == v2 == 0.0:
                return rfloat.NAN
            return math.copysign(rfloat.INFINITY, v1 * v2)

    @simple_binary_op
    def mod(self, v1, v2):
        # partial copy of pypy.objspace.std.floatobject.W_FloatObject.descr_mod
        if v2 == 0.0:
            return rfloat.NAN
        mod = math.fmod(v1, v2)
        if mod:
            # ensure the remainder has the same sign as the denominator
            if (v2 < 0.0) != (mod < 0.0):
                mod += v2
        else:
            # the remainder is zero, and in the presence of signed zeroes
            # fmod returns different results across platforms; ensure
            # it has the same sign as the denominator; we'd like to do
            # "mod = v2 * 0.0", but that may get optimized away
            mod = math.copysign(0.0, v2)
        return mod

    @simple_binary_op
    def pow(self, v1, v2):
        try:
            return math.pow(v1, v2)
        except ValueError:
            return rfloat.NAN
        except OverflowError:
            if math.modf(v2)[0] == 0 and math.modf(v2 / 2)[0] != 0:
                # Odd integer powers result in the same sign as the base
                return math.copysign(rfloat.INFINITY, v1)
            return rfloat.INFINITY

    @simple_binary_op
    def copysign(self, v1, v2):
        return math.copysign(v1, v2)

    @simple_unary_op
    def sign(self, v):
        if v == 0.0:
            return 0.0
        if math.isnan(v):
            return rfloat.NAN
        return math.copysign(1.0, v)

    @raw_unary_op
    def signbit(self, v):
        return math.copysign(1.0, v) < 0.0

    @simple_unary_op
    def fabs(self, v):
        return math.fabs(v)

    @simple_binary_op
    def max(self, v1, v2):
        return v1 if v1 >= v2 or math.isnan(v1) else v2

    @simple_binary_op
    def min(self, v1, v2):
        return v1 if v1 <= v2 or math.isnan(v1) else v2

    @raw_binary_op
    def argmax(self, v1, v2):
        return v1 >= v2 or math.isnan(v1)

    @raw_binary_op
    def argmin(self, v1, v2):
        return v1 <= v2 or math.isnan(v1)

    @simple_binary_op
    def fmax(self, v1, v2):
        return v1 if v1 >= v2 or math.isnan(v2) else v2

    @simple_binary_op
    def fmin(self, v1, v2):
        return v1 if v1 <= v2 or math.isnan(v2) else v2

    @simple_binary_op
    def fmod(self, v1, v2):
        try:
            return math.fmod(v1, v2)
        except ValueError:
            return rfloat.NAN

    @simple_unary_op
    def reciprocal(self, v):
        if v == 0.0:
            return math.copysign(rfloat.INFINITY, v)
        return 1.0 / v

    @simple_unary_op
    def floor(self, v):
        return math.floor(v)

    @simple_unary_op
    def ceil(self, v):
        return math.ceil(v)

    @specialize.argtype(1)
    def round(self, v, decimals=0):
        raw = self.for_computation(self.unbox(v))
        if math.isinf(raw):
            return v
        elif math.isnan(raw):
            return v
        ans = rfloat.round_double(raw, decimals, half_even=True)
        return self.box(ans)

    @simple_unary_op
    def trunc(self, v):
        if v < 0:
            return math.ceil(v)
        else:
            return math.floor(v)

    @simple_unary_op
    def exp(self, v):
        try:
            return math.exp(v)
        except OverflowError:
            return rfloat.INFINITY

    @simple_unary_op
    def exp2(self, v):
        try:
            return math.pow(2, v)
        except OverflowError:
            return rfloat.INFINITY

    @simple_unary_op
    def expm1(self, v):
        try:
            return rfloat.expm1(v)
        except OverflowError:
            return rfloat.INFINITY

    @simple_unary_op
    def sin(self, v):
        return math.sin(v)

    @simple_unary_op
    def cos(self, v):
        return math.cos(v)

    @simple_unary_op
    def tan(self, v):
        return math.tan(v)

    @simple_unary_op
    def arcsin(self, v):
        if not -1.0 <= v <= 1.0:
            return rfloat.NAN
        return math.asin(v)

    @simple_unary_op
    def arccos(self, v):
        if not -1.0 <= v <= 1.0:
            return rfloat.NAN
        return math.acos(v)

    @simple_unary_op
    def arctan(self, v):
        return math.atan(v)

    @simple_binary_op
    def arctan2(self, v1, v2):
        return math.atan2(v1, v2)

    @simple_unary_op
    def sinh(self, v):
        return math.sinh(v)

    @simple_unary_op
    def cosh(self, v):
        return math.cosh(v)

    @simple_unary_op
    def tanh(self, v):
        return math.tanh(v)

    @simple_unary_op
    def arcsinh(self, v):
        return math.asinh(v)

    @simple_unary_op
    def arccosh(self, v):
        if v < 1.0:
            return rfloat.NAN
        return math.acosh(v)

    @simple_unary_op
    def arctanh(self, v):
        if v == 1.0 or v == -1.0:
            return math.copysign(rfloat.INFINITY, v)
        if not -1.0 < v < 1.0:
            return rfloat.NAN
        return math.atanh(v)

    @simple_unary_op
    def sqrt(self, v):
        try:
            return math.sqrt(v)
        except ValueError:
            return rfloat.NAN

    @simple_unary_op
    def square(self, v):
        return v*v

    @raw_unary_op
    def isnan(self, v):
        return math.isnan(v)

    @raw_unary_op
    def isinf(self, v):
        return math.isinf(v)

    @raw_unary_op
    def isfinite(self, v):
        return rfloat.isfinite(v)

    @simple_unary_op
    def radians(self, v):
        return v * degToRad
    deg2rad = radians

    @simple_unary_op
    def degrees(self, v):
        return v / degToRad

    @simple_unary_op
    def log(self, v):
        try:
            return math.log(v)
        except ValueError:
            if v == 0.0:
                # CPython raises ValueError here, so we have to check
                # the value to find the correct numpy return value
                return -rfloat.INFINITY
            return rfloat.NAN

    @simple_unary_op
    def log2(self, v):
        try:
            return math.log(v) / log2
        except ValueError:
            if v == 0.0:
                # CPython raises ValueError here, so we have to check
                # the value to find the correct numpy return value
                return -rfloat.INFINITY
            return rfloat.NAN

    @simple_unary_op
    def log10(self, v):
        try:
            return math.log10(v)
        except ValueError:
            if v == 0.0:
                # CPython raises ValueError here, so we have to check
                # the value to find the correct numpy return value
                return -rfloat.INFINITY
            return rfloat.NAN

    @simple_unary_op
    def log1p(self, v):
        try:
            return rfloat.log1p(v)
        except OverflowError:
            return -rfloat.INFINITY
        except ValueError:
            return rfloat.NAN

    @simple_binary_op
    def logaddexp(self, v1, v2):
        tmp = v1 - v2
        if tmp > 0:
            return v1 + rfloat.log1p(math.exp(-tmp))
        elif tmp <= 0:
            return v2 + rfloat.log1p(math.exp(tmp))
        else:
            return v1 + v2

    def npy_log2_1p(self, v):
        return log2e * rfloat.log1p(v)

    @simple_binary_op
    def logaddexp2(self, v1, v2):
        tmp = v1 - v2
        if tmp > 0:
            return v1 + self.npy_log2_1p(math.pow(2, -tmp))
        if tmp <= 0:
            return v2 + self.npy_log2_1p(math.pow(2, tmp))
        else:
            return v1 + v2

    @simple_unary_op
    def rint(self, v):
        x = float(v)
        if rfloat.isfinite(x):
            import math
            y = math.floor(x)
            r = x - y

            if r > 0.5:
                y += 1.0

            if r == 0.5:
                r = y - 2.0 * math.floor(0.5 * y)
                if r == 1.0:
                    y += 1.0
            return y
        else:
            return x

class Float16(Float, BaseType):
    _STORAGE_T = rffi.USHORT
    T = rffi.SHORT
    num = NPY.HALF
    kind = NPY.FLOATINGLTR
    char = NPY.HALFLTR
    BoxType = boxes.W_Float16Box
    max_value = 65000.

    @specialize.argtype(1)
    def box(self, value):
        return self.BoxType(rffi.cast(rffi.DOUBLE, value))

    def runpack_str(self, space, s, native):
        assert len(s) == 2
        fval = self.box(unpack_float(s, native_is_bigendian))
        if not native:
            fval = self.byteswap(fval)
        return fval

    def default_fromstring(self, space):
        return self.box(-1.0)

    def byteswap(self, w_v):
        value = self.unbox(w_v)
        hbits = float_pack(value, 2)
        swapped = byteswap(rffi.cast(self._STORAGE_T, hbits))
        return self.box(float_unpack(r_ulonglong(swapped), 2))

    def _read(self, storage, i, offset, native):
        hbits = raw_storage_getitem_unaligned(self._STORAGE_T, storage, i + offset)
        if not native:
            hbits = byteswap(hbits)
        return float_unpack(r_ulonglong(hbits), 2)

    def _write(self, storage, i, offset, value, native):
        try:
            hbits = float_pack(value, 2)
        except OverflowError:
            hbits = float_pack(rfloat.INFINITY, 2)
        hbits = rffi.cast(self._STORAGE_T, hbits)
        if not native:
            hbits = byteswap(hbits)
        raw_storage_setitem_unaligned(storage, i + offset, hbits)

class Float32(Float, BaseType):
    T = rffi.FLOAT
    num = NPY.FLOAT
    kind = NPY.FLOATINGLTR
    char = NPY.FLOATLTR
    BoxType = boxes.W_Float32Box
    format_code = "f"
    max_value = 3.4e38

class Float64(Float, BaseType):
    T = rffi.DOUBLE
    num = NPY.DOUBLE
    kind = NPY.FLOATINGLTR
    char = NPY.DOUBLELTR
    BoxType = boxes.W_Float64Box
    format_code = "d"
    max_value = 1.7e308

class ComplexFloating(object):
    _mixin_ = True
    strlen = 64

    def _coerce(self, space, w_item):
        if w_item is None:
            return self.box_complex(0.0, 0.0)
        if space.is_none(w_item):
            return self.box_complex(rfloat.NAN, rfloat.NAN)
        w_item = space.call_function(space.w_complex, w_item)
        real, imag = space.unpackcomplex(w_item)
        return self.box_complex(real, imag)

    def coerce(self, space, dtype, w_item):
        if isinstance(w_item, self.BoxType):
            return w_item
        return self.coerce_subtype(space, space.gettypefor(self.BoxType), w_item)

    def coerce_subtype(self, space, w_subtype, w_item):
        w_tmpobj = self._coerce(space, w_item)
        w_obj = space.allocate_instance(self.BoxType, w_subtype)
        assert isinstance(w_obj, self.BoxType)
        w_obj.__init__(w_tmpobj.real, w_tmpobj.imag)
        return w_obj

    def str_format(self, box, add_quotes=True):
        real, imag = self.for_computation(self.unbox(box))
        imag_str = str_format(imag)
        if not rfloat.isfinite(imag):
            imag_str += '*'
        imag_str += 'j'

        # (0+2j) => 2j
        if real == 0 and math.copysign(1, real) == 1:
            return imag_str

        real_str = str_format(real)
        op = '+' if imag >= 0 or math.isnan(imag) else ''
        return ''.join(['(', real_str, op, imag_str, ')'])

    def runpack_str(self, space, s, native):
        comp = self.ComponentBoxType._get_dtype(space)
        l = len(s) // 2
        real = comp.runpack_str(space, s[:l])
        imag = comp.runpack_str(space, s[l:])
        if not native:
            real = comp.itemtype.byteswap(real)
            imag = comp.itemtype.byteswap(imag)
        return self.composite(real, imag)

    @staticmethod
    def for_computation(v):
        return float(v[0]), float(v[1])

    @raw_unary_op
    def _to_builtin_type(self, v):
        return v

    def to_builtin_type(self, space, box):
        real, imag = self.for_computation(self.unbox(box))
        return space.newcomplex(real, imag)

    def bool(self, v):
        real, imag = self.for_computation(self.unbox(v))
        return bool(real) or bool(imag)

    def read_bool(self, arr, i, offset, dtype):
        with arr as storage:
            v = self.for_computation(
                self._read(storage, i, offset, dtype.is_native()))
            return bool(v[0]) or bool(v[1])

    def get_element_size(self):
        return 2 * rffi.sizeof(self.T)

    def byteswap(self, w_v):
        real, imag = self.unbox(w_v)
        return self.box_complex(byteswap(real), byteswap(imag))

    @specialize.argtype(1)
    def box(self, value):
        return self.BoxType(
            rffi.cast(self.T, value),
            rffi.cast(self.T, 0.0))

    @specialize.argtype(1)
    def box_component(self, value):
        return self.ComponentBoxType(
            rffi.cast(self.T, value))

    @specialize.argtype(1, 2)
    def box_complex(self, real, imag):
        return self.BoxType(
            rffi.cast(self.T, real),
            rffi.cast(self.T, imag))

    def box_raw_data(self, data):
        # For pickle
        array = rffi.cast(rffi.CArrayPtr(self.T), data)
        return self.box_complex(array[0], array[1])

    def composite(self, v1, v2):
        assert isinstance(v1, self.ComponentBoxType)
        assert isinstance(v2, self.ComponentBoxType)
        real = v1.value
        imag = v2.value
        return self.box_complex(real, imag)

    def unbox(self, box):
        if isinstance(box, self.BoxType):
            return box.real, box.imag
        elif isinstance(box,  boxes.W_ObjectBox):
            retval = self._coerce(self.space, box)
            return retval.real, retval.imag
        else:
            raise oefmt(self.space.w_NotImplementedError,
                "%s dtype cannot unbox %s", str(self), str(box))

    def _read(self, storage, i, offset, native):
        real = raw_storage_getitem_unaligned(self.T, storage, i + offset)
        imag = raw_storage_getitem_unaligned(self.T, storage, i + offset + rffi.sizeof(self.T))
        if not native:
            real = byteswap(real)
            imag = byteswap(imag)
        return real, imag

    def read(self, arr, i, offset, dtype):
        with arr as storage:
            real, imag = self._read(storage, i, offset, dtype.is_native())
            return self.box_complex(real, imag)

    def _write(self, storage, i, offset, value, native):
        real, imag = value
        if not native:
            real = byteswap(real)
            imag = byteswap(imag)
        raw_storage_setitem_unaligned(storage, i + offset, real)
        raw_storage_setitem_unaligned(storage, i + offset + rffi.sizeof(self.T), imag)

    def store(self, arr, i, offset, box, native):
        with arr as storage:
            self._write(storage, i, offset, self.unbox(box), native)

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        value = self.unbox(box)
        for i in xrange(start, stop, width):
            self._write(storage, i, offset, value, native)

    @complex_binary_op
    def add(self, v1, v2):
        return rcomplex.c_add(v1, v2)

    @complex_binary_op
    def sub(self, v1, v2):
        return rcomplex.c_sub(v1, v2)

    @complex_binary_op
    def mul(self, v1, v2):
        return rcomplex.c_mul(v1, v2)

    @complex_binary_op
    def div(self, v1, v2):
        try:
            return rcomplex.c_div(v1, v2)
        except ZeroDivisionError:
            if rcomplex.c_abs(*v1) == 0 or \
                    (math.isnan(v1[0]) and math.isnan(v1[1])):
                return rfloat.NAN, rfloat.NAN
            return rfloat.INFINITY, rfloat.INFINITY

    @complex_unary_op
    def pos(self, v):
        return v

    @complex_unary_op
    def neg(self, v):
        return -v[0], -v[1]

    @complex_unary_op
    def conj(self, v):
        return v[0], -v[1]

    @complex_to_real_unary_op
    def real(self, v):
        return v[0]

    @complex_to_real_unary_op
    def imag(self, v):
        return v[1]

    @complex_to_real_unary_op
    def abs(self, v):
        try:
            return rcomplex.c_abs(v[0], v[1])
        except OverflowError:
            # warning ...
            return rfloat.INFINITY

    @raw_unary_op
    def isnan(self, v):
        '''a complex number is nan if one of the parts is nan'''
        return math.isnan(v[0]) or math.isnan(v[1])

    @raw_unary_op
    def isinf(self, v):
        '''a complex number is inf if one of the parts is inf'''
        return math.isinf(v[0]) or math.isinf(v[1])

    def _eq(self, v1, v2):
        return v1[0] == v2[0] and v1[1] == v2[1]

    @raw_binary_op
    def eq(self, v1, v2):
        #compare the parts, so nan == nan is False
        return self._eq(v1, v2)

    @raw_binary_op
    def ne(self, v1, v2):
        return not self._eq(v1, v2)

    def _lt(self, v1, v2):
        (r1, i1), (r2, i2) = v1, v2
        if r1 < r2 and not math.isnan(i1) and not math.isnan(i2):
            return True
        if r1 == r2 and i1 < i2:
            return True
        return False

    @raw_binary_op
    def lt(self, v1, v2):
        return self._lt(v1, v2)

    @raw_binary_op
    def le(self, v1, v2):
        return self._lt(v1, v2) or self._eq(v1, v2)

    @raw_binary_op
    def gt(self, v1, v2):
        return self._lt(v2, v1)

    @raw_binary_op
    def ge(self, v1, v2):
        return self._lt(v2, v1) or self._eq(v2, v1)

    def _cbool(self, v):
        return bool(v[0]) or bool(v[1])

    @raw_binary_op
    def logical_and(self, v1, v2):
        if self._cbool(v1) and self._cbool(v2):
            return Bool._True
        return Bool._False

    @raw_binary_op
    def logical_or(self, v1, v2):
        if self._cbool(v1) or self._cbool(v2):
            return Bool._True
        return Bool._False

    @raw_unary_op
    def logical_not(self, v):
        return not self._cbool(v)

    @raw_binary_op
    def logical_xor(self, v1, v2):
        a = self._cbool(v1)
        b = self._cbool(v2)
        return (not b and a) or (not a and b)

    def min(self, v1, v2):
        if self.le(v1, v2) or self.isnan(v1):
            return v1
        return v2

    def max(self, v1, v2):
        if self.ge(v1, v2) or self.isnan(v1):
            return v1
        return v2

    def argmin(self, v1, v2):
        if self.le(v1, v2) or self.isnan(v1):
            return True
        return False

    def argmax(self, v1, v2):
        if self.ge(v1, v2) or self.isnan(v1):
            return True
        return False

    @complex_binary_op
    def floordiv(self, v1, v2):
        (r1, i1), (r2, i2) = v1, v2
        if r2 < 0:
            abs_r2 = -r2
        else:
            abs_r2 = r2
        if i2 < 0:
            abs_i2 = -i2
        else:
            abs_i2 = i2
        if abs_r2 >= abs_i2:
            if abs_r2 == 0.0:
                return rfloat.NAN, 0.
            else:
                ratio = i2 / r2
                denom = r2 + i2 * ratio
                rr = (r1 + i1 * ratio) / denom
        elif math.isnan(r2):
            rr = rfloat.NAN
        else:
            ratio = r2 / i2
            denom = r2 * ratio + i2
            assert i2 != 0.0
            rr = (r1 * ratio + i1) / denom
        return math.floor(rr), 0.

    #complex mod does not exist in numpy
    #@simple_binary_op
    #def mod(self, v1, v2):
    #    return math.fmod(v1, v2)

    def pow(self, v1, v2):
        y = self.for_computation(self.unbox(v2))
        if y[1] == 0:
            if y[0] == 0:
                return self.box_complex(1, 0)
            if y[0] == 1:
                return v1
            if y[0] == 2:
                return self.mul(v1, v1)
        x = self.for_computation(self.unbox(v1))
        if x[0] == 0 and x[1] == 0:
            if y[0] > 0 and y[1] == 0:
                return self.box_complex(0, 0)
            return self.box_complex(rfloat.NAN, rfloat.NAN)
        b = self.for_computation(self.unbox(self.log(v1)))
        return self.exp(self.box_complex(b[0] * y[0] - b[1] * y[1],
                                         b[0] * y[1] + b[1] * y[0]))

    #complex copysign does not exist in numpy
    #@complex_binary_op
    #def copysign(self, v1, v2):
    #    return (rfloat.copysign(v1[0], v2[0]),
    #           rfloat.copysign(v1[1], v2[1]))

    @complex_unary_op
    def sign(self, v):
        '''
        sign of complex number could be either the point closest to the unit circle
        or {-1,0,1}, for compatability with numpy we choose the latter
        '''
        if math.isnan(v[0]) or math.isnan(v[1]):
            return rfloat.NAN, 0
        if v[0] == 0.0:
            if v[1] == 0:
                return 0, 0
            if v[1] > 0:
                return 1, 0
            return -1, 0
        if v[0] > 0:
            return 1, 0
        return -1, 0

    def fmax(self, v1, v2):
        if self.ge(v1, v2) or self.isnan(v2):
            return v1
        return v2

    def fmin(self, v1, v2):
        if self.le(v1, v2) or self.isnan(v2):
            return v1
        return v2

    #@simple_binary_op
    #def fmod(self, v1, v2):
    #    try:
    #        return math.fmod(v1, v2)
    #    except ValueError:
    #        return rfloat.NAN

    @complex_unary_op
    def reciprocal(self, v):
        if math.isinf(v[1]) and math.isinf(v[0]):
            return rfloat.NAN, rfloat.NAN
        if math.isinf(v[0]):
            return (math.copysign(0., v[0]),
                    math.copysign(0., -v[1]))
        a2 = v[0]*v[0] + v[1]*v[1]
        try:
            return rcomplex.c_div((v[0], -v[1]), (a2, 0.))
        except ZeroDivisionError:
            return rfloat.NAN, rfloat.NAN

    @specialize.argtype(1)
    def round(self, v, decimals=0):
        ans = list(self.for_computation(self.unbox(v)))
        if rfloat.isfinite(ans[0]):
            ans[0] = rfloat.round_double(ans[0], decimals, half_even=True)
        if rfloat.isfinite(ans[1]):
            ans[1] = rfloat.round_double(ans[1], decimals, half_even=True)
        return self.box_complex(ans[0], ans[1])

    def rint(self, v):
        return self.round(v)

    # No floor, ceil, trunc in numpy for complex
    #@simple_unary_op
    #def floor(self, v):
    #    return math.floor(v)

    #@simple_unary_op
    #def ceil(self, v):
    #    return math.ceil(v)

    #@simple_unary_op
    #def trunc(self, v):
    #    if v < 0:
    #        return math.ceil(v)
    #    else:
    #        return math.floor(v)

    @complex_unary_op
    def exp(self, v):
        if math.isinf(v[1]):
            if math.isinf(v[0]):
                if v[0] < 0:
                    return 0., 0.
                return rfloat.INFINITY, rfloat.NAN
            elif (rfloat.isfinite(v[0]) or \
                                 (math.isinf(v[0]) and v[0] > 0)):
                return rfloat.NAN, rfloat.NAN
        try:
            return rcomplex.c_exp(*v)
        except OverflowError:
            if v[1] == 0:
                return rfloat.INFINITY, 0.0
            return rfloat.INFINITY, rfloat.NAN

    @complex_unary_op
    def exp2(self, v):
        try:
            return rcomplex.c_pow((2,0), v)
        except OverflowError:
            return rfloat.INFINITY, rfloat.NAN
        except ValueError:
            return rfloat.NAN, rfloat.NAN

    @complex_unary_op
    def expm1(self, v):
        # duplicate exp() so in the future it will be easier
        # to implement seterr
        if math.isinf(v[1]):
            if math.isinf(v[0]):
                if v[0] < 0:
                    return -1., 0.
                return rfloat.NAN, rfloat.NAN
            elif (rfloat.isfinite(v[0]) or \
                                 (math.isinf(v[0]) and v[0] > 0)):
                return rfloat.NAN, rfloat.NAN
        try:
            res = rcomplex.c_exp(*v)
            res = (res[0]-1, res[1])
            return res
        except OverflowError:
            if v[1] == 0:
                return rfloat.INFINITY, 0.0
            return rfloat.INFINITY, rfloat.NAN

    @complex_unary_op
    def sin(self, v):
        if math.isinf(v[0]):
            if v[1] == 0.:
                return rfloat.NAN, 0.
            if rfloat.isfinite(v[1]):
                return rfloat.NAN, rfloat.NAN
            elif not math.isnan(v[1]):
                return rfloat.NAN, rfloat.INFINITY
        return rcomplex.c_sin(*v)

    @complex_unary_op
    def cos(self, v):
        if math.isinf(v[0]):
            if v[1] == 0.:
                return rfloat.NAN, 0.0
            if rfloat.isfinite(v[1]):
                return rfloat.NAN, rfloat.NAN
            elif not math.isnan(v[1]):
                return rfloat.INFINITY, rfloat.NAN
        return rcomplex.c_cos(*v)

    @complex_unary_op
    def tan(self, v):
        if math.isinf(v[0]) and rfloat.isfinite(v[1]):
            return rfloat.NAN, rfloat.NAN
        return rcomplex.c_tan(*v)

    @complex_unary_op
    def arcsin(self, v):
        return rcomplex.c_asin(*v)

    @complex_unary_op
    def arccos(self, v):
        return rcomplex.c_acos(*v)

    @complex_unary_op
    def arctan(self, v):
        if v[0] == 0 and (v[1] == 1 or v[1] == -1):
            #This is the place to print a "runtime warning"
            return rfloat.NAN, math.copysign(rfloat.INFINITY, v[1])
        return rcomplex.c_atan(*v)

    #@complex_binary_op
    #def arctan2(self, v1, v2):
    #    return rcomplex.c_atan2(v1, v2)

    @complex_unary_op
    def sinh(self, v):
        if math.isinf(v[1]):
            if rfloat.isfinite(v[0]):
                if v[0] == 0.0:
                    return 0.0, rfloat.NAN
                return rfloat.NAN, rfloat.NAN
            elif not math.isnan(v[0]):
                return rfloat.INFINITY, rfloat.NAN
        return rcomplex.c_sinh(*v)

    @complex_unary_op
    def cosh(self, v):
        if math.isinf(v[1]):
            if rfloat.isfinite(v[0]):
                if v[0] == 0.0:
                    return rfloat.NAN, 0.0
                return rfloat.NAN, rfloat.NAN
            elif not math.isnan(v[0]):
                return rfloat.INFINITY, rfloat.NAN
        return rcomplex.c_cosh(*v)

    @complex_unary_op
    def tanh(self, v):
        if math.isinf(v[1]) and rfloat.isfinite(v[0]):
            return rfloat.NAN, rfloat.NAN
        return rcomplex.c_tanh(*v)

    @complex_unary_op
    def arcsinh(self, v):
        return rcomplex.c_asinh(*v)

    @complex_unary_op
    def arccosh(self, v):
        return rcomplex.c_acosh(*v)

    @complex_unary_op
    def arctanh(self, v):
        if v[1] == 0 and (v[0] == 1.0 or v[0] == -1.0):
            return (math.copysign(rfloat.INFINITY, v[0]),
                   math.copysign(0., v[1]))
        return rcomplex.c_atanh(*v)

    @complex_unary_op
    def sqrt(self, v):
        return rcomplex.c_sqrt(*v)

    @complex_unary_op
    def square(self, v):
        return rcomplex.c_mul(v,v)

    @raw_unary_op
    def isfinite(self, v):
        return rfloat.isfinite(v[0]) and rfloat.isfinite(v[1])

    #@simple_unary_op
    #def radians(self, v):
    #    return v * degToRad
    #deg2rad = radians

    #@simple_unary_op
    #def degrees(self, v):
    #    return v / degToRad

    @complex_unary_op
    def log(self, v):
        try:
            return rcomplex.c_log(*v)
        except ValueError:
            return -rfloat.INFINITY, math.atan2(v[1], v[0])

    @complex_unary_op
    def log2(self, v):
        try:
            r = rcomplex.c_log(*v)
        except ValueError:
            r = -rfloat.INFINITY, math.atan2(v[1], v[0])
        return r[0] / log2, r[1] / log2

    @complex_unary_op
    def log10(self, v):
        try:
            return rcomplex.c_log10(*v)
        except ValueError:
            return -rfloat.INFINITY, math.atan2(v[1], v[0]) / log10

    @complex_unary_op
    def log1p(self, v):
        try:
            return rcomplex.c_log(v[0] + 1, v[1])
        except OverflowError:
            return -rfloat.INFINITY, 0
        except ValueError:
            return rfloat.NAN, rfloat.NAN

class Complex64(ComplexFloating, BaseType):
    T = rffi.FLOAT
    num = NPY.CFLOAT
    kind = NPY.COMPLEXLTR
    char = NPY.CFLOATLTR
    BoxType = boxes.W_Complex64Box
    ComponentBoxType = boxes.W_Float32Box
    ComponentType = Float32

class Complex128(ComplexFloating, BaseType):
    T = rffi.DOUBLE
    num = NPY.CDOUBLE
    kind = NPY.COMPLEXLTR
    char = NPY.CDOUBLELTR
    BoxType = boxes.W_Complex128Box
    ComponentBoxType = boxes.W_Float64Box
    ComponentType = Float64

if boxes.long_double_size == 8:
    class FloatLong(Float, BaseType):
        T = rffi.DOUBLE
        num = NPY.LONGDOUBLE
        kind = NPY.FLOATINGLTR
        char = NPY.LONGDOUBLELTR
        BoxType = boxes.W_FloatLongBox
        format_code = "d"

    class ComplexLong(ComplexFloating, BaseType):
        T = rffi.DOUBLE
        num = NPY.CLONGDOUBLE
        kind = NPY.COMPLEXLTR
        char = NPY.CLONGDOUBLELTR
        BoxType = boxes.W_ComplexLongBox
        ComponentBoxType = boxes.W_FloatLongBox
        ComponentType = FloatLong

elif boxes.long_double_size in (12, 16):
    class FloatLong(Float, BaseType):
        T = rffi.LONGDOUBLE
        num = NPY.LONGDOUBLE
        kind = NPY.FLOATINGLTR
        char = NPY.LONGDOUBLELTR
        BoxType = boxes.W_FloatLongBox

        def runpack_str(self, space, s, native):
            assert len(s) == boxes.long_double_size
            fval = self.box(unpack_float80(s, native_is_bigendian))
            if not native:
                fval = self.byteswap(fval)
            return fval

        def byteswap(self, w_v):
            value = self.unbox(w_v)
            result = StringBuilder(10)
            pack_float80(result, value, 10, not native_is_bigendian)
            return self.box(unpack_float80(result.build(), native_is_bigendian))

    class ComplexLong(ComplexFloating, BaseType):
        T = rffi.LONGDOUBLE
        num = NPY.CLONGDOUBLE
        kind = NPY.COMPLEXLTR
        char = NPY.CLONGDOUBLELTR
        BoxType = boxes.W_ComplexLongBox
        ComponentBoxType = boxes.W_FloatLongBox
        ComponentType = FloatLong

_all_objs_for_tests = [] # for tests

class ObjectType(Primitive, BaseType):
    T = lltype.Signed
    num = NPY.OBJECT
    kind = NPY.OBJECTLTR
    char = NPY.OBJECTLTR
    BoxType = boxes.W_ObjectBox

    def get_element_size(self):
        return rffi.sizeof(lltype.Signed)

    def coerce(self, space, dtype, w_item):
        if isinstance(w_item, boxes.W_ObjectBox):
            return w_item
        return boxes.W_ObjectBox(w_item)

    def coerce_subtype(self, space, w_subtype, w_item):
        # return the item itself
        return self.unbox(self.box(w_item))

    def store(self, arr, i, offset, box, native):
        if arr.gcstruct is V_OBJECTSTORE:
            raise oefmt(self.space.w_NotImplementedError,
                "cannot store object in array with no gc hook")
        self._write(arr.storage, i, offset, self.unbox(box),
                    arr.gcstruct)

    def read(self, arr, i, offset, dtype):
        if arr.gcstruct is V_OBJECTSTORE and not arr.base():
            raise oefmt(self.space.w_NotImplementedError,
                "cannot read object from array with no gc hook")
        return self.box(self._read(arr.storage, i, offset))

    def byteswap(self, w_v):
        return w_v

    @jit.dont_look_inside
    def _write(self, storage, i, offset, w_obj, gcstruct):
        # no GC anywhere in this function!
        if we_are_translated():
            from rpython.rlib import rgc
            rgc.ll_writebarrier(gcstruct)
            value = rffi.cast(lltype.Signed, cast_instance_to_gcref(w_obj))
        else:
            value = len(_all_objs_for_tests)
            _all_objs_for_tests.append(w_obj)
        raw_storage_setitem_unaligned(storage, i + offset, value)

    @jit.dont_look_inside
    def _read(self, storage, i, offset, native=True):
        res = raw_storage_getitem_unaligned(self.T, storage, i + offset)
        if we_are_translated():
            gcref = rffi.cast(llmemory.GCREF, res)
            w_obj = cast_gcref_to_instance(W_Root, gcref)
        else:
            w_obj = _all_objs_for_tests[res]
        return w_obj

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        value = self.unbox(box)
        for i in xrange(start, stop, width):
            self._write(storage, i, offset, value, gcstruct)

    def unbox(self, box):
        if isinstance(box, self.BoxType):
            return box.w_obj
        else:
            raise oefmt(self.space.w_NotImplementedError,
                "object dtype cannot unbox %s", str(box))

    @specialize.argtype(1)
    def box(self, w_obj):
        if isinstance(w_obj, W_Root):
            pass
        elif isinstance(w_obj, bool):
            w_obj = self.space.newbool(w_obj)
        elif isinstance(w_obj, int):
            w_obj = self.space.newint(w_obj)
        elif isinstance(w_obj, lltype.Number):
            w_obj = self.space.newint(w_obj)
        elif isinstance(w_obj, float):
            w_obj = self.space.newfloat(w_obj)
        elif w_obj is None:
            w_obj = self.space.w_None
        else:
            raise oefmt(self.space.w_NotImplementedError,
                "cannot create object array/scalar from lltype")
        return self.BoxType(w_obj)

    @specialize.argtype(1, 2)
    def box_complex(self, real, imag):
        if isinstance(real, rffi.r_singlefloat):
            real = rffi.cast(rffi.DOUBLE, real)
        if isinstance(imag, rffi.r_singlefloat):
            imag = rffi.cast(rffi.DOUBLE, imag)
        w_obj = self.space.newcomplex(real, imag)
        return self.BoxType(w_obj)

    def str_format(self, box, add_quotes=True):
        if not add_quotes:
            as_str = self.space.text_w(self.space.repr(self.unbox(box)))
            as_strl = len(as_str) - 1
            if as_strl>1 and as_str[0] == "'" and as_str[as_strl] == "'":
                as_str = as_str[1:as_strl]
            return as_str
        return self.space.text_w(self.space.repr(self.unbox(box)))

    def runpack_str(self, space, s, native):
        raise oefmt(space.w_NotImplementedError,
                    "fromstring not implemented for object type")

    def to_builtin_type(self, space, box):
        assert isinstance(box, self.BoxType)
        return box.w_obj

    @staticmethod
    def for_computation(v):
        return v

    @raw_binary_op
    def eq(self, v1, v2):
        return self.space.eq_w(v1, v2)

    @simple_binary_op
    def max(self, v1, v2):
        if self.space.is_true(self.space.ge(v1, v2)):
            return v1
        return v2

    @simple_binary_op
    def min(self, v1, v2):
        if self.space.is_true(self.space.le(v1, v2)):
            return v1
        return v2

    @raw_binary_op
    def argmax(self, v1, v2):
        if self.space.is_true(self.space.ge(v1, v2)):
            return True
        return False

    @raw_binary_op
    def argmin(self, v1, v2):
        if self.space.is_true(self.space.le(v1, v2)):
            return True
        return False

    @raw_unary_op
    def bool(self,v):
        return self._obool(v)

    def _obool(self, v):
        if self.space.is_true(v):
            return True
        return False

    @raw_binary_op
    def logical_and(self, v1, v2):
        if self._obool(v1):
            return self.box(v2)
        return self.box(v1)

    @raw_binary_op
    def logical_or(self, v1, v2):
        if self._obool(v1):
            return self.box(v1)
        return self.box(v2)

    @raw_unary_op
    def logical_not(self, v):
        return not self._obool(v)

    @raw_binary_op
    def logical_xor(self, v1, v2):
        a = self._obool(v1)
        b = self._obool(v2)
        return (not b and a) or (not a and b)

    @simple_binary_op
    def bitwise_and(self, v1, v2):
        return self.space.and_(v1, v2)

    @simple_binary_op
    def bitwise_or(self, v1, v2):
        return self.space.or_(v1, v2)

    @simple_binary_op
    def bitwise_xor(self, v1, v2):
        return self.space.xor(v1, v2)

    @simple_binary_op
    def pow(self, v1, v2):
        return self.space.pow(v1, v2, self.space.newint(1))

    @simple_unary_op
    def reciprocal(self, v1):
        return self.space.div(self.space.newfloat(1.0), v1)

    @simple_unary_op
    def sign(self, v):
        zero = self.space.newint(0)
        one = self.space.newint(1)
        m_one = self.space.newint(-1)
        if self.space.is_true(self.space.gt(v, zero)):
            return one
        elif self.space.is_true(self.space.lt(v, zero)):
            return m_one
        else:
            return zero

    @simple_unary_op
    def real(self, v):
        return v

    @simple_unary_op
    def imag(self, v):
        return 0

    @simple_unary_op
    def square(self, v):
        return self.space.mul(v, v)

    @raw_binary_op
    def le(self, v1, v2):
        return self.space.bool_w(self.space.le(v1, v2))

    @raw_binary_op
    def ge(self, v1, v2):
        return self.space.bool_w(self.space.ge(v1, v2))

    @raw_binary_op
    def lt(self, v1, v2):
        return self.space.bool_w(self.space.lt(v1, v2))

    @raw_binary_op
    def gt(self, v1, v2):
        return self.space.bool_w(self.space.gt(v1, v2))

    @raw_binary_op
    def ne(self, v1, v2):
        return self.space.bool_w(self.space.ne(v1, v2))

def add_attributeerr_op(cls, op):
    def func(self, *args):
        raise oefmt(self.space.w_AttributeError,
            "%s", op)
    func.__name__ = 'object_' + op
    setattr(cls, op, func)

def add_unsupported_op(cls, op):
    def func(self, *args):
        raise oefmt(self.space.w_TypeError,
            "ufunc '%s' not supported for input types", op)
    func.__name__ = 'object_' + op
    setattr(cls, op, func)

def add_unary_op(cls, op, method):
    @simple_unary_op
    def func(self, w_v):
        space = self.space
        w_impl = space.lookup(w_v, method)
        if w_impl is None:
            raise oefmt(space.w_AttributeError, 'unknown op "%s" on object' % op)
        return space.get_and_call_function(w_impl, w_v)
    func.__name__ = 'object_' + op
    setattr(cls, op, func)

def add_space_unary_op(cls, op):
    @simple_unary_op
    def func(self, v):
        return getattr(self.space, op)(v)
    func.__name__ = 'object_' + op
    setattr(cls, op, func)

def add_space_binary_op(cls, op):
    @simple_binary_op
    def func(self, v1, v2):
        return getattr(self.space, op)(v1, v2)
    func.__name__ = 'object_' + op
    setattr(cls, op, func)

for op in ('copysign', 'isfinite', 'isinf', 'isnan', 'logaddexp', 'logaddexp2',
           'signbit'):
    add_unsupported_op(ObjectType, op)
for op in ('arctan2', 'arccos', 'arccosh', 'arcsin', 'arcsinh', 'arctan',
           'arctanh', 'ceil', 'floor', 'cos', 'sin', 'tan', 'cosh', 'sinh',
           'tanh', 'radians', 'degrees', 'exp','exp2', 'expm1', 'fabs',
           'log', 'log10', 'log1p', 'log2', 'sqrt', 'trunc'):
    add_attributeerr_op(ObjectType, op)
for op in ('abs', 'neg', 'pos', 'invert'):
    add_space_unary_op(ObjectType, op)
for op, method in (('conj', 'descr_conjugate'), ('rint', 'descr_rint')):
    add_unary_op(ObjectType, op, method)
for op in ('add', 'floordiv', 'div', 'mod', 'mul', 'sub', 'lshift', 'rshift'):
    add_space_binary_op(ObjectType, op)

ObjectType.fmax = ObjectType.max
ObjectType.fmin = ObjectType.min
ObjectType.fmod = ObjectType.mod

class FlexibleType(BaseType):
    def get_element_size(self):
        return rffi.sizeof(self.T)

    def to_str(self, item):
        return item.raw_str()

def str_unary_op(func):
    specialize.argtype(1)(func)
    @functools.wraps(func)
    def dispatcher(self, v1):
        return func(self, self.to_str(v1))
    return dispatcher

def str_binary_op(func):
    specialize.argtype(1, 2)(func)
    @functools.wraps(func)
    def dispatcher(self, v1, v2):
        return func(self,
            self.to_str(v1),
            self.to_str(v2)
        )
    return dispatcher

class StringType(FlexibleType):
    T = lltype.Char
    num = NPY.STRING
    kind = NPY.STRINGLTR
    char = NPY.STRINGLTR

    @jit.unroll_safe
    def coerce(self, space, dtype, w_item):
        if isinstance(w_item, boxes.W_StringBox):
            return w_item
        if w_item is None:
            w_item = space.newbytes('')
        arg = space.text_w(space.str(w_item))
        arr = VoidBoxStorage(dtype.elsize, dtype)
        with arr as storage:
            j = min(len(arg), dtype.elsize)
            for i in range(j):
                storage[i] = arg[i]
            for j in range(j, dtype.elsize):
                storage[j] = '\x00'
            return boxes.W_StringBox(arr,  0, arr.dtype)

    def store(self, arr, i, offset, box, native):
        assert isinstance(box, boxes.W_StringBox)
        size = min(arr.dtype.elsize - offset, box.arr.size - box.ofs)
        with arr as storage:
            return self._store(storage, i, offset, box, size)

    @jit.unroll_safe
    def _store(self, storage, i, offset, box, size):
        assert isinstance(box, boxes.W_StringBox)
        with box.arr as box_storage:
            for k in range(size):
                storage[k + offset + i] = box_storage[k + box.ofs]

    def read(self, arr, i, offset, dtype):
        return boxes.W_StringBox(arr, i + offset, dtype)

    def str_format(self, item, add_quotes=True):
        builder = StringBuilder()
        if add_quotes:
            builder.append("'")
        builder.append(self.to_str(item))
        if add_quotes:
            builder.append("'")
        return builder.build()

    # XXX move the rest of this to base class when UnicodeType is supported
    def to_builtin_type(self, space, box):
        return space.newbytes(self.to_str(box))

    @str_binary_op
    def eq(self, v1, v2):
        return v1 == v2

    @str_binary_op
    def ne(self, v1, v2):
        return v1 != v2

    @str_binary_op
    def lt(self, v1, v2):
        return v1 < v2

    @str_binary_op
    def le(self, v1, v2):
        return v1 <= v2

    @str_binary_op
    def gt(self, v1, v2):
        return v1 > v2

    @str_binary_op
    def ge(self, v1, v2):
        return v1 >= v2

    @str_binary_op
    def logical_and(self, v1, v2):
        if bool(v1) and bool(v2):
            return Bool._True
        return Bool._False

    @str_binary_op
    def logical_or(self, v1, v2):
        if bool(v1) or bool(v2):
            return Bool._True
        return Bool._False

    @str_unary_op
    def logical_not(self, v):
        return not bool(v)

    @str_binary_op
    def logical_xor(self, v1, v2):
        a = bool(v1)
        b = bool(v2)
        return (not b and a) or (not a and b)

    def bool(self, v):
        return bool(self.to_str(v))

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        for i in xrange(start, stop, width):
            self._store(storage, i, offset, box, width)

class UnicodeType(FlexibleType):
    T = lltype.UniChar
    num = NPY.UNICODE
    kind = NPY.UNICODELTR
    char = NPY.UNICODELTR

    def get_element_size(self):
        return 4  # always UTF-32

    @jit.unroll_safe
    def coerce(self, space, dtype, w_item):
        if isinstance(w_item, boxes.W_UnicodeBox):
            return w_item
        if isinstance(w_item, boxes.W_ObjectBox):
            value = space.utf8_w(space.unicode_from_object(w_item.w_obj))
        else:
            value = space.utf8_w(space.unicode_from_object(w_item))
        return boxes.W_UnicodeBox(value)

    def convert_utf8_to_unichar_list(self, utf8):
        l = []
        for ch in Utf8StringIterator(utf8):
            l.append(unichr(ch))
        return l

    def store(self, arr, i, offset, box, native):
        assert isinstance(box, boxes.W_UnicodeBox)
        with arr as storage:
            self._store(storage, i, offset, box, arr.dtype.elsize)

    @jit.unroll_safe
    def _store(self, storage, i, offset, box, width):
        v = self.convert_utf8_to_unichar_list(box._value)
        size = min(width // 4, len(v))
        for k in range(size):
            index = i + offset + 4*k
            data = rffi.cast(Int32.T, ord(v[k]))
            raw_storage_setitem_unaligned(storage, index, data)
        # zero out the remaining memory
        for index in range(size * 4 + i + offset, width):
            data = rffi.cast(Int8.T, 0)
            raw_storage_setitem_unaligned(storage, index, data)

    def read(self, arr, i, offset, dtype):
        if dtype is None:
            dtype = arr.dtype
        size = dtype.elsize // 4
        builder = Utf8StringBuilder(size)
        with arr as storage:
            for k in range(size):
                index = i + offset + 4*k
                codepoint = rffi.cast(lltype.Signed,
                    raw_storage_getitem_unaligned(
                    Int32.T, arr.storage, index))
                if codepoint == 0:
                    break
                builder.append_code(codepoint)
        return boxes.W_UnicodeBox(builder.build())

    def str_format(self, item, add_quotes=True):
        assert isinstance(item, boxes.W_UnicodeBox)
        if add_quotes:
            w_unicode = self.to_builtin_type(self.space, item)
            return self.space.text_w(self.space.repr(w_unicode))
        else:
            # Same as W_UnicodeBox.descr_repr() but without quotes and prefix
            from rpython.rlib.runicode import unicode_encode_unicode_escape
            return unicode_encode_unicode_escape(item._value,
                                                 len(item._value), 'strict')

    def to_builtin_type(self, space, box):
        assert isinstance(box, boxes.W_UnicodeBox)
        return space.newutf8(box._value, codepoints_in_utf8(box._value))

    def eq(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value == v2._value

    def ne(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value != v2._value

    def lt(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value < v2._value

    def le(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value <= v2._value

    def gt(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value > v2._value

    def ge(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        return v1._value >= v2._value

    def logical_and(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        if bool(v1) and bool(v2):
            return Bool._True
        return Bool._False

    def logical_or(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        if bool(v1) or bool(v2):
            return Bool._True
        return Bool._False

    def logical_not(self, v):
        assert isinstance(v, boxes.W_UnicodeBox)
        return not bool(v)

    def logical_xor(self, v1, v2):
        assert isinstance(v1, boxes.W_UnicodeBox)
        assert isinstance(v2, boxes.W_UnicodeBox)
        a = bool(v1)
        b = bool(v2)
        return (not b and a) or (not a and b)

    def bool(self, v):
        assert isinstance(v, boxes.W_UnicodeBox)
        return bool(v._value)

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        assert isinstance(box, boxes.W_UnicodeBox)
        for i in xrange(start, stop, width):
            self._store(storage, i, offset, box, width)


class VoidType(FlexibleType):
    T = lltype.Char
    num = NPY.VOID
    kind = NPY.VOIDLTR
    char = NPY.VOIDLTR

    def _coerce(self, space, arr, ofs, dtype, w_items, shape):
        # TODO: Make sure the shape and the array match
        from pypy.module.micronumpy.descriptor import W_Dtype
        if w_items is None:
            items_w = [None] * shape[0]
        elif support.issequence_w(space, w_items):
            items_w = space.fixedview(w_items)
        else:
            items_w = [w_items] * shape[0]
        subdtype = dtype.subdtype
        assert isinstance(subdtype, W_Dtype)
        itemtype = subdtype.itemtype
        if len(shape) <= 1:
            for i in range(len(items_w)):
                w_box = subdtype.coerce(space, items_w[i])
                subdtype.store(arr, 0, ofs, w_box)
                ofs += itemtype.get_element_size()
        else:
            for w_item in items_w:
                size = 1
                for dimension in shape[1:]:
                    size *= dimension
                size *= itemtype.get_element_size()
                self._coerce(space, arr, ofs, dtype, w_item, shape[1:])
                ofs += size

    def coerce(self, space, dtype, w_items):
        if dtype.is_record():
            # the dtype is a union of a void and a record,
            return record_coerce(self, space, dtype, w_items)
        arr = VoidBoxStorage(dtype.elsize, dtype)
        self._coerce(space, arr, 0, dtype, w_items, dtype.shape)
        return boxes.W_VoidBox(arr, 0, dtype)

    @jit.unroll_safe
    def store(self, arr, i, offset, box, native):
        assert isinstance(box, boxes.W_VoidBox)
        assert box.dtype is box.arr.dtype
        with arr as arr_storage, box.arr as box_storage:
            for k in range(box.arr.dtype.elsize):
                arr_storage[i + k + offset] = box_storage[k + box.ofs]

    def readarray(self, arr, i, offset, dtype=None):
        from pypy.module.micronumpy.base import W_NDimArray
        if dtype is None:
            dtype = arr.dtype
        strides, backstrides = calc_strides(dtype.shape, dtype.subdtype,
                                            arr.order)
        implementation = SliceArray(i + offset, strides, backstrides,
                                    dtype.shape, arr, W_NDimArray(arr),
                                    dtype.subdtype)
        return W_NDimArray(implementation)

    def read(self, arr, i, offset, dtype):
        return boxes.W_VoidBox(arr, i + offset, dtype)

    @jit.unroll_safe
    def str_format(self, box, add_quotes=True):
        assert isinstance(box, boxes.W_VoidBox)
        arr = self.readarray(box.arr, box.ofs, 0, box.dtype)
        return arr.dump_data(prefix='', suffix='')

    def to_builtin_type(self, space, item):
        ''' From the documentation of ndarray.item():
        "Void arrays return a buffer object for item(),
         unless fields are defined, in which case a tuple is returned."
        '''
        assert isinstance(item, boxes.W_VoidBox)
        dt = item.arr.dtype
        ret_unwrapped = []
        for name in dt.names:
            ofs, dtype = dt.fields[name[0]]
            # XXX: code duplication with W_VoidBox.descr_getitem()
            if isinstance(dtype.itemtype, VoidType):
                read_val = dtype.itemtype.readarray(item.arr, ofs, 0, dtype)
            else:
                read_val = dtype.read(item.arr, ofs, 0)
            if isinstance (read_val, boxes.W_StringBox):
                # StringType returns a str
                read_val = space.newbytes(dtype.itemtype.to_str(read_val))
            ret_unwrapped = ret_unwrapped + [read_val,]
        if len(ret_unwrapped) == 0:
            raise oefmt(space.w_NotImplementedError,
                        "item() for Void aray with no fields not implemented")
        return space.newtuple(ret_unwrapped)

class CharType(StringType):
    char = NPY.CHARLTR

def record_coerce(typ, space, dtype, w_item):
        from pypy.module.micronumpy.base import W_NDimArray
        if isinstance(w_item, boxes.W_VoidBox):
            if dtype == w_item.dtype:
                return w_item
            else:
                # match up the field names
                items_w = [None] * len(dtype.names)
                for i in range(len(dtype.names)):
                    name = dtype.names[i]
                    if name in w_item.dtype.names:
                        items_w[i] = w_item.descr_getitem(space, space.newtext(name[0]))
        elif w_item is not None:
            if space.isinstance_w(w_item, space.w_tuple):
                if len(dtype.names) != space.len_w(w_item):
                    raise oefmt(space.w_ValueError,
                                "size of tuple must match number of fields.")
                items_w = space.fixedview(w_item)
            elif isinstance(w_item, W_NDimArray) and w_item.is_scalar():
                items_w = space.fixedview(w_item.get_scalar_value())
            elif space.isinstance_w(w_item, space.w_list):
                raise oefmt(space.w_TypeError,
                            "expected a readable buffer object")
            else:
                # XXX support initializing from readable buffers
                items_w = [w_item] * len(dtype.names)
        else:
            items_w = [None] * len(dtype.fields)
        arr = VoidBoxStorage(dtype.elsize, dtype)
        for i in range(len(dtype.names)):
            ofs, subdtype = dtype.fields[dtype.names[i][0]]
            try:
                w_box = subdtype.coerce(space, items_w[i])
            except IndexError:
                w_box = subdtype.coerce(space, None)
            subdtype.store(arr, 0, ofs, w_box)
        return boxes.W_VoidBox(arr, 0, dtype)

class RecordType(FlexibleType):
    T = lltype.Char
    num = NPY.VOID
    kind = NPY.VOIDLTR
    char = NPY.VOIDLTR

    def read(self, arr, i, offset, dtype):
        return boxes.W_VoidBox(arr, i + offset, dtype)

    @jit.unroll_safe
    def coerce(self, space, dtype, w_item):
        return record_coerce(self, space, dtype, w_item)

    def runpack_str(self, space, s, native):
        raise oefmt(space.w_NotImplementedError,
                    "fromstring not implemented for record types")

    def store(self, arr, i, offset, box, native):
        assert isinstance(box, boxes.W_VoidBox)
        with arr as storage:
            self._store(storage, i, offset, box, box.dtype.elsize)

    @jit.unroll_safe
    def _store(self, storage, i, ofs, box, size):
        with box.arr as box_storage:
            for k in range(size):
                storage[k + i + ofs] = box_storage[k + box.ofs]

    def fill(self, storage, width, native, box, start, stop, offset, gcstruct):
        assert isinstance(box, boxes.W_VoidBox)
        assert width == box.dtype.elsize
        for i in xrange(start, stop, width):
            self._store(storage, i, offset, box, width)

    def byteswap(self, w_v):
        # XXX implement
        return w_v

    def to_builtin_type(self, space, box):
        assert isinstance(box, boxes.W_VoidBox)
        items = []
        dtype = box.dtype
        for name in dtype.names:
            ofs, subdtype = dtype.fields[name[0]]
            subbox = subdtype.read(box.arr, box.ofs, ofs)
            items.append(subdtype.itemtype.to_builtin_type(space, subbox))
        return space.newtuple(items)

    @jit.unroll_safe
    def str_format(self, box, add_quotes=True):
        assert isinstance(box, boxes.W_VoidBox)
        pieces = ["("]
        first = True
        for name in box.dtype.names:
            ofs, subdtype = box.dtype.fields[name[0]]
            if first:
                first = False
            else:
                pieces.append(", ")
            val = subdtype.read(box.arr, box.ofs, ofs)
            tp = subdtype.itemtype
            pieces.append(tp.str_format(val, add_quotes=add_quotes))
        pieces.append(")")
        return "".join(pieces)

    def eq(self, v1, v2):
        assert isinstance(v1, boxes.W_VoidBox)
        assert isinstance(v2, boxes.W_VoidBox)
        s1 = v1.dtype.elsize
        s2 = v2.dtype.elsize
        assert s1 == s2
        with v1.arr as v1_storage, v2.arr as v2_storage:
            for i in range(s1):
                if v1_storage[v1.ofs + i] != v2_storage[v2.ofs + i]:
                    return False
        return True

    def ne(self, v1, v2):
        return not self.eq(v1, v2)

for tp in [Int32, Int64]:
    if tp.T == lltype.Signed:
        IntP = tp
        break
for tp in [UInt32, UInt64]:
    if tp.T == lltype.Unsigned:
        UIntP = tp
        break
del tp

all_float_types = []
float_types = []
all_int_types = []
int_types = []
all_complex_types = []
complex_types = []

_REQ_STRLEN = [0, 3, 5, 10, 10, 20, 20, 20, 20]  # data for can_cast_to()
def _setup():
    # compute alignment
    for tp in globals().values():
        if isinstance(tp, type) and hasattr(tp, 'T'):
            tp.alignment = widen(clibffi.cast_type_to_ffitype(tp.T).c_alignment)
            if issubclass(tp, Float):
                all_float_types.append((tp, 'float'))
                float_types.append(tp)
            if issubclass(tp, Integer):
                all_int_types.append((tp, 'int'))
                int_types.append(tp)
                elsize = tp(ObjSpace()).get_element_size()
                tp.strlen = _REQ_STRLEN[elsize]
                if tp.kind == NPY.SIGNEDLTR:
                    tp.strlen += 1
            if issubclass(tp, ComplexFloating):
                all_complex_types.append((tp, 'complex'))
                complex_types.append(tp)
    for l in [float_types, int_types, complex_types]:
        l.sort(key=lambda tp: tp.num)
_setup()
del _setup

number_types = int_types + float_types + complex_types
all_types = [Bool] + number_types + [ObjectType, StringType, UnicodeType, VoidType]



_int_types = [(Int8, UInt8), (Int16, UInt16), (Int32, UInt32),
        (Int64, UInt64), (Long, ULong)]
for Int_t, UInt_t in _int_types:
    Int_t.Unsigned = UInt_t
    UInt_t.Signed = Int_t
    size = rffi.sizeof(Int_t.T)
    Int_t.min_value = rffi.cast(Int_t.T, -1) << (8*size - 1)
    Int_t.max_value = ~Int_t.min_value
    UInt_t.max_value = ~rffi.cast(UInt_t.T, 0)


signed_types = [Int8, Int16, Int32, Int64, Long]

def make_integer_min_dtype(Int_t, UInt_t):
    smaller_types = [tp for tp in signed_types
            if rffi.sizeof(tp.T) < rffi.sizeof(Int_t.T)]
    smaller_types = unrolling_iterable(
            [(tp, tp.Unsigned) for tp in smaller_types])
    def min_dtype(self):
        value = rffi.cast(UInt64.T, self.value)
        for Small, USmall in smaller_types:
            signed_max = rffi.cast(UInt64.T, Small.max_value)
            unsigned_max = rffi.cast(UInt64.T, USmall.max_value)
            if value <= unsigned_max:
                if value <= signed_max:
                    return Small.num, USmall.num
                else:
                    return USmall.num, USmall.num
        if value <= rffi.cast(UInt64.T, Int_t.max_value):
            return Int_t.num, UInt_t.num
        else:
            return UInt_t.num, UInt_t.num
    UInt_t.BoxType.min_dtype = min_dtype

    def min_dtype(self):
        value = rffi.cast(Int64.T, self.value)
        if value >= 0:
            for Small, USmall in smaller_types:
                signed_max = rffi.cast(Int64.T, Small.max_value)
                unsigned_max = rffi.cast(Int64.T, USmall.max_value)
                if value <= unsigned_max:
                    if value <= signed_max:
                        return Small.num, USmall.num
                    else:
                        return USmall.num, USmall.num
            return Int_t.num, UInt_t.num
        else:
            for Small, USmall in smaller_types:
                signed_min = rffi.cast(Int64.T, Small.min_value)
                if value >= signed_min:
                        return Small.num, Small.num
            return Int_t.num, Int_t.num
    Int_t.BoxType.min_dtype = min_dtype

for Int_t in signed_types:
    UInt_t = Int_t.Unsigned
    make_integer_min_dtype(Int_t, UInt_t)


smaller_float_types = {
    Float16: [], Float32: [Float16], Float64: [Float16, Float32],
    FloatLong: [Float16, Float32, Float64]}

def make_float_min_dtype(Float_t):
    smaller_types = unrolling_iterable(smaller_float_types[Float_t])
    smallest_type = Float16

    def min_dtype(self):
        value = float(self.value)
        if not rfloat.isfinite(value):
            tp = smallest_type
        else:
            for SmallFloat in smaller_types:
                if -SmallFloat.max_value < value < SmallFloat.max_value:
                    tp = SmallFloat
                    break
            else:
                tp = Float_t
        return tp.num, tp.num
    Float_t.BoxType.min_dtype = min_dtype

for Float_t in float_types:
    make_float_min_dtype(Float_t)

smaller_complex_types = {
    Complex64: [], Complex128: [Complex64],
    ComplexLong: [Complex64, Complex128]}

def make_complex_min_dtype(Complex_t):
    smaller_types = unrolling_iterable(smaller_complex_types[Complex_t])

    def min_dtype(self):
        real, imag = float(self.real), float(self.imag)
        for CSmall in smaller_types:
            max_value = CSmall.ComponentType.max_value

            if -max_value < real < max_value and -max_value < imag < max_value:
                tp = CSmall
                break
        else:
            tp = Complex_t
        return tp.num, tp.num
    Complex_t.BoxType.min_dtype = min_dtype

for Complex_t in complex_types:
    make_complex_min_dtype(Complex_t)

def min_dtype(self):
    return Bool.num, Bool.num
Bool.BoxType.min_dtype = min_dtype
