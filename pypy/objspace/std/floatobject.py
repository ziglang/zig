import math
import operator
import sys

from rpython.rlib import rarithmetic, rfloat
from rpython.rlib.rarithmetic import LONG_BIT, intmask, ovfcheck_float_to_int
from rpython.rlib.rarithmetic import int_between
from rpython.rlib.rbigint import rbigint
from rpython.rlib.rfloat import (
    DTSF_ADD_DOT_0, INFINITY, NAN,
    float_as_rbigint_ratio, formatd, isfinite)
from rpython.rlib.rstring import ParseStringError
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem.module.ll_math import math_fmod
from rpython.tool.sourcetools import func_with_new_name

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import WrappedDefault, interp2app, unwrap_spec
from pypy.interpreter.typedef import GetSetProperty, TypeDef
from pypy.objspace.std import newformat
from pypy.objspace.std.intobject import HASH_BITS, HASH_MODULUS, W_IntObject
from pypy.objspace.std.longobject import (
    W_AbstractLongObject, newlong_from_float)
from rpython.rlib.rarithmetic import (
    LONG_BIT, intmask, ovfcheck_float_to_int, r_uint)
from pypy.objspace.std.util import wrap_parsestringerror

HASH_INF  = 314159
HASH_NAN  = 0

# Here 0.30103 is an upper bound for log10(2)
NDIGITS_MAX = int((rfloat.DBL_MANT_DIG - rfloat.DBL_MIN_EXP) * 0.30103)
NDIGITS_MIN = -int((rfloat.DBL_MAX_EXP + 1) * 0.30103)

def float2string(x, code, precision):
    # we special-case explicitly inf and nan here
    if isfinite(x):
        s = formatd(x, code, precision, DTSF_ADD_DOT_0)
    elif math.isinf(x):
        if x > 0.0:
            s = "inf"
        else:
            s = "-inf"
    else:  # isnan(x):
        s = "nan"
    return s


def detect_floatformat():
    from rpython.rtyper.lltypesystem import rffi, lltype
    buf = lltype.malloc(rffi.CCHARP.TO, 8, flavor='raw')
    rffi.cast(rffi.DOUBLEP, buf)[0] = 9006104071832581.0
    packed = rffi.charpsize2str(buf, 8)
    if packed == "\x43\x3f\xff\x01\x02\x03\x04\x05":
        double_format = 'IEEE, big-endian'
    elif packed == "\x05\x04\x03\x02\x01\xff\x3f\x43":
        double_format = 'IEEE, little-endian'
    else:
        double_format = 'unknown'
    lltype.free(buf, flavor='raw')
    #
    buf = lltype.malloc(rffi.CCHARP.TO, 4, flavor='raw')
    rffi.cast(rffi.FLOATP, buf)[0] = rarithmetic.r_singlefloat(16711938.0)
    packed = rffi.charpsize2str(buf, 4)
    if packed == "\x4b\x7f\x01\x02":
        float_format = 'IEEE, big-endian'
    elif packed == "\x02\x01\x7f\x4b":
        float_format = 'IEEE, little-endian'
    else:
        float_format = 'unknown'
    lltype.free(buf, flavor='raw')

    return double_format, float_format

_double_format, _float_format = detect_floatformat()


_alpha = zip("abcdef", range(10, 16)) + zip("ABCDEF", range(10, 16))
_hex_to_int = zip("0123456789", range(10)) + _alpha
_hex_to_int_iterable = unrolling_iterable(_hex_to_int)

def _hex_from_char(c):
    for h, v in _hex_to_int_iterable:
        if h == c:
            return v
    return -1

def _hex_digit(s, j, co_end, float_digits):
    if j < float_digits:
        i = co_end - j
    else:
        i = co_end - 1 - j
    return _hex_from_char(s[i])

def _char_from_hex(number):
    return "0123456789abcdef"[number]


def make_compare_func(opname):
    op = getattr(operator, opname)

    if opname == 'eq' or opname == 'ne':
        def do_compare_bigint(f1, b2):
            """f1 is a float.  b2 is a bigint."""
            if not isfinite(f1) or math.floor(f1) != f1:
                return opname == 'ne'
            b1 = rbigint.fromfloat(f1)
            res = b1.eq(b2)
            if opname == 'ne':
                res = not res
            return res
    else:
        def do_compare_bigint(f1, b2):
            """f1 is a float.  b2 is a bigint."""
            if not isfinite(f1):
                return op(f1, 0.0)
            if opname == 'gt' or opname == 'le':
                # 'float > long'   <==>  'ceil(float) > long'
                # 'float <= long'  <==>  'ceil(float) <= long'
                f1 = math.ceil(f1)
            else:
                # 'float < long'   <==>  'floor(float) < long'
                # 'float >= long'  <==>  'floor(float) >= long'
                f1 = math.floor(f1)
            b1 = rbigint.fromfloat(f1)
            return getattr(b1, opname)(b2)

    def _compare(self, space, w_other):
        if isinstance(w_other, W_FloatObject):
            return space.newbool(op(self.floatval, w_other.floatval))
        if isinstance(w_other, W_IntObject):
            f1 = self.floatval
            i2 = space.int_w(w_other)
            # (double-)floats have always at least 48 bits of precision
            if LONG_BIT > 32 and not int_between(-1, i2 >> 48, 1):
                res = do_compare_bigint(f1, rbigint.fromint(i2))
            else:
                f2 = float(i2)
                res = op(f1, f2)
            return space.newbool(res)
        if isinstance(w_other, W_AbstractLongObject):
            return space.newbool(do_compare_bigint(self.floatval,
                                                   space.bigint_w(w_other)))
        return space.w_NotImplemented
    return func_with_new_name(_compare, 'descr_' + opname)

def newint_from_float(space, floatval):
    """This is also used from module/math/interp_math.py"""
    try:
        value = ovfcheck_float_to_int(floatval)
    except OverflowError:
        return newlong_from_float(space, floatval)
    else:
        return space.newint(value)


class W_FloatObject(W_Root):
    """This is a implementation of the app-level 'float' type.
    The constructor takes an RPython float as an argument."""
    _immutable_fields_ = ['floatval']

    def __init__(self, floatval):
        self.floatval = floatval

    def unwrap(self, space):
        return self.floatval

    def int_w(self, space, allow_conversion=True):
        self._typed_unwrap_error(space, "integer")

    def bigint_w(self, space, allow_conversion=True):
        self._typed_unwrap_error(space, "integer")

    def float_w(self, space, allow_conversion=True):
        return self.floatval

    def _float_w(self, space):
        return self.floatval

    def int(self, space):
        # this is a speed-up only, for space.int(w_float).
        if (type(self) is not W_FloatObject and
            space.is_overloaded(self, space.w_float, '__int__')):
            return W_Root.int(self, space)
        return self.descr_trunc(space)

    def is_w(self, space, w_other):
        from rpython.rlib.longlong2float import float2longlong
        if not isinstance(w_other, W_FloatObject):
            return False
        if self.user_overridden_class or w_other.user_overridden_class:
            return self is w_other
        one = float2longlong(space.float_w(self))
        two = float2longlong(space.float_w(w_other))
        return one == two

    def immutable_unique_id(self, space):
        if self.user_overridden_class:
            return None
        from rpython.rlib.longlong2float import float2longlong
        from pypy.objspace.std.util import IDTAG_FLOAT as tag
        from pypy.objspace.std.util import IDTAG_SHIFT
        val = float2longlong(space.float_w(self))
        b = rbigint.fromrarith_int(val)
        b = b.lshift(IDTAG_SHIFT).int_or_(tag)
        return space.newlong_from_rbigint(b)

    def __repr__(self):
        return "<W_FloatObject(%f)>" % self.floatval

    @staticmethod
    @unwrap_spec(w_x=WrappedDefault(0.0))
    def descr__new__(space, w_floattype, w_x, __posonly__):
        w_value = w_x     # 'x' is the keyword argument name in CPython
        if space.lookup(w_value, "__float__") is not None:
            w_obj = space.float(w_value)
            w_obj_type = space.type(w_obj)
            if not space.is_w(w_obj_type, space.w_float):
                space.warn(space.newtext(
                    "%s.__float__ returned non-float (type %s).  "
                    "The ability to return an instance of a strict subclass "
                    "of float is deprecated, and may be removed "
                    "in a future version of Python." %
                    (space.type(w_value).name, w_obj_type.name)),
                    space.w_DeprecationWarning)
            elif space.is_w(w_floattype, space.w_float):
                return w_obj
            value = space.float_w(w_obj)
        elif space.lookup(w_value, "__index__") is not None:
            w_obj = space.index(w_value)
            return space.float(w_obj)
        elif space.isinstance_w(w_value, space.w_unicode):
            from unicodeobject import unicode_to_decimal_w
            value = _string_to_float(space, w_value,
                                     unicode_to_decimal_w(space, w_value))
        else:
            try:
                value = space.charbuf_w(w_value)
            except OperationError as e:
                if e.match(space, space.w_TypeError):
                    raise oefmt(space.w_TypeError,
                                "float() argument must be a string or a "
                                "number, not '%T'", w_value)
                raise
            value = _string_to_float(space, w_value, value)
        w_obj = space.allocate_instance(W_FloatObject, w_floattype)
        W_FloatObject.__init__(w_obj, value)
        return w_obj

    @staticmethod
    @unwrap_spec(kind='text')
    def descr___getformat__(space, w_cls, kind):
        if kind == "float":
            return space.newtext(_float_format)
        elif kind == "double":
            return space.newtext(_double_format)
        raise oefmt(space.w_ValueError, "only float and double are valid")

    @staticmethod
    @unwrap_spec(s='text')
    def descr_fromhex(space, w_cls, s):
        """float.fromhex(string) -> float

        Create a floating-point number from a hexadecimal string.
        >>> float.fromhex('0x1.ffffp10')
        2047.984375
        >>> float.fromhex('-0x1p-1074')
        -5e-324

        """
        length = len(s)
        i = 0
        value = 0.0
        while i < length and s[i].isspace():
            i += 1
        if i == length:
            raise oefmt(space.w_ValueError, "invalid hex string")
        sign = 1
        if s[i] == "-":
            sign = -1
            i += 1
        elif s[i] == "+":
            i += 1
        if length == i:
            raise oefmt(space.w_ValueError, "invalid hex string")
        if s[i] == "i" or s[i] == "I":
            i += 1
            if length - i >= 2 and s[i:i + 2].lower() == "nf":
                i += 2
                value = rfloat.INFINITY
                if length - i >= 5 and s[i:i + 5].lower() == "inity":
                    i += 5
        elif s[i] == "n" or s[i] == "N":
            i += 1
            if length - i >= 2 and s[i:i + 2].lower() == "an":
                i += 2
                value = rfloat.NAN
        else:
            if (s[i] == "0" and length - i > 1 and
                (s[i + 1] == "x" or s[i + 1] == "X")):
                i += 2
            co_start = i
            while i < length and _hex_from_char(s[i]) >= 0:
                i += 1
            whole_end = i
            if i < length and s[i] == ".":
                i += 1
                while i < length and _hex_from_char(s[i]) >= 0:
                    i += 1
                co_end = i - 1
            else:
                co_end = i
            total_digits = co_end - co_start
            float_digits = co_end - whole_end
            if not total_digits:
                raise oefmt(space.w_ValueError, "invalid hex string")
            const_one = rfloat.DBL_MIN_EXP - rfloat.DBL_MANT_DIG + sys.maxint // 2
            const_two = sys.maxint // 2 + 1 - rfloat.DBL_MAX_EXP
            if total_digits > min(const_one, const_two) // 4:
                raise oefmt(space.w_ValueError, "way too long")
            if i < length and (s[i] == "p" or s[i] == "P"):
                i += 1
                if i == length:
                    raise oefmt(space.w_ValueError, "invalid hex string")
                exp_sign = 1
                if s[i] == "-" or s[i] == "+":
                    if s[i] == "-":
                        exp_sign = -1
                    i += 1
                    if i == length:
                        raise oefmt(space.w_ValueError, "invalid hex string")
                if not s[i].isdigit():
                    raise oefmt(space.w_ValueError, "invalid hex string")
                exp = ord(s[i]) - ord('0')
                i += 1
                while i < length and s[i].isdigit():
                    exp = exp * 10 + (ord(s[i]) - ord('0'))
                    if exp >= (sys.maxint-9) // 10:
                        if exp_sign > 0:
                            exp_sign = 2    # overflow in positive numbers
                        else:
                            exp_sign = -2   # overflow in negative numbers
                    i += 1
                if exp_sign == -1:
                    exp = -exp
                elif exp_sign == -2:
                    exp = -sys.maxint / 2
                elif exp_sign == 2:
                    exp = sys.maxint / 2
            else:
                exp = 0
            while (total_digits and
                   _hex_digit(s, total_digits - 1, co_end, float_digits) == 0):
                total_digits -= 1
            if not total_digits or exp <= -sys.maxint / 2:
                value = 0.0
            elif exp >= sys.maxint // 2:
                raise oefmt(space.w_OverflowError, "too large")
            else:
                exp -= 4 * float_digits
                top_exp = exp + 4 * (total_digits - 1)
                digit = _hex_digit(s, total_digits - 1, co_end, float_digits)
                while digit:
                    top_exp += 1
                    digit //= 2
                if top_exp < rfloat.DBL_MIN_EXP - rfloat.DBL_MANT_DIG:
                    value = 0.0
                elif top_exp > rfloat.DBL_MAX_EXP:
                    raise oefmt(space.w_OverflowError, "too large")
                else:
                    lsb = max(top_exp, rfloat.DBL_MIN_EXP) - rfloat.DBL_MANT_DIG
                    value = 0
                    if exp >= lsb:
                        for j in range(total_digits - 1, -1, -1):
                            value = 16.0 * value + _hex_digit(s, j, co_end,
                                                              float_digits)
                        value = math.ldexp(value, exp)
                    else:
                        half_eps = 1 << ((lsb - exp - 1) % 4)
                        key_digit = (lsb - exp - 1) // 4
                        for j in range(total_digits - 1, key_digit, -1):
                            value = 16.0 * value + _hex_digit(s, j, co_end,
                                                              float_digits)
                        digit = _hex_digit(s, key_digit, co_end, float_digits)
                        value = 16.0 * value + (digit & (16 - 2*half_eps))
                        if digit & half_eps:
                            round_up = False
                            if (digit & (3 * half_eps - 1) or
                                (half_eps == 8 and key_digit + 1 < float_digits and
                                 _hex_digit(s, key_digit + 1, co_end, float_digits) & 1)):
                                round_up = True
                            else:
                                for j in range(key_digit - 1, -1, -1):
                                    if _hex_digit(s, j, co_end, float_digits):
                                        round_up = True
                                        break
                            if round_up:
                                value += 2 * half_eps
                                mant_dig = rfloat.DBL_MANT_DIG
                                if (top_exp == rfloat.DBL_MAX_EXP and
                                    value == math.ldexp(2 * half_eps, mant_dig)):
                                    raise oefmt(space.w_OverflowError, "too large")
                        value = math.ldexp(value, (exp + 4*key_digit))
        while i < length and s[i].isspace():
            i += 1
        if i != length:
            raise oefmt(space.w_ValueError, "invalid hex string")
        w_float = space.newfloat(sign * value)
        return space.call_function(w_cls, w_float)

    def _to_float(self, space, w_obj):
        if isinstance(w_obj, W_FloatObject):
            return w_obj
        if space.isinstance_w(w_obj, space.w_int):
            return W_FloatObject(space.float_w(w_obj))

    def descr___round__(self, space, w_ndigits=None):
        return _round_float(space, self, w_ndigits)

    def descr_repr(self, space):
        return space.newtext(float2string(self.floatval, 'r', 0))
    descr_str = func_with_new_name(descr_repr, 'descr_str')

    def descr_hash(self, space):
        h = _hash_float(space, self.floatval)
        return space.newint(h)

    def descr_format(self, space, w_spec):
        return newformat.run_formatter(space, w_spec, "format_float", self)

    def descr_bool(self, space):
        return space.newbool(self.floatval != 0.0)

    def descr_float(self, space):
        if space.is_w(space.type(self), space.w_float):
            return self
        a = self.floatval
        return W_FloatObject(a)

    def descr_trunc(self, space):
        return newint_from_float(space, self.floatval)

    def descr_floor(self, space):
        return newint_from_float(space, math.floor(self.floatval))

    def descr_ceil(self, space):
        return newint_from_float(space, math.ceil(self.floatval))

    def descr_neg(self, space):
        return W_FloatObject(-self.floatval)

    def descr_pos(self, space):
        return self.descr_float(space)

    def descr_abs(self, space):
        return W_FloatObject(abs(self.floatval))

    def descr_getnewargs(self, space):
        return space.newtuple([self.descr_float(space)])

    descr_eq = make_compare_func('eq')
    descr_ne = make_compare_func('ne')
    descr_lt = make_compare_func('lt')
    descr_le = make_compare_func('le')
    descr_gt = make_compare_func('gt')
    descr_ge = make_compare_func('ge')

    def descr_add(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return W_FloatObject(self.floatval + w_rhs.floatval)

    def descr_radd(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return W_FloatObject(w_lhs.floatval + self.floatval)

    def descr_sub(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return W_FloatObject(self.floatval - w_rhs.floatval)

    def descr_rsub(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return W_FloatObject(w_lhs.floatval - self.floatval)

    def descr_mul(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return W_FloatObject(self.floatval * w_rhs.floatval)

    def descr_rmul(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return W_FloatObject(w_lhs.floatval * self.floatval)

    def descr_div(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        rhs = w_rhs.floatval
        if rhs == 0.0:
            raise oefmt(space.w_ZeroDivisionError, "float division by zero")
        return W_FloatObject(self.floatval / rhs)

    def descr_rdiv(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        selfval = self.floatval
        if selfval == 0.0:
            raise oefmt(space.w_ZeroDivisionError, "float division by zero")
        return W_FloatObject(w_lhs.floatval / selfval)

    def descr_floordiv(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return _divmod_w(space, self, w_rhs)[0]

    def descr_rfloordiv(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return _divmod_w(space, w_lhs, self)[0]

    def descr_mod(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        x = self.floatval
        y = w_rhs.floatval
        if y == 0.0:
            raise oefmt(space.w_ZeroDivisionError, "float modulo")
        mod = math_fmod(x, y)
        if mod:
            # ensure the remainder has the same sign as the denominator
            if (y < 0.0) != (mod < 0.0):
                mod += y
        else:
            # the remainder is zero, and in the presence of signed zeroes
            # fmod returns different results across platforms; ensure
            # it has the same sign as the denominator; we'd like to do
            # "mod = y * 0.0", but that may get optimized away
            mod = math.copysign(0.0, y)

        return W_FloatObject(mod)

    def descr_rmod(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return w_lhs.descr_mod(space, self)

    def descr_divmod(self, space, w_rhs):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return space.newtuple(_divmod_w(space, self, w_rhs))

    def descr_rdivmod(self, space, w_lhs):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return space.newtuple(_divmod_w(space, w_lhs, self))

    @unwrap_spec(w_third_arg=WrappedDefault(None))
    def descr_pow(self, space, w_rhs, w_third_arg):
        w_rhs = self._to_float(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        if not space.is_w(w_third_arg, space.w_None):
            raise oefmt(space.w_TypeError, "pow() 3rd argument not allowed "
                                           "unless all arguments are integers")
        x = self.floatval
        y = w_rhs.floatval

        try:
            result = _pow(space, x, y)
        except PowDomainError:
            # Negative numbers raised to fractional powers become complex
            return space.pow(space.newcomplex(x, 0.0),
                             space.newcomplex(y, 0.0),
                             w_third_arg)
        return W_FloatObject(result)

    @unwrap_spec(w_third_arg=WrappedDefault(None))
    def descr_rpow(self, space, w_lhs, w_third_arg):
        w_lhs = self._to_float(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return w_lhs.descr_pow(space, self, w_third_arg)

    def descr_get_real(self, space):
        return space.float(self)

    def descr_get_imag(self, space):
        return space.newfloat(0.0)

    def descr_conjugate(self, space):
        return space.float(self)

    def descr_is_integer(self, space):
        v = self.floatval
        if not rfloat.isfinite(v):
            return space.w_False
        return space.newbool(math.floor(v) == v)

    def descr_as_integer_ratio(self, space):
        """float.as_integer_ratio() -> (int, int)

        Return a pair of integers, whose ratio is exactly equal to the
        original float and with a positive denominator.  Raise
        OverflowError on infinities and a ValueError on NaNs.

        >>> (10.0).as_integer_ratio()
        (10, 1)
        >>> (0.0).as_integer_ratio()
        (0, 1)
        >>> (-.25).as_integer_ratio()
        (-1, 4)

        """
        value = self.floatval
        try:
            num, den = float_as_rbigint_ratio(value)
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "cannot convert Infinity to integer ratio")
        except ValueError:
            raise oefmt(space.w_ValueError,
                        "cannot convert NaN to integer ratio")

        w_num = space.newlong_from_rbigint(num)
        w_den = space.newlong_from_rbigint(den)
        # Try to return int
        return space.newtuple([space.int(w_num), space.int(w_den)])

    def descr_hex(self, space):
        """float.hex() -> string

        Return a hexadecimal representation of a floating-point
        number.

        >>> (-0.1).hex()
        '-0x1.999999999999ap-4'
        >>> 3.14159.hex()
        '0x1.921f9f01b866ep+1'

        """
        TOHEX_NBITS = rfloat.DBL_MANT_DIG + 3 - (rfloat.DBL_MANT_DIG + 2) % 4
        value = self.floatval
        if not isfinite(value):
            return self.descr_str(space)
        if value == 0.0:
            if math.copysign(1., value) == -1.:
                return space.newtext("-0x0.0p+0")
            else:
                return space.newtext("0x0.0p+0")
        mant, exp = math.frexp(value)
        shift = 1 - max(rfloat.DBL_MIN_EXP - exp, 0)
        mant = math.ldexp(mant, shift)
        mant = abs(mant)
        exp -= shift
        result = ['\0'] * ((TOHEX_NBITS - 1) // 4 + 2)
        result[0] = _char_from_hex(int(mant))
        mant -= int(mant)
        result[1] = "."
        for i in range((TOHEX_NBITS - 1) // 4):
            mant *= 16.0
            result[i + 2] = _char_from_hex(int(mant))
            mant -= int(mant)
        if exp < 0:
            sign = "-"
        else:
            sign = "+"
        exp = abs(exp)
        s = ''.join(result)
        if value < 0.0:
            return space.newtext("-0x%sp%s%d" % (s, sign, exp))
        else:
            return space.newtext("0x%sp%s%d" % (s, sign, exp))


W_FloatObject.typedef = TypeDef("float",
    __doc__ = '''float(x) -> floating point number

Convert a string or number to a floating point number, if possible.''',
    __new__ = interp2app(W_FloatObject.descr__new__),
    __getformat__ = interp2app(W_FloatObject.descr___getformat__, as_classmethod=True),
    __round__ = interp2app(W_FloatObject.descr___round__),
    fromhex = interp2app(W_FloatObject.descr_fromhex, as_classmethod=True),
    __repr__ = interp2app(W_FloatObject.descr_repr),
    __str__ = interp2app(W_FloatObject.descr_str),
    __hash__ = interp2app(W_FloatObject.descr_hash),
    __format__ = interp2app(W_FloatObject.descr_format),
    __bool__ = interp2app(W_FloatObject.descr_bool),
    __int__ = interp2app(W_FloatObject.descr_trunc),
    __float__ = interp2app(W_FloatObject.descr_float),
    __trunc__ = interp2app(W_FloatObject.descr_trunc),
    __floor__ = interp2app(W_FloatObject.descr_floor),
    __ceil__ = interp2app(W_FloatObject.descr_ceil),
    __neg__ = interp2app(W_FloatObject.descr_neg),
    __pos__ = interp2app(W_FloatObject.descr_pos),
    __abs__ = interp2app(W_FloatObject.descr_abs),
    __getnewargs__ = interp2app(W_FloatObject.descr_getnewargs),

    __eq__ = interp2app(W_FloatObject.descr_eq),
    __ne__ = interp2app(W_FloatObject.descr_ne),
    __lt__ = interp2app(W_FloatObject.descr_lt),
    __le__ = interp2app(W_FloatObject.descr_le),
    __gt__ = interp2app(W_FloatObject.descr_gt),
    __ge__ = interp2app(W_FloatObject.descr_ge),

    __add__ = interp2app(W_FloatObject.descr_add),
    __radd__ = interp2app(W_FloatObject.descr_radd),
    __sub__ = interp2app(W_FloatObject.descr_sub),
    __rsub__ = interp2app(W_FloatObject.descr_rsub),
    __mul__ = interp2app(W_FloatObject.descr_mul),
    __rmul__ = interp2app(W_FloatObject.descr_rmul),
    __truediv__ = interp2app(W_FloatObject.descr_div),
    __rtruediv__ = interp2app(W_FloatObject.descr_rdiv),
    __floordiv__ = interp2app(W_FloatObject.descr_floordiv),
    __rfloordiv__ = interp2app(W_FloatObject.descr_rfloordiv),
    __mod__ = interp2app(W_FloatObject.descr_mod),
    __rmod__ = interp2app(W_FloatObject.descr_rmod),
    __divmod__ = interp2app(W_FloatObject.descr_divmod),
    __rdivmod__ = interp2app(W_FloatObject.descr_rdivmod),
    __pow__ = interp2app(W_FloatObject.descr_pow),
    __rpow__ = interp2app(W_FloatObject.descr_rpow),

    real = GetSetProperty(W_FloatObject.descr_get_real),
    imag = GetSetProperty(W_FloatObject.descr_get_imag),
    conjugate = interp2app(W_FloatObject.descr_conjugate),
    is_integer = interp2app(W_FloatObject.descr_is_integer),
    as_integer_ratio = interp2app(W_FloatObject.descr_as_integer_ratio),
    hex = interp2app(W_FloatObject.descr_hex),
)

def _remove_underscores(string):
    i = 0
    prev = '?'
    res = []
    for i in range(len(string)):
        c = string[i]
        if c == '_':
            # undercores can only come after digits
            if not ord('0') <= ord(prev) <= ord('9'):
                raise ValueError
        else:
            res.append(c)
            # undercores can only come before digits
            if prev == '_' and not ord('0') <= ord(c) <= ord('9'):
                raise ValueError
        prev = c
    if prev == "_": # not allowed at end
        raise ValueError
    return "".join(res)

def _string_to_float(space, w_source, string):
    try:
        if "_" in string:
            string = _remove_underscores(string)
    except ValueError:
        pass
    else:
        try:
            return rfloat.string_to_float(string)
        except ParseStringError as e:
            pass
    raise oefmt(space.w_ValueError,
                "could not convert string to float: %R", w_source)

def _hash_float(space, v):
    if not isfinite(v):
        if math.isinf(v):
            return HASH_INF if v > 0 else -HASH_INF
        return HASH_NAN

    m, e = math.frexp(v)

    sign = 1
    if m < 0:
        sign = -1
        m = -m

    # process 28 bits at a time;  this should work well both for binary
    # and hexadecimal floating point.
    x = r_uint(0)
    while m:
        x = ((x << 28) & HASH_MODULUS) | x >> (HASH_BITS - 28)
        m *= 268435456.0  # 2**28
        e -= 28
        y = r_uint(m)  # pull out integer part
        m -= y
        x += y
        if x >= HASH_MODULUS:
            x -= HASH_MODULUS

    # adjust for the exponent;  first reduce it modulo HASH_BITS
    e = e % HASH_BITS if e >= 0 else HASH_BITS - 1 - ((-1 - e) % HASH_BITS)
    x = ((x << e) & HASH_MODULUS) | x >> (HASH_BITS - e)

    x = intmask(intmask(x) * sign)
    x -= (x == -1)
    return x


def _divmod_w(space, w_float1, w_float2):
    x = w_float1.floatval
    y = w_float2.floatval
    if y == 0.0:
        raise oefmt(space.w_ZeroDivisionError, "float modulo")
    mod = math_fmod(x, y)
    # fmod is typically exact, so vx-mod is *mathematically* an
    # exact multiple of wx.  But this is fp arithmetic, and fp
    # vx - mod is an approximation; the result is that div may
    # not be an exact integral value after the division, although
    # it will always be very close to one.
    div = (x - mod) / y
    if (mod):
        # ensure the remainder has the same sign as the denominator
        if ((y < 0.0) != (mod < 0.0)):
            mod += y
            div -= 1.0
    else:
        # the remainder is zero, and in the presence of signed zeroes
        # fmod returns different results across platforms; ensure
        # it has the same sign as the denominator; we'd like to do
        # "mod = wx * 0.0", but that may get optimized away
        mod *= mod  # hide "mod = +0" from optimizer
        if y < 0.0:
            mod = -mod
    # snap quotient to nearest integral value
    if div:
        floordiv = math.floor(div)
        if (div - floordiv > 0.5):
            floordiv += 1.0
    else:
        # div is zero - get the same sign as the true quotient
        div *= div  # hide "div = +0" from optimizers
        floordiv = div * x / y  # zero w/ sign of vx/wx

    return [W_FloatObject(floordiv), W_FloatObject(mod)]


class PowDomainError(ValueError):
    """Signals a negative number raised to a fractional power"""

def _pow(space, x, y):
    # Sort out special cases here instead of relying on pow()
    if y == 2.0:       # special case for performance:
        return x * x   # x * x is always correct
    if y == 0.0:
        # x**0 is 1, even 0**0
        return 1.0
    if math.isnan(x):
        # nan**y = nan, unless y == 0
        return x
    if math.isnan(y):
        # x**nan = nan, unless x == 1; x**nan = x
        if x == 1.0:
            return 1.0
        else:
            return y
    if math.isinf(y):
        # x**inf is: 0.0 if abs(x) < 1; 1.0 if abs(x) == 1; inf if
        # abs(x) > 1 (including case where x infinite)
        #
        # x**-inf is: inf if abs(x) < 1; 1.0 if abs(x) == 1; 0.0 if
        # abs(x) > 1 (including case where v infinite)
        x = abs(x)
        if x == 1.0:
            return 1.0
        elif (y > 0.0) == (x > 1.0):
            return INFINITY
        else:
            return 0.0
    if math.isinf(x):
        # (+-inf)**w is: inf for w positive, 0 for w negative; in oth
        # cases, we need to add the appropriate sign if w is an odd
        # integer.
        y_is_odd = math.fmod(abs(y), 2.0) == 1.0
        if y > 0.0:
            if y_is_odd:
                return x
            else:
                return abs(x)
        else:
            if y_is_odd:
                return math.copysign(0.0, x)
            else:
                return 0.0

    if x == 0.0:
        if y < 0.0:
            raise oefmt(space.w_ZeroDivisionError,
                        "0.0 cannot be raised to a negative power")

    negate_result = False
    # special case: "(-1.0) ** bignum" should not raise PowDomainError,
    # unlike "math.pow(-1.0, bignum)".  See http://mail.python.org/
    # -           pipermail/python-bugs-list/2003-March/016795.html
    if x < 0.0:
        if math.isnan(y):
            return NAN
        if math.floor(y) != y:
            raise PowDomainError
        # y is an exact integer, albeit perhaps a very large one.
        # Replace x by its absolute value and remember to negate the
        # pow result if y is odd.
        x = -x
        negate_result = math.fmod(abs(y), 2.0) == 1.0

    if x == 1.0:
        # (-1) ** large_integer also ends up here
        if negate_result:
            return -1.0
        else:
            return 1.0

    try:
        # We delegate to our implementation of math.pow() the error detection.
        z = math.pow(x, y)
    except OverflowError:
        raise oefmt(space.w_OverflowError, "float power")
    except ValueError:
        raise oefmt(space.w_ValueError, "float power")

    if negate_result:
        z = -z
    return z


def _round_float(space, w_float, w_ndigits=None):
    # Algorithm copied directly from CPython
    x = w_float.floatval

    if space.is_none(w_ndigits):
        # single-argument round: round to nearest integer
        rounded = rfloat.round_away(x)
        if math.fabs(x - rounded) == 0.5:
            # halfway case: round to even
            rounded = 2.0 * rfloat.round_away(x / 2.0)
        return newint_from_float(space, rounded)

    # interpret 2nd argument as a Py_ssize_t; clip on overflow
    ndigits = space.getindex_w(w_ndigits, None)

    # nans and infinities round to themselves
    if not rfloat.isfinite(x):
        return space.newfloat(x)

    # Deal with extreme values for ndigits. For ndigits > NDIGITS_MAX, x
    # always rounds to itself.  For ndigits < NDIGITS_MIN, x always
    # rounds to +-0.0
    if ndigits > NDIGITS_MAX:
        return space.newfloat(x)
    elif ndigits < NDIGITS_MIN:
        # return 0.0, but with sign of x
        return space.newfloat(0.0 * x)

    # finite x, and ndigits is not unreasonably large
    z = rfloat.round_double(x, ndigits, half_even=True)
    if math.isinf(z):
        raise oefmt(space.w_OverflowError, "overflow occurred during round")
    return space.newfloat(z)
