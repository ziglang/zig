from pypy.interpreter.error import oefmt
from pypy.interpreter.unicodehelper import utf8_encode_utf_16, utf8_encode_utf_32
from pypy.objspace.std.unicodeobject import W_UnicodeObject

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import r_singlefloat, r_longfloat
from rpython.rlib.rbigint import rbigint

from pypy.module._cffi_backend import newtype

# Mixins to refactor type-specific codef from converter and executor classes
# (in converter.py and executor.py, respectively). To get the right mixin, a
# non-RPython function typeid() is used.

class State(object):
    def __init__(self, space):
        nt = newtype     # module from _cffi_backend

        # the below are (expected to be) lookups, not actual new types, hence
        # the underlying wrapped primitive class need not be specified

        # builtin types
        self.c_void    = nt.new_void_type(space)
        self.c_bool    = nt.new_primitive_type(space, '_Bool')
        self.c_char    = nt.new_primitive_type(space, 'char')
        self.c_uchar   = nt.new_primitive_type(space, 'unsigned char')
        self.c_short   = nt.new_primitive_type(space, 'short')
        self.c_ushort  = nt.new_primitive_type(space, 'unsigned short')
        self.c_int     = nt.new_primitive_type(space, 'int')
        self.c_uint    = nt.new_primitive_type(space, 'unsigned int')
        self.c_long    = nt.new_primitive_type(space, 'long')
        self.c_ulong   = nt.new_primitive_type(space, 'unsigned long')
        self.c_llong   = nt.new_primitive_type(space, 'long long')
        self.c_ullong  = nt.new_primitive_type(space, 'unsigned long long')
        self.c_float   = nt.new_primitive_type(space, 'float')
        self.c_double  = nt.new_primitive_type(space, 'double')
        self.c_ldouble = nt.new_primitive_type(space, 'long double')
        
        # pointer types
        self.c_ccharp = nt.new_pointer_type(space, self.c_char)
        self.c_voidp  = nt.new_pointer_type(space, self.c_void)
        self.c_voidpp = nt.new_pointer_type(space, self.c_voidp)

        # special types
        self.c_int8_t    = nt.new_primitive_type(space, 'int8_t')
        self.c_uint8_t   = nt.new_primitive_type(space, 'uint8_t')
        self.c_size_t    = nt.new_primitive_type(space, 'size_t')
        self.c_ptrdiff_t = nt.new_primitive_type(space, 'ptrdiff_t')
        self.c_intptr_t  = nt.new_primitive_type(space, 'intptr_t')
        self.c_uintptr_t = nt.new_primitive_type(space, 'uintptr_t')
        self.c_wchar_t   = nt.new_primitive_type(space, 'wchar_t')
        self.c_char16_t  = nt.new_primitive_type(space, 'char16_t')
        self.c_char32_t  = nt.new_primitive_type(space, 'char32_t')


class BoolTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.UCHAR
    c_ptrtype   = rffi.UCHARP

    def _wrap_object(self, space, obj):
        return space.newbool(bool(ord(rffi.cast(rffi.CHAR, obj))))

    def _unwrap_object(self, space, w_obj):
        arg = space.c_int_w(w_obj)
        if arg != False and arg != True:
            raise oefmt(space.w_ValueError,
                        "boolean value should be bool, or integer 1 or 0")
        return arg

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_bool

class CharTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.CHAR
    c_ptrtype   = rffi.CCHARP           # there's no such thing as rffi.CHARP

    def _wrap_object(self, space, obj):
        return space.newbytes(rffi.cast(self.c_type, obj))

    def _unwrap_object(self, space, w_value):
        # allow int to pass to char and make sure that str is of length 1
        if space.isinstance_w(w_value, space.w_int):
            ival = space.c_int_w(w_value)
            if ival < -128 or 127 < ival:
                raise oefmt(space.w_ValueError, "char arg not in range(-128,128)")

            value = rffi.cast(rffi.CHAR, space.c_int_w(w_value))
        else:
            if space.isinstance_w(w_value, space.w_text):
                value = space.text_w(w_value)
            else:
                value = space.bytes_w(w_value)
            if len(value) != 1:
                raise oefmt(space.w_ValueError,
                            "char expected, got string of size %d", len(value))

            value = rffi.cast(rffi.CHAR, value[0])
        return value

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_char

class SCharTypeMixin(CharTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.SIGNEDCHAR
    c_ptrtype   = rffi.CCHARP           # SIGNEDCHARP is not recognized as a char type for str

    def _wrap_object(self, space, obj):
        return space.newbytes(rffi.cast(rffi.CHAR, rffi.cast(self.c_type, obj)))

class UCharTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.UCHAR
    c_ptrtype   = rffi.CCHARP           # UCHARP is not recognized as a char type for str

    def _wrap_object(self, space, obj):
        return space.newbytes(obj)

    def _unwrap_object(self, space, w_value):
        # allow int to pass to char and make sure that str is of length 1
        if space.isinstance_w(w_value, space.w_int):
            ival = space.c_int_w(w_value)
            if ival < 0 or 256 <= ival:
                raise oefmt(space.w_ValueError, "char arg not in range(256)")

            value = rffi.cast(rffi.CHAR, space.c_int_w(w_value))
        else:
            if space.isinstance_w(w_value, space.w_text):
                value = space.text_w(w_value)
            else:
                value = space.bytes_w(w_value)
            if len(value) != 1:
                raise oefmt(space.w_ValueError,
                            "unsigned char expected, got string of size %d", len(value))

            value = rffi.cast(rffi.CHAR, value[0])
        return value     # turn it into a "char" to the annotator

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_char

class WCharTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = lltype.UniChar
    c_ptrtype   = rffi.CWCHARP

    def _wrap_object(self, space, obj):
        result = rffi.cast(self.c_type, obj)
        u = rffi.cast(lltype.UniChar, result)
        return W_UnicodeObject(u.encode('utf8'), 1)

    def _unwrap_object(self, space, w_value):
        utf8, length = space.utf8_len_w(space.unicode_from_object(w_value))
        if length != 1:
            raise oefmt(space.w_ValueError,
                        "wchar_t expected, got string of size %d", length)

        with rffi.scoped_utf82wcharp(utf8, length) as u:
            value = rffi.cast(self.c_type, u[0])
        return value

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_wchar_t


def select_sized_int(size):
    for t, p in [(rffi.SHORT, rffi.SHORTP), (rffi.INT, rffi.INTP), (rffi.LONG, rffi.LONGP)]:
        if rffi.sizeof(t) == size:
            return t, p
    raise NotImplementedError("no integer type of size %d available" % size)

CHAR16_T = 'char16_t'
class Char16TypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type, c_ptrtype = select_sized_int(2)

    def _wrap_object(self, space, obj):
        result = rffi.cast(self.c_type, obj)
        u = rffi.cast(lltype.UniChar, result)
        return W_UnicodeObject(u.encode('utf8'), 1)

    def _unwrap_object(self, space, w_value):
        utf8, length = space.utf8_len_w(space.unicode_from_object(w_value))
        if length != 1:
            raise oefmt(space.w_ValueError,
                        "char16_t expected, got string of size %d", length)

        utf16 = utf8_encode_utf_16(utf8, 'strict')
        rawstr = rffi.str2charp(utf16)
        value = rffi.cast(self.c_ptrtype, lltype.direct_ptradd(rawstr, 2))[0]   # adjust BOM
        lltype.free(rawstr, flavor='raw')
        return value

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_char16_t

CHAR32_T = 'char32_t'
class Char32TypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type, c_ptrtype = select_sized_int(4)

    def _wrap_object(self, space, obj):
        result = rffi.cast(self.c_type, obj)
        u = rffi.cast(lltype.UniChar, result)
        return W_UnicodeObject(u.encode('utf8'), 1)

    def _unwrap_object(self, space, w_value):
        utf8, length = space.utf8_len_w(space.unicode_from_object(w_value))
        if length != 1:
            raise oefmt(space.w_ValueError,
                        "char32_t expected, got string of size %d", length)

        utf32 = utf8_encode_utf_32(utf8, 'strict')
        rawstr = rffi.str2charp(utf32)
        value = rffi.cast(self.c_ptrtype, lltype.direct_ptradd(rawstr, 4))[0]   # adjust BOM
        lltype.free(rawstr, flavor='raw')
        return value

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_char32_t


class BaseIntTypeMixin(object):
    _mixin_     = True

    def _wrap_object(self, space, obj):
        return space.newint(rffi.cast(rffi.INT, rffi.cast(self.c_type, obj)))

    def _unwrap_object(self, space, w_obj):
        return rffi.cast(self.c_type, space.c_int_w(w_obj))

INT8_T = 'int8_t'
class Int8TypeMixin(BaseIntTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.SIGNEDCHAR
    c_ptrtype   = rffi.SIGNEDCHARP

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_int8_t

UINT8_T = 'uint8_t'
class UInt8TypeMixin(BaseIntTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.UCHAR
    c_ptrtype   = rffi.UCHARP

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_uint8_t

class ShortTypeMixin(BaseIntTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.SHORT
    c_ptrtype   = rffi.SHORTP

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_short

class UShortTypeMixin(BaseIntTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.USHORT
    c_ptrtype   = rffi.USHORTP

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_ushort

class IntTypeMixin(BaseIntTypeMixin):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.INT
    c_ptrtype   = rffi.INTP

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_int

class UIntTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.UINT
    c_ptrtype   = rffi.UINTP

    def _wrap_object(self, space, obj):
        return space.newlong_from_rarith_int(obj)

    def _unwrap_object(self, space, w_obj):
        return rffi.cast(self.c_type, space.uint_w(w_obj))

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_uint

class LongTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.LONG
    c_ptrtype   = rffi.LONGP

    def _wrap_object(self, space, obj):
        return space.newlong(obj)

    def _unwrap_object(self, space, w_obj):
        return space.int_w(w_obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_long

class ULongTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.ULONG
    c_ptrtype   = rffi.ULONGP

    def _wrap_object(self, space, obj):
        return space.newlong_from_rarith_int(obj)

    def _unwrap_object(self, space, w_obj):
        return space.uint_w(w_obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_ulong

class LongLongTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.LONGLONG
    c_ptrtype   = rffi.LONGLONGP

    def _wrap_object(self, space, obj):
        return space.newlong_from_rarith_int(obj)

    def _unwrap_object(self, space, w_obj):
        return space.r_longlong_w(w_obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_llong

class ULongLongTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype']

    c_type      = rffi.ULONGLONG
    c_ptrtype   = rffi.ULONGLONGP

    def _wrap_object(self, space, obj):
        return space.newlong_from_rarith_int(obj)

    def _unwrap_object(self, space, w_obj):
        return space.r_ulonglong_w(w_obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_ullong

class FloatTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype', 'typecode']

    c_type      = rffi.FLOAT
    c_ptrtype   = rffi.FLOATP
    typecode    = 'f'

    def _unwrap_object(self, space, w_obj):
        return r_singlefloat(space.float_w(w_obj))

    def _wrap_object(self, space, obj):
        return space.newfloat(float(obj))

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_float

class DoubleTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype', 'typecode']

    c_type      = rffi.DOUBLE
    c_ptrtype   = rffi.DOUBLEP
    typecode    = 'd'

    def _wrap_object(self, space, obj):
        return space.newfloat(obj)

    def _unwrap_object(self, space, w_obj):
        return space.float_w(w_obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_double

class LongDoubleTypeMixin(object):
    _mixin_     = True
    _immutable_fields_ = ['c_type', 'c_ptrtype', 'typecode']

    c_type      = rffi.LONGDOUBLE
    # c_ptrtype   = rffi.LONGDOUBLEP   # useless type at this point
    c_ptrtype   = rffi.VOIDP
    typecode    = 'g'

    # long double is not really supported ...
    def _unwrap_object(self, space, w_obj):
        return r_longfloat(space.float_w(w_obj))

    def _wrap_object(self, space, obj):
        return space.newfloat(obj)

    def cffi_type(self, space):
        state = space.fromcache(State)
        return state.c_ldouble

def typeid(c_type):
    "NOT_RPYTHON"
    if c_type == bool:            return BoolTypeMixin
    if c_type == rffi.CHAR:       return CharTypeMixin
    if c_type == rffi.SIGNEDCHAR: return SCharTypeMixin
    if c_type == rffi.UCHAR:      return UCharTypeMixin
    if c_type == lltype.UniChar:  return WCharTypeMixin    # rffi.W_CHAR_T is rffi.INT
    if c_type == CHAR16_T:        return Char16TypeMixin   # no type in rffi
    if c_type == CHAR32_T:        return Char32TypeMixin   # id.
    if c_type == INT8_T:          return Int8TypeMixin     # id.
    if c_type == UINT8_T:         return UInt8TypeMixin    # id.
    if c_type == rffi.SHORT:      return ShortTypeMixin
    if c_type == rffi.USHORT:     return UShortTypeMixin
    if c_type == rffi.INT:        return IntTypeMixin
    if c_type == rffi.UINT:       return UIntTypeMixin
    if c_type == rffi.LONG:       return LongTypeMixin
    if c_type == rffi.ULONG:      return ULongTypeMixin
    if c_type == rffi.LONGLONG:   return LongLongTypeMixin
    if c_type == rffi.ULONGLONG:  return ULongLongTypeMixin
    if c_type == rffi.FLOAT:      return FloatTypeMixin
    if c_type == rffi.DOUBLE:     return DoubleTypeMixin
    if c_type == rffi.LONGDOUBLE: return LongDoubleTypeMixin

    # should never get here
    raise TypeError("unknown rffi type: %s" % c_type)
