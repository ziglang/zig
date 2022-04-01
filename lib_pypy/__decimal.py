# Implementation of the "decimal" module, based on libmpdec library.

__xname__ = __name__    # sys.modules lookup (--without-threads)
__name__ = 'decimal'    # For pickling


import _collections_abc
import math as _math
import numbers as _numbers
import sys as _sys

from _decimal_cffi import ffi as _ffi, lib as _mpdec

# Compatibility with the C version
HAVE_THREADS = True
HAVE_CONTEXTVAR = True
if _sys.maxsize == 2**63-1:
    MAX_PREC = 999999999999999999
    MAX_EMAX = 999999999999999999
    MIN_EMIN = -999999999999999999
else:
    MAX_PREC = 425000000
    MAX_EMAX = 425000000
    MIN_EMIN = -425000000

MIN_ETINY = MIN_EMIN - (MAX_PREC-1)

# Errors

class DecimalException(ArithmeticError):
    def handle(self, context, *args):
        pass

class Clamped(DecimalException):
    pass

class InvalidOperation(DecimalException):
    def handle(self, context, *args):
        if args:
            ans = _dec_from_triple(args[0]._sign, args[0]._int, 'n', True)
            return ans._fix_nan(context)
        return _NaN

class ConversionSyntax(InvalidOperation):
    def handle(self, context, *args):
        return _NaN

class DivisionByZero(DecimalException, ZeroDivisionError):
    def handle(self, context, sign, *args):
        return _SignedInfinity[sign]

class DivisionImpossible(InvalidOperation):
    def handle(self, context, *args):
        return _NaN

class DivisionUndefined(InvalidOperation, ZeroDivisionError):
    def handle(self, context, *args):
        return _NaN

class Inexact(DecimalException):
    pass

class InvalidContext(InvalidOperation):
    def handle(self, context, *args):
        return _NaN

class Rounded(DecimalException):
    pass

class Subnormal(DecimalException):
    pass

class Overflow(Inexact, Rounded):
    def handle(self, context, sign, *args):
        if context.rounding in (ROUND_HALF_UP, ROUND_HALF_EVEN,
                                ROUND_HALF_DOWN, ROUND_UP):
            return _SignedInfinity[sign]
        if sign == 0:
            if context.rounding == ROUND_CEILING:
                return _SignedInfinity[sign]
            return _dec_from_triple(sign, '9'*context.prec,
                            context.Emax-context.prec+1)
        if sign == 1:
            if context.rounding == ROUND_FLOOR:
                return _SignedInfinity[sign]
            return _dec_from_triple(sign, '9'*context.prec,
                             context.Emax-context.prec+1)

class Underflow(Inexact, Rounded, Subnormal):
    pass

class FloatOperation(DecimalException, TypeError):
    pass


__version__ = "1.70"
__libmpdec_version__ = _ffi.string(_mpdec.mpd_version())

# Default context

import threading
__local = threading.local()
del threading

def getcontext():
    """Returns this thread's context.

    If this thread does not yet have a context, returns
    a new context and sets this thread's context.
    New contexts are copies of DefaultContext.
    """
    try:
        return __local.__decimal_context__
    except AttributeError:
        context = Context()
        __local.__decimal_context__ = context
        return context

def _getcontext(context=None):
    if context is None:
        return getcontext()
    if not isinstance(context, Context):
        raise TypeError
    return context

def setcontext(context):
    """Set this thread's context to context."""
    if context in (DefaultContext, BasicContext, ExtendedContext):
        context = context.copy()
        context.clear_flags()
    if not isinstance(context, Context):
        raise TypeError
    __local.__decimal_context__ = context

def localcontext(ctx=None):
    """Return a context manager for a copy of the supplied context.
    """
    return _ContextManager(_getcontext(ctx))


from collections import namedtuple as _namedtuple
DecimalTuple = _namedtuple('DecimalTuple', 'sign digits exponent')


# A codecs error handler to handle unicode digits
import codecs as _codecs
import unicodedata as _unicodedata
def _handle_decimaldigits(exc):
    res = ""
    for c in exc.object[exc.start:exc.end]:
        if c.isspace():
            res += ' '
        else:
            res += str(_unicodedata.digit(c))
    return res, exc.end
_codecs.register_error('_decimal_encode', _handle_decimaldigits)


def _unsafe_check(name, lo, hi, value):
    if not -_sys.maxsize-1 <= value <= _sys.maxsize:
        raise OverflowError(
            "Python int too large to convert to C ssize_t")
    if not lo <= value <= hi:
        raise ValueError("valid range for unsafe %s is [%d, %d]" %
                         (name, lo, hi))


# Decimal class

_DEC_MINALLOC = 4

class Decimal(object):
    __slots__ = ('_mpd', '_data')

    def __new__(cls, value="0", context=None):
        return cls._from_object(value, context, exact=True)

    @classmethod
    def _new_empty(cls):
        self = object.__new__(cls)
        self._mpd = mpd = _ffi.new("struct mpd_t*")
        self._data = _ffi.new("mpd_uint_t[]", _DEC_MINALLOC)
        mpd.flags = _mpdec.MPD_STATIC | _mpdec.MPD_STATIC_DATA
        mpd.alloc = _DEC_MINALLOC
        mpd.exp = 0
        mpd.digits = 0
        mpd.len = 0
        mpd.data = self._data
        return self

    def __del__(self):
        _mpdec.mpd_del(self._mpd)

    @classmethod
    def _from_object(cls, value, context, exact=True):
        if isinstance(value, Decimal):
            return cls._from_decimal(value, context, exact=exact)
        if isinstance(value, str):
            return cls._from_str(value, context, exact=exact, strip=exact)
        if isinstance(value, int):
            return cls._from_int(value, context, exact=exact)
        if isinstance(value, (list, tuple)):
            return cls._from_tuple(value, context, exact=exact)
        if isinstance(value, float):
            context = _getcontext(context)
            context._add_status(_mpdec.MPD_Float_operation)
            return cls._from_float_subclass_handling(value, context, exact=exact)
        raise TypeError("conversion from %s to Decimal is not supported" %
                        value.__class__.__name__)

    @classmethod
    def _from_decimal(cls, value, context, exact=True):
        if exact:
            if cls is Decimal and type(value) is Decimal:
                return value
            self = cls._new_empty()
            with _CatchConversions(self._mpd, context, exact) as (
                    ctx, status_ptr):
                _mpdec.mpd_qcopy(self._mpd, value._mpd, status_ptr)
            return self
        else:
            if (_mpdec.mpd_isnan(value._mpd) and
                value._mpd.digits > (context._ctx.prec - context._ctx.clamp)):
                # Special case: too many NaN payload digits
                context._add_status(_mpdec.MPD_Conversion_syntax)
                self = cls._new_empty()
                _mpdec.mpd_setspecial(self._mpd, _mpdec.MPD_POS, _mpdec.MPD_NAN)
                return self
            else:
                self = cls._new_empty()
                with _CatchStatus(context) as (ctx, status_ptr):
                    _mpdec.mpd_qcopy(self._mpd, value._mpd, status_ptr)
                    _mpdec.mpd_qfinalize(self._mpd, ctx, status_ptr)
                return self

    @classmethod
    def _from_str(cls, value, context, exact=True, strip=True):
        value = value.replace("_", "")
        s = str.encode(value, 'ascii', '_decimal_encode')
        if b'\0' in s:
            s = b''  # empty string triggers ConversionSyntax.
        if strip:
            s = s.strip()
        return cls._from_bytes(s, context, exact=exact)

    @classmethod
    def _from_bytes(cls, value, context, exact=True):
        self = cls._new_empty()
        with _CatchConversions(self._mpd, context, exact) as (ctx, status_ptr):
            _mpdec.mpd_qset_string(self._mpd, value, ctx, status_ptr)
        return self

    @classmethod
    def _from_int(cls, value, context, exact=True):
        value = int(value)     # in case it's a subclass of 'int'
        self = cls._new_empty()
        with _CatchConversions(self._mpd, context, exact) as (ctx, status_ptr):
            size = (((value|1).bit_length() + 15) // 16) + 5
            if value < 0:
                value = -value
                sign = _mpdec.MPD_NEG
            else:
                sign = _mpdec.MPD_POS
            array = value.to_bytes(2*size, byteorder='little', signed=False)
            digits = _ffi.new("uint8_t[]", array)
            _mpdec.mpd_qimport_u16(
                self._mpd, _ffi.cast("uint16_t*", digits),
                size, sign, 0x10000, ctx, status_ptr)
        return self

    @classmethod
    def _from_tuple(cls, value, context, exact=True):
        sign, digits, exponent  = value

        # Make a bytes string representation of a DecimalTuple
        builder = []

        # sign
        if not isinstance(sign, int) or sign not in (0, 1):
            raise ValueError("sign must be an integer with the value 0 or 1")
        builder.append(b'-' if sign else b'+')

        # exponent or encoding for a special number
        is_infinite = False
        is_special = False
        if isinstance(exponent, str):
            # special
            is_special = True
            if exponent == 'F':
                builder.append(b'Inf')
                is_infinite = True
            elif exponent == 'n':
                builder.append(b'Nan')
            elif exponent == 'N':
                builder.append(b'sNan')
            else:
                raise ValueError("string argument in the third position "
                                 "must be 'F', 'n' or 'N'")
            exponent = 0
        else:
            if not isinstance(exponent, int):
                raise ValueError("exponent must be an integer")
            if not -_sys.maxsize-1 <= exponent <= _sys.maxsize:
                # Compatibility with CPython
                raise OverflowError(
                    "Python int too large to convert to C ssize_t")

        # coefficients
        if not digits and not is_special:
            # empty tuple: zero coefficient, except for special numbers
            builder.append(b'0')
        for digit in digits:
            if not isinstance(digit, int) or not 0 <= digit <= 9:
                raise ValueError("coefficient must be a tuple of digits")
            if is_infinite:
                # accept but ignore any well-formed coefficient for
                # compatibility with decimal.py
                continue
            builder.append(bytes([ord('0') + digit]))

        if not is_special:
            builder.append(b'E')
            builder.append(str(exponent).encode())

        return cls._from_bytes(b''.join(builder), context, exact=exact)

    @classmethod
    def from_float(cls, value):
        if not isinstance(value, (int, float)):
            raise TypeError("argument must be int of float")
        return cls._from_float_subclass_handling(value, getcontext())

    @classmethod
    def _from_float_subclass_handling(cls, value, context, exact=True):
        result = cls._from_float(value, context, exact=exact)
        if cls is Decimal:
            return result
        else:
            return cls(result)

    @staticmethod
    def _from_float(value, context, exact=True):
        if isinstance(value, int):
            return Decimal._from_int(value, context, exact=exact)
        value = float(value)    # in case it's a subclass of 'float'
        sign = 0 if _math.copysign(1.0, value) == 1.0 else 1

        if _math.isnan(value):
            self = Decimal._new_empty()
            # decimal.py calls repr(float(+-nan)), which always gives a
            # positive result.
            _mpdec.mpd_setspecial(self._mpd, _mpdec.MPD_POS, _mpdec.MPD_NAN)
            return self
        if _math.isinf(value):
            self = Decimal._new_empty()
            _mpdec.mpd_setspecial(self._mpd, sign, _mpdec.MPD_INF)
            return self

        # float as integer ratio: numerator/denominator
        num, den = abs(value).as_integer_ratio()
        k = den.bit_length() - 1

        self = Decimal._from_int(num, context, exact=True)

        # Compute num * 5**k
        d1 = _mpdec.mpd_qnew()
        if not d1:
            raise MemoryError()
        try:
            d2 = _mpdec.mpd_qnew()
            if not d2:
                raise MemoryError()
            try:
                with _CatchConversions(self._mpd, context, exact=True) as (
                        ctx, status_ptr):
                    _mpdec.mpd_qset_uint(d1, 5, ctx, status_ptr)
                    _mpdec.mpd_qset_ssize(d2, k, ctx, status_ptr)
                    _mpdec.mpd_qpow(d1, d1, d2, ctx, status_ptr)
            finally:
                _mpdec.mpd_del(d2)
            with _CatchConversions(self._mpd, context, exact=True) as (
                    ctx, status_ptr):
                _mpdec.mpd_qmul(self._mpd, self._mpd, d1, ctx, status_ptr)
        finally:
            _mpdec.mpd_del(d1)

        # result = +- n * 5**k * 10**-k
        _mpdec.mpd_set_sign(self._mpd, sign)
        self._mpd.exp = - k

        if not exact:
            with _CatchStatus(context) as (ctx, status_ptr):
                _mpdec.mpd_qfinalize(self._mpd, ctx, status_ptr)
        return self

    def __str__(self):
        return getcontext().to_sci_string(self)

    def __repr__(self):
        context = getcontext()
        output = _mpdec.mpd_to_sci(self._mpd, context._capitals)
        if not output:
            raise MemoryError
        try:
            result = _ffi.string(output)
        finally:
            _mpdec.mpd_free(output)
        return "Decimal('%s')" % result.decode()

    def as_tuple(self):
        "Return the DecimalTuple representation of a Decimal"
        mpd = self._mpd
        sign = _mpdec.mpd_sign(mpd)
        if _mpdec.mpd_isinfinite(mpd):
            expt = "F"
            # decimal.py has non-compliant infinity payloads.
            coeff = (0,)
        else:
            if _mpdec.mpd_isnan(mpd):
                if _mpdec.mpd_issnan(mpd):
                    expt = "N"
                else:
                    expt = "n"
            else:
                expt = mpd.exp

            if mpd.len > 0:
                # coefficient is defined

                # make an integer
                # XXX this should be done in C...
                x = _mpdec.mpd_qncopy(mpd)
                if not x:
                    raise MemoryError
                try:
                    x.exp = 0
                    # clear NaN and sign
                    _mpdec.mpd_clear_flags(x)
                    intstring = _mpdec.mpd_to_sci(x, 1)
                finally:
                    _mpdec.mpd_del(x)
                if not intstring:
                    raise MemoryError
                try:
                    digits = _ffi.string(intstring)
                finally:
                    _mpdec.mpd_free(intstring)
                coeff = tuple(d - ord('0') for d in digits)
            else:
                coeff = ()

        return DecimalTuple(sign, coeff, expt)

    def as_integer_ratio(self):
        "Convert a Decimal to its exact integer ratio representation"
        if _mpdec.mpd_isspecial(self._mpd):
            if _mpdec.mpd_isnan(self._mpd):
                raise ValueError("cannot convert NaN to integer ratio")
            else:
                raise OverflowError("cannot convert Infinity to integer ratio")

        context = getcontext()
        tmp = Decimal._new_empty()
        with _CatchStatus(context) as (ctx, status_ptr):
            _mpdec.mpd_qcopy(tmp._mpd, self._mpd, status_ptr)
        exp = tmp._mpd.exp if tmp else 0
        tmp._mpd.exp = 0

        # context and rounding are unused here: the conversion is exact
        numerator = tmp._to_int(_mpdec.MPD_ROUND_FLOOR)

        exponent = 10 ** abs(exp)
        if exp >= 0:
            numerator *= exponent
            denominator = 1
        else:
            denominator = exponent
            gcd = _math.gcd(numerator, denominator)
            numerator //= gcd
            denominator //= gcd

        return numerator, denominator

    def _convert_for_comparison(self, other, op):
        if isinstance(other, Decimal):
            return self, other

        context = getcontext()
        if isinstance(other, int):
            other = Decimal._from_int(other, context)
        elif isinstance(other, float):
            if op not in ('eq', 'ne'):
                # Add status, and maybe raise
                context._add_status(_mpdec.MPD_Float_operation)
            else:
                # Add status, but don't raise
                context._ctx.status |= _mpdec.MPD_Float_operation
            other = Decimal._from_float(other, context)
        elif isinstance(other, complex):
            if op not in ('eq', 'ne'):
                return NotImplemented, NotImplemented
            if other.imag != 0.0:
                return NotImplemented, NotImplemented
            # Add status, but don't raise
            context._ctx.status |= _mpdec.MPD_Float_operation
            other = Decimal._from_float(other.real, context)
        elif isinstance(other, _numbers.Rational):
            numerator = Decimal._from_int(other.numerator, context)
            if not _mpdec.mpd_isspecial(self._mpd):
                # multiplied = self * other.denominator
                #
                # Prevent Overflow in the following multiplication.
                # The result of the multiplication is
                # only used in mpd_qcmp, which can handle values that
                # are technically out of bounds, like (for 32-bit)
                # 99999999999999999999...99999999e+425000000.
                vv = _mpdec.mpd_qncopy(self._mpd)
                if not vv:
                    raise MemoryError
                try:
                    exp = vv.exp
                    vv.exp = 0
                    multiplied = Decimal._new_empty()
                    denom = Decimal(other.denominator)
                    maxctx = _ffi.new("struct mpd_context_t*")
                    _mpdec.mpd_maxcontext(maxctx)
                    status_ptr = _ffi.new("uint32_t*")
                    _mpdec.mpd_qmul(multiplied._mpd, vv, denom._mpd,
                                    maxctx, status_ptr)
                    multiplied._mpd.exp = exp
                finally:
                    _mpdec.mpd_del(vv)
                if status_ptr[0] != 0:
                    raise ValueError("exact conversion for comparison failed")

                return multiplied, numerator
            else:
                return self, numerator
        else:
            return NotImplemented, NotImplemented
        return self, other

    # _PyHASH_10INV is the inverse of 10 modulo the prime _PyHASH_MODULUS
    _PyHASH_MODULUS = _sys.hash_info.modulus
    _PyHASH_10INV = pow(10, _PyHASH_MODULUS - 2, _PyHASH_MODULUS)

    def __bool__(self):
        return not _mpdec.mpd_iszero(self._mpd)

    def __hash__(self):
        # In order to make sure that the hash of a Decimal instance
        # agrees with the hash of a numerically equal integer, float
        # or Fraction, we follow the rules for numeric hashes outlined
        # in the documentation.  (See library docs, 'Built-in Types').
        mpd = self._mpd
        if _mpdec.mpd_isspecial(mpd):
            if _mpdec.mpd_issnan(mpd):
                raise TypeError("cannot hash a signaling NaN value")
            elif _mpdec.mpd_isnan(mpd):
                return _sys.hash_info.nan
            elif _mpdec.mpd_isnegative(mpd):
                return -_sys.hash_info.inf
            else:
                return _sys.hash_info.inf

        maxctx = _ffi.new("struct mpd_context_t*")
        _mpdec.mpd_maxcontext(maxctx)
        status_ptr = _ffi.new("uint32_t*")

        # XXX cache these
        p = self._new_empty()
        _mpdec.mpd_qset_ssize(p._mpd, self._PyHASH_MODULUS,
                              maxctx, status_ptr)
        ten = self._new_empty()
        _mpdec.mpd_qset_ssize(ten._mpd, 10,
                              maxctx, status_ptr)
        inv10_p = self._new_empty()
        _mpdec.mpd_qset_ssize(inv10_p._mpd, self._PyHASH_10INV,
                              maxctx, status_ptr)

        tmp = self._new_empty()
        exp_hash = self._new_empty()

        if mpd.exp >= 0:
            # 10**exp(v) % p
            _mpdec.mpd_qsset_ssize(tmp._mpd, mpd.exp, maxctx, status_ptr)
            _mpdec.mpd_qpowmod(exp_hash._mpd, ten._mpd, tmp._mpd, p._mpd,
                               maxctx, status_ptr)
        else:
            # inv10_p**(-exp(v)) % p
            _mpdec.mpd_qsset_ssize(tmp._mpd, -mpd.exp, maxctx, status_ptr)
            _mpdec.mpd_qpowmod(exp_hash._mpd, inv10_p._mpd, tmp._mpd, p._mpd,
                               maxctx, status_ptr)

        # hash = (int(v) * exp_hash) % p
        if not _mpdec.mpd_qcopy(tmp._mpd, mpd, status_ptr):
            raise MemoryError

        tmp._mpd.exp = 0
        _mpdec.mpd_set_positive(tmp._mpd)

        maxctx.prec = MAX_PREC + 21
        maxctx.emax = MAX_EMAX + 21
        maxctx.emin = MIN_EMIN - 21

        _mpdec.mpd_qmul(tmp._mpd, tmp._mpd, exp_hash._mpd, maxctx, status_ptr)
        _mpdec.mpd_qrem(tmp._mpd, tmp._mpd, p._mpd, maxctx, status_ptr)

        result = _mpdec.mpd_qget_ssize(tmp._mpd, status_ptr)
        result = result if _mpdec.mpd_ispositive(mpd) else -result
        result = result if result != -1 else -2

        if status_ptr[0]:
            if status_ptr[0] & _mpdec.MPD_Malloc_error:
                raise MemoryError
            else:
                raise SystemError("Decimal.__hash__")

        return result

    def _cmp(self, other, op):
        a, b = self._convert_for_comparison(other, op)
        if a is NotImplemented:
            return NotImplemented
        status_ptr = _ffi.new("uint32_t*")
        r = _mpdec.mpd_qcmp(a._mpd, b._mpd, status_ptr)
        if r > 1:  # INT_MAX
            # sNaNs or op={le,ge,lt,gt} always signal
            if (_mpdec.mpd_issnan(a._mpd) or
                _mpdec.mpd_issnan(b._mpd) or
                op not in ('eq', 'ne')):
                getcontext()._add_status(status_ptr[0])
            # qNaN comparison with op={eq,ne} or comparison with
            # InvalidOperation disabled.
            # Arrange to return False.
            if op in ('gt', 'ge'):
                return -1
            else:
                return 1
        return r

    def __eq__(self, other):
        r = self._cmp(other, 'eq')
        if r is NotImplemented:
            return NotImplemented
        return r == 0

    def __ne__(self, other):
        r = self._cmp(other, 'ne')
        if r is NotImplemented:
            return NotImplemented
        return r != 0

    def __lt__(self, other):
        r = self._cmp(other, 'lt')
        if r is NotImplemented:
            return NotImplemented
        return r < 0

    def __le__(self, other):
        r = self._cmp(other, 'le')
        if r is NotImplemented:
            return NotImplemented
        return r <= 0

    def __gt__(self, other):
        r = self._cmp(other, 'gt')
        if r is NotImplemented:
            return NotImplemented
        return r > 0

    def __ge__(self, other):
        r = self._cmp(other, 'ge')
        if r is NotImplemented:
            return NotImplemented
        return r >= 0

    # operations
    def _make_unary_operation(name, ctxop_name=None):
        ctxop_name = ctxop_name or name
        if name.startswith('__'):
            def method(self):
                return getattr(getcontext(), ctxop_name)(self)
        else:
            # Allow optional context
            def method(self, context=None):
                context = _getcontext(context)
                return getattr(context, ctxop_name)(self)
        method.__name__ = name
        return method

    def _make_unary_operation_noctx(name, ctxop_name=None):
        ctxop_name = ctxop_name or name
        def method(self):
            return getattr(getcontext(), ctxop_name)(self)
        method.__name__ = name
        return method

    def _make_binary_operation(name, ctxop_name=None):
        ctxop_name = ctxop_name or name
        if name.startswith('__'):
            def method(self, other):
                return getattr(getcontext(), ctxop_name)(
                    self, other, strict=False)
        else:
            def method(self, other, context=None):
                context = _getcontext(context)
                return getattr(context, ctxop_name)(
                    self, other)
        method.__name__ = name
        return method

    def _make_binary_roperation(name, ctxop_name):
        def method(self, other):
            return getattr(getcontext(), ctxop_name)(other, self, strict=False)
        method.__name__ = name
        return method

    __abs__ = _make_unary_operation('__abs__', 'abs')
    __pos__ = _make_unary_operation('__pos__', 'plus')
    __neg__ = _make_unary_operation('__neg__', 'minus')

    __add__ = _make_binary_operation('__add__', 'add')
    __sub__ = _make_binary_operation('__sub__', 'subtract')
    __mul__ = _make_binary_operation('__mul__', 'multiply')
    __floordiv__ = _make_binary_operation('__floordiv__', 'divide_int')
    __truediv__ = _make_binary_operation('__truediv__', 'divide')
    __mod__ = _make_binary_operation('__mod__', 'remainder')
    __divmod__ = _make_binary_operation('__divmod__', 'divmod')

    __radd__ = _make_binary_roperation('__radd__', 'add')
    __rsub__ = _make_binary_roperation('__rsub__', 'subtract')
    __rmul__ = _make_binary_roperation('__rmul__', 'multiply')
    __rfloordiv__ = _make_binary_roperation('__rfloordiv__', 'divide_int')
    __rtruediv__ = _make_binary_roperation('__rtruediv__', 'divide')
    __rmod__ = _make_binary_roperation('__rmod__', 'remainder')
    __rdivmod__ = _make_binary_roperation('__rdivmod__', 'divmod')

    def __pow__(self, other, modulo=None):
        return getcontext().power(self, other, modulo, strict=False)
    def __rpow__(self, other):
        return getcontext().power(other, self, strict=False)

    copy_sign = _make_binary_operation('copy_sign')
    copy_abs = _make_unary_operation_noctx('copy_abs')
    copy_negate = _make_unary_operation_noctx('copy_negate')

    sqrt = _make_unary_operation('sqrt')
    exp = _make_unary_operation('exp')
    ln = _make_unary_operation('ln')
    log10 = _make_unary_operation('log10')
    logb = _make_unary_operation('logb')
    logical_invert = _make_unary_operation('logical_invert')
    normalize = _make_unary_operation('normalize')

    compare = _make_binary_operation('compare')
    compare_signal = _make_binary_operation('compare_signal')
    compare_total = _make_binary_operation('compare_total')
    compare_total_mag = _make_binary_operation('compare_total_mag')
    logical_and = _make_binary_operation('logical_and')
    logical_or = _make_binary_operation('logical_or')
    logical_xor = _make_binary_operation('logical_xor')
    max = _make_binary_operation('max')
    max_mag = _make_binary_operation('max_mag')
    min = _make_binary_operation('min')
    min_mag = _make_binary_operation('min_mag')
    next_minus = _make_unary_operation('next_minus')
    next_plus = _make_unary_operation('next_plus')
    next_toward = _make_binary_operation('next_toward')
    remainder_near = _make_binary_operation('remainder_near')
    rotate = _make_binary_operation('rotate')
    same_quantum = _make_binary_operation('same_quantum')
    scaleb = _make_binary_operation('scaleb')
    shift = _make_binary_operation('shift')

    is_normal = _make_unary_operation('is_normal')
    is_subnormal = _make_unary_operation('is_subnormal')
    is_signed = _make_unary_operation_noctx('is_signed')
    is_zero = _make_unary_operation_noctx('is_zero')
    is_nan = _make_unary_operation_noctx('is_nan')
    is_snan = _make_unary_operation_noctx('is_snan')
    is_qnan = _make_unary_operation_noctx('is_qnan')
    is_finite = _make_unary_operation_noctx('is_finite')
    is_infinite = _make_unary_operation_noctx('is_infinite')
    number_class = _make_unary_operation('number_class')

    to_eng_string = _make_unary_operation('to_eng_string')

    def fma(self, other, third, context=None):
        context = _getcontext(context)
        return context.fma(self, other, third)

    def _to_int(self, rounding):
        mpd = self._mpd
        if _mpdec.mpd_isspecial(mpd):
            if _mpdec.mpd_isnan(mpd):
                raise ValueError("cannot convert NaN to integer")
            else:
                raise OverflowError("cannot convert Infinity to integer")

        x = Decimal._new_empty()
        context = getcontext()
        tempctx = context.copy()
        tempctx._ctx.round = rounding
        with _CatchStatus(context) as (ctx, status_ptr):
            # We round with the temporary context, but set status and
            # raise errors on the global one.
            _mpdec.mpd_qround_to_int(x._mpd, mpd, tempctx._ctx, status_ptr)

            # XXX mpd_qexport_u64 would be faster...
            digits_ptr = _ffi.new("uint16_t**")
            n = _mpdec.mpd_qexport_u16(digits_ptr, 0, 0x10000,
                                       x._mpd, status_ptr)
            if n == _mpdec.MPD_SIZE_MAX:
                raise MemoryError
            try:
                s = _ffi.buffer(digits_ptr[0], n * 2)[:]
            finally:
                _mpdec.mpd_free(digits_ptr[0])
            result = int.from_bytes(s, 'little', signed=False)
        if _mpdec.mpd_isnegative(x._mpd) and not _mpdec.mpd_iszero(x._mpd):
            result = -result
        return result

    def __int__(self):
        return self._to_int(_mpdec.MPD_ROUND_DOWN)

    __trunc__ = __int__

    def __floor__(self):
        return self._to_int(_mpdec.MPD_ROUND_FLOOR)

    def __ceil__(self):
        return self._to_int(_mpdec.MPD_ROUND_CEILING)

    def to_integral(self, rounding=None, context=None):
        context = _getcontext(context)
        workctx = context.copy()
        if rounding is not None:
            workctx.rounding = rounding
        result = Decimal._new_empty()
        with _CatchStatus(context) as (ctx, status_ptr):
            # We round with the temporary context, but set status and
            # raise errors on the global one.
            _mpdec.mpd_qround_to_int(result._mpd, self._mpd,
                                     workctx._ctx, status_ptr)
        return result

    to_integral_value = to_integral

    def to_integral_exact(self, rounding=None, context=None):
        context = _getcontext(context)
        workctx = context.copy()
        if rounding is not None:
            workctx.rounding = rounding
        result = Decimal._new_empty()
        with _CatchStatus(context) as (ctx, status_ptr):
            # We round with the temporary context, but set status and
            # raise errors on the global one.
            _mpdec.mpd_qround_to_intx(result._mpd, self._mpd,
                                      workctx._ctx, status_ptr)
        return result

    def quantize(self, exp, rounding=None, context=None):
        context = _getcontext(context)
        exp = context._convert_unaryop(exp)
        workctx = context.copy()
        if rounding is not None:
            workctx.rounding = rounding
        result = Decimal._new_empty()
        with _CatchStatus(context) as (ctx, status_ptr):
            # We round with the temporary context, but set status and
            # raise errors on the global one.
            _mpdec.mpd_qquantize(result._mpd, self._mpd, exp._mpd,
                                 workctx._ctx, status_ptr)
        return result

    def __round__(self, x=None):
        if x is None:
            return self._to_int(_mpdec.MPD_ROUND_HALF_EVEN)
        result = Decimal._new_empty()
        context = getcontext()
        q = Decimal._from_int(1, context)
        if x == _mpdec.MPD_SSIZE_MIN:
            q._mpd.exp = _mpdec.MPD_SSIZE_MAX
        elif x == -_mpdec.MPD_SSIZE_MIN:
            raise OverflowError  # For compatibility with CPython.
        else:
            q._mpd.exp = -x
        with _CatchStatus(context) as (ctx, status_ptr):
            _mpdec.mpd_qquantize(result._mpd, self._mpd, q._mpd,
                                 ctx, status_ptr)
        return result

    def __float__(self):
        if _mpdec.mpd_isnan(self._mpd):
            if _mpdec.mpd_issnan(self._mpd):
                raise ValueError("cannot convert signaling NaN to float")
            if _mpdec.mpd_isnegative(self._mpd):
                return float("-nan")
            else:
                return float("nan")
        else:
            return float(str(self))

    def radix(self):
        return Decimal(10)

    def canonical(self):
        return self

    def is_canonical(self):
        return True

    def adjusted(self):
        if _mpdec.mpd_isspecial(self._mpd):
            return 0
        return _mpdec.mpd_adjexp(self._mpd)

    @property
    def real(self):
        return self

    @property
    def imag(self):
        return Decimal(0)

    def conjugate(self):
        return self

    def __complex__(self):
        return complex(float(self))

    def __copy__(self):
        return self

    def __deepcopy__(self, memo=None):
        return self

    def __reduce__(self):
        return (type(self), (str(self),))

    def __format__(self, specifier, override=None):
        if not isinstance(specifier, str):
            raise TypeError
        fmt = specifier.encode('utf-8')
        context = getcontext()

        replace_fillchar = False
        if fmt and fmt[0] == 0:
            # NUL fill character: must be replaced with a valid UTF-8 char
            # before calling mpd_parse_fmt_str().
            replace_fillchar = True
            fmt = b'_' + fmt[1:]

        spec = _ffi.new("mpd_spec_t*")
        if not _mpdec.mpd_parse_fmt_str(spec, fmt, context._capitals):
            raise ValueError("invalid format string")
        if replace_fillchar:
            # In order to avoid clobbering parts of UTF-8 thousands
            # separators or decimal points when the substitution is
            # reversed later, the actual placeholder must be an invalid
            # UTF-8 byte.
            spec.fill = b'\xff\x00'

        if override:
            # Values for decimal_point, thousands_sep and grouping can
            # be explicitly specified in the override dict. These values
            # take precedence over the values obtained from localeconv()
            # in mpd_parse_fmt_str(). The feature is not documented and
            # is only used in test_decimal.
            try:
                dot = _ffi.new("char[]", override['decimal_point'].encode())
            except KeyError:
                pass
            else:
                spec.dot = dot
            try:
                sep = _ffi.new("char[]", override['thousands_sep'].encode())
            except KeyError:
                pass
            else:
                spec.sep = sep
            try:
                grouping = _ffi.new("char[]", override['grouping'].encode())
            except KeyError:
                pass
            else:
                spec.grouping = grouping
            if _mpdec.mpd_validate_lconv(spec) < 0:
                raise ValueError("invalid override dict")

        with _CatchStatus(context) as (ctx, status_ptr):
            decstring = _mpdec.mpd_qformat_spec(
                self._mpd, spec, ctx, status_ptr)
            status = status_ptr[0]
        if not decstring:
            if status & _mpdec.MPD_Malloc_error:
                raise MemoryError
            else:
                raise ValueError("format specification exceeds "
                                 "internal limits of _decimal")
        result = _ffi.string(decstring)
        if replace_fillchar:
            result = result.replace(b'\xff', b'\0')
        return result.decode('utf-8')


# Register Decimal as a kind of Number (an abstract base class).
# However, do not register it as Real (because Decimals are not
# interoperable with floats).
_numbers.Number.register(Decimal)

# Context class

_DEC_DFLT_EMAX = 999999
_DEC_DFLT_EMIN = -999999

# Rounding
_ROUNDINGS = {
    'ROUND_DOWN': _mpdec.MPD_ROUND_DOWN,
    'ROUND_HALF_UP': _mpdec.MPD_ROUND_HALF_UP,
    'ROUND_HALF_EVEN': _mpdec.MPD_ROUND_HALF_EVEN,
    'ROUND_CEILING': _mpdec.MPD_ROUND_CEILING,
    'ROUND_FLOOR': _mpdec.MPD_ROUND_FLOOR,
    'ROUND_UP': _mpdec.MPD_ROUND_UP,
    'ROUND_HALF_DOWN': _mpdec.MPD_ROUND_HALF_DOWN,
    'ROUND_05UP': _mpdec.MPD_ROUND_05UP,
}
for _rounding in _ROUNDINGS:
    globals()[_rounding] = _rounding

_SIGNALS = {
    InvalidOperation: _mpdec.MPD_IEEE_Invalid_operation,
    FloatOperation: _mpdec.MPD_Float_operation,
    DivisionByZero: _mpdec.MPD_Division_by_zero ,
    Overflow: _mpdec.MPD_Overflow ,
    Underflow: _mpdec.MPD_Underflow ,
    Subnormal: _mpdec.MPD_Subnormal ,
    Inexact: _mpdec.MPD_Inexact ,
    Rounded: _mpdec.MPD_Rounded,
    Clamped: _mpdec.MPD_Clamped,
}

class _ContextManager(object):
    """Context manager class to support localcontext().

      Sets a copy of the supplied context in __enter__() and restores
      the previous decimal context in __exit__()
    """
    def __init__(self, new_context):
        self.new_context = new_context.copy()
    def __enter__(self):
        self.saved_context = getcontext()
        setcontext(self.new_context)
        return self.new_context
    def __exit__(self, t, v, tb):
        setcontext(self.saved_context)


class Context(object):
    """Contains the context for a Decimal instance.

    Contains:
    prec - precision (for use in rounding, division, square roots..)
    rounding - rounding type (how you round)
    traps - If traps[exception] = 1, then the exception is
                    raised when it is caused.  Otherwise, a value is
                    substituted in.
    flags  - When an exception is caused, flags[exception] is set.
             (Whether or not the trap_enabler is set)
             Should be reset by user of Decimal instance.
    Emin -   Minimum exponent
    Emax -   Maximum exponent
    capitals -      If 1, 1*10^1 is printed as 1E+1.
                    If 0, printed as 1e1
    clamp -  If 1, change exponents if too high (Default 0)
    """

    __slots__ = ('_ctx', '_capitals')

    def __new__(cls, prec=None, rounding=None, Emin=None, Emax=None,
                capitals=None, clamp=None, flags=None, traps=None):
        # NOTE: the arguments are ignored here, they are used in __init__()
        self = object.__new__(cls)
        self._ctx = ctx = _ffi.new("struct mpd_context_t*")
        # Default context
        ctx.prec = 28
        ctx.emax = _DEC_DFLT_EMAX
        ctx.emin = _DEC_DFLT_EMIN
        ctx.traps = (_mpdec.MPD_IEEE_Invalid_operation|
                     _mpdec.MPD_Division_by_zero|
                     _mpdec.MPD_Overflow)
        ctx.status = 0
        ctx.newtrap = 0
        ctx.round = _mpdec.MPD_ROUND_HALF_EVEN
        ctx.clamp = 0
        ctx.allcr = 1

        self._capitals = 1
        return self

    def __init__(self, prec=None, rounding=None, Emin=None, Emax=None,
                 capitals=None, clamp=None, flags=None, traps=None):
        ctx = self._ctx

        try:
            dc = DefaultContext._ctx
        except NameError:
            pass
        else:
            ctx[0] = dc[0]
        if prec is not None:
            self.prec = prec
        if rounding is not None:
            self.rounding = rounding
        if Emin is not None:
            self.Emin = Emin
        if Emax is not None:
            self.Emax = Emax
        if clamp is not None:
            self.clamp = clamp
        if capitals is not None:
            self.capitals = capitals

        if traps is None:
            ctx.traps = dc.traps
        elif isinstance(traps, list):
            ctx.traps = 0
            for signal in traps:
                ctx.traps |= _SIGNALS[signal]
        elif isinstance(traps, dict):
            ctx.traps = 0
            for signal, value in traps.items():
                if value:
                    ctx.traps |= _SIGNALS[signal]
        else:
            self.traps = traps

        if flags is None:
            ctx.status = 0
        elif isinstance(flags, list):
            ctx.status = 0
            for signal in flags:
                ctx.status |= _SIGNALS[signal]
        elif isinstance(flags, dict):
            for signal, value in flags.items():
                if value:
                    ctx.status |= _SIGNALS[signal]
        else:
            self.flags = flags

    def clear_flags(self):
        self._ctx.status = 0

    def clear_traps(self):
        self._ctx.traps = 0

    @property
    def prec(self):
        return self._ctx.prec
    @prec.setter
    def prec(self, value):
        if not _mpdec.mpd_qsetprec(self._ctx, value):
            raise ValueError("valid range for prec is [1, MAX_PREC]")

    @property
    def clamp(self):
        return self._ctx.clamp
    @clamp.setter
    def clamp(self, value):
        if not _mpdec.mpd_qsetclamp(self._ctx, value):
            raise ValueError("valid values for clamp are 0 or 1")

    @property
    def rounding(self):
        return next(name
                    for (name, value) in _ROUNDINGS.items()
                    if value==self._ctx.round)
    @rounding.setter
    def rounding(self, value):
        if value not in _ROUNDINGS:
            raise TypeError(
                "valid values for rounding are:\n"
                "[ROUND_CEILING, ROUND_FLOOR, ROUND_UP, ROUND_DOWN,\n"
                "ROUND_HALF_UP, ROUND_HALF_DOWN, ROUND_HALF_EVEN,\n"
                "ROUND_05UP]")
        if not _mpdec.mpd_qsetround(self._ctx, _ROUNDINGS[value]):
            raise RuntimeError("internal error while setting rounding")

    @property
    def Emin(self):
        return self._ctx.emin
    @Emin.setter
    def Emin(self, value):
        if not _mpdec.mpd_qsetemin(self._ctx, value):
            raise ValueError("valid range for Emin is [MIN_EMIN, 0]")

    @property
    def Emax(self):
        return self._ctx.emax
    @Emax.setter
    def Emax(self, value):
        if not _mpdec.mpd_qsetemax(self._ctx, value):
            raise ValueError("valid range for Emax is [0, MAX_EMAX]")

    @property
    def flags(self):
        return _SignalDict(self._ctx, 'status')
    @flags.setter
    def flags(self, value):
        if not isinstance(value, _collections_abc.Mapping):
            raise TypeError
        if len(value) != len(_SIGNALS):
            raise KeyError("Invalid signal dict")
        for signal, value in value.items():
            if value:
                self._ctx.status |= _SIGNALS[signal]

    @property
    def traps(self):
        return _SignalDict(self._ctx, 'traps')
    @traps.setter
    def traps(self, value):
        if not isinstance(value, _collections_abc.Mapping):
            raise TypeError
        if len(value) != len(_SIGNALS):
            raise KeyError("Invalid signal dict")
        for signal, value in value.items():
            if value:
                self._ctx.traps |= _SIGNALS[signal]

    @property
    def capitals(self):
        return self._capitals
    @capitals.setter
    def capitals(self, value):
        if not isinstance(value, int):
            raise TypeError
        if value not in (0, 1):
            raise ValueError("valid values for capitals are 0 or 1")
        self._capitals = value

    def __repr__(self):
        ctx = self._ctx
        return ("Context(prec=%s, rounding=%s, Emin=%s, Emax=%s, "
                "capitals=%s, clamp=%s, flags=%s, traps=%s)" % (
                    ctx.prec, self.rounding,
                    ctx.emin, ctx.emax,
                    self._capitals, ctx.clamp,
                    self.flags, self.traps))

    def radix(self):
        return Decimal(10)

    def Etiny(self):
        return _mpdec.mpd_etiny(self._ctx)

    def Etop(self):
        return _mpdec.mpd_etop(self._ctx)

    def is_canonical(self, a):
        if not isinstance(a, Decimal):
            raise TypeError("is_canonical requires a Decimal as an argument.")
        return a.is_canonical()

    def canonical(self, a):
        if not isinstance(a, Decimal):
            raise TypeError("argument must be a Decimal")
        return a

    def copy(self):
        other = Context()
        other._ctx[0] = self._ctx[0]
        other._capitals = self._capitals
        return other

    def __copy__(self):
        return self.copy()

    def __reduce__(self):
        return (type(self), (
            self.prec, self.rounding, self.Emin, self.Emax,
            self._capitals, self.clamp,
            self.flags._as_list(),
            self.traps._as_list()))

    def _add_status(self, status):
        self._ctx.status |= status
        if self._ctx.status & _mpdec.MPD_Malloc_error:
            raise MemoryError()
        trapped = self._ctx.traps & status
        if trapped:
            for exception, flag in _SIGNALS.items():
                if trapped & flag:
                    raise exception
            raise RuntimeError("Invalid error flag", trapped)

    def create_decimal(self, num="0"):
        """Creates a new Decimal instance but using self as context.

        This method implements the to-number operation of the
        IBM Decimal specification."""

        if isinstance(num, str) and (num != num.strip() or '_' in num):
            num = '' # empty string triggers ConversionSyntax
        return Decimal._from_object(num, self, exact=False)

    def create_decimal_from_float(self, f):
        return Decimal._from_float(f, self, exact=False)

    # operations
    def _convert_unaryop(self, a, *, strict=True):
        if isinstance(a, Decimal):
            return a
        elif isinstance(a, int):
            return Decimal._from_int(a, self)
        if strict:
            raise TypeError("Unable to convert %s to Decimal" % (a,))
        else:
            return NotImplemented

    def _convert_binop(self, a, b, *, strict=True):
        a = self._convert_unaryop(a, strict=strict)
        b = self._convert_unaryop(b, strict=strict)
        if b is NotImplemented:
            return b, b
        return a, b

    def _make_unary_method(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, *, strict=True):
            a = self._convert_unaryop(a, strict=strict)
            if a is NotImplemented:
                return NotImplemented
            res = Decimal._new_empty()
            with _CatchStatus(self) as (ctx, status_ptr):
                mpd_func(res._mpd, a._mpd, ctx, status_ptr)
            return res
        method.__name__ = name
        return method

    def _make_unary_method_noctx(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, *, strict=True):
            a = self._convert_unaryop(a, strict=strict)
            if a is NotImplemented:
                return NotImplemented
            res = Decimal._new_empty()
            with _CatchStatus(self) as (ctx, status_ptr):
                mpd_func(res._mpd, a._mpd, status_ptr)
            return res
        method.__name__ = name
        return method

    def _make_bool_method(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a):
            a = self._convert_unaryop(a)
            return bool(mpd_func(a._mpd, self._ctx))
        method.__name__ = name
        return method

    def _make_bool_method_noctx(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a):
            a = self._convert_unaryop(a)
            return bool(mpd_func(a._mpd))
        method.__name__ = name
        return method

    def _make_binary_method(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, b, *, strict=True):
            a, b = self._convert_binop(a, b, strict=strict)
            if a is NotImplemented:
                return NotImplemented
            res = Decimal._new_empty()
            with _CatchStatus(self) as (ctx, status_ptr):
                mpd_func(res._mpd, a._mpd, b._mpd, ctx, status_ptr)
            return res
        method.__name__ = name
        return method

    def _make_binary_bool_method(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, b):
            a, b = self._convert_binop(a, b)
            return bool(mpd_func(a._mpd, b._mpd))
        method.__name__ = name
        return method

    def _make_binary_method_noctx(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, b, *, strict=True):
            a, b = self._convert_binop(a, b, strict=strict)
            if a is NotImplemented:
                return NotImplemented
            res = Decimal._new_empty()
            with _CatchStatus(self) as (ctx, status_ptr):
                mpd_func(res._mpd, a._mpd, b._mpd, status_ptr)
            return res
        method.__name__ = name
        return method

    def _make_binary_method_nostatus(name, mpd_func_name):
        mpd_func = getattr(_mpdec, mpd_func_name)

        def method(self, a, b, *, strict=True):
            a, b = self._convert_binop(a, b, strict=strict)
            if a is NotImplemented:
                return NotImplemented
            res = Decimal._new_empty()
            mpd_func(res._mpd, a._mpd, b._mpd)
            return res
        method.__name__ = name
        return method

    abs = _make_unary_method('abs', 'mpd_qabs')
    plus = _make_unary_method('plus', 'mpd_qplus')
    minus = _make_unary_method('minus', 'mpd_qminus')
    sqrt = _make_unary_method('sqrt', 'mpd_qsqrt')
    exp = _make_unary_method('exp', 'mpd_qexp')
    ln = _make_unary_method('ln', 'mpd_qln')
    log10 = _make_unary_method('log10', 'mpd_qlog10')
    logb = _make_unary_method('logb', 'mpd_qlogb')
    logical_invert = _make_unary_method('logical_invert', 'mpd_qinvert')
    normalize = _make_unary_method('normalize', 'mpd_qreduce')

    add = _make_binary_method('add', 'mpd_qadd')
    subtract = _make_binary_method('add', 'mpd_qsub')
    multiply = _make_binary_method('multiply', 'mpd_qmul')
    divide = _make_binary_method('divide', 'mpd_qdiv')
    divide_int = _make_binary_method('divide_int', 'mpd_qdivint')
    remainder = _make_binary_method('remainder', 'mpd_qrem')
    remainder_near = _make_binary_method('remainder_near', 'mpd_qrem_near')
    copy_sign = _make_binary_method_noctx('copy_sign', 'mpd_qcopy_sign')
    copy_abs = _make_unary_method_noctx('copy_abs', 'mpd_qcopy_abs')
    copy_negate = _make_unary_method_noctx('copy_negate', 'mpd_qcopy_negate')

    compare = _make_binary_method('compare', 'mpd_qcompare')
    compare_signal = _make_binary_method('compare_signal',
                                         'mpd_qcompare_signal')
    compare_total = _make_binary_method_nostatus('compare_total',
                                                 'mpd_compare_total')
    compare_total_mag = _make_binary_method_nostatus('compare_total_mag',
                                                     'mpd_compare_total_mag')
    logical_and = _make_binary_method('logical_and', 'mpd_qand')
    logical_or = _make_binary_method('logical_or', 'mpd_qor')
    logical_xor = _make_binary_method('logical_xor', 'mpd_qxor')
    max = _make_binary_method('max', 'mpd_qmax')
    max_mag = _make_binary_method('max_mag', 'mpd_qmax_mag')
    min = _make_binary_method('min', 'mpd_qmin')
    min_mag = _make_binary_method('min_mag', 'mpd_qmin_mag')
    next_minus = _make_unary_method('next_minus', 'mpd_qnext_minus')
    next_plus = _make_unary_method('next_plus', 'mpd_qnext_plus')
    next_toward = _make_binary_method('next_toward', 'mpd_qnext_toward')
    rotate = _make_binary_method('rotate', 'mpd_qrotate')
    same_quantum = _make_binary_bool_method('same_quantum', 'mpd_same_quantum')
    scaleb = _make_binary_method('scaleb', 'mpd_qscaleb')
    shift = _make_binary_method('shift', 'mpd_qshift')
    quantize = _make_binary_method('quantize', 'mpd_qquantize')

    is_normal = _make_bool_method('is_normal', 'mpd_isnormal')
    is_signed = _make_bool_method_noctx('is_signed', 'mpd_issigned')
    is_zero = _make_bool_method_noctx('is_signed', 'mpd_iszero')
    is_subnormal = _make_bool_method('is_subnormal', 'mpd_issubnormal')
    is_nan = _make_bool_method_noctx('is_qnan', 'mpd_isnan')
    is_snan = _make_bool_method_noctx('is_qnan', 'mpd_issnan')
    is_qnan = _make_bool_method_noctx('is_qnan', 'mpd_isqnan')
    is_finite = _make_bool_method_noctx('is_finite', 'mpd_isfinite')
    is_infinite = _make_bool_method_noctx('is_infinite', 'mpd_isinfinite')

    def _apply(self, a):
        # Apply the context to the input operand.
        a = self._convert_unaryop(a)
        result = Decimal._new_empty()
        with _CatchStatus(self) as (ctx, status_ptr):
            _mpdec.mpd_qcopy(result._mpd, a._mpd, status_ptr)
            _mpdec.mpd_qfinalize(result._mpd, ctx, status_ptr)
        return result

    def divmod(self, a, b, *, strict=True):
        a, b = self._convert_binop(a, b, strict=strict)
        if a is NotImplemented:
            return NotImplemented
        q = Decimal._new_empty()
        r = Decimal._new_empty()
        with _CatchStatus(self) as (ctx, status_ptr):
            _mpdec.mpd_qdivmod(q._mpd, r._mpd, a._mpd, b._mpd,
                               ctx, status_ptr)
        return q, r

    def power(self, a, b, modulo=None, *, strict=True):
        a, b = self._convert_binop(a, b, strict=strict)
        if a is NotImplemented:
            return NotImplemented
        if modulo is not None:
            modulo = self._convert_unaryop(modulo, strict=strict)
            if modulo is NotImplemented:
                return NotImplemented
        res = Decimal._new_empty()
        with _CatchStatus(self) as (ctx, status_ptr):
            if modulo is not None:
                _mpdec.mpd_qpowmod(res._mpd, a._mpd, b._mpd, modulo._mpd,
                                   ctx, status_ptr)
            else:
                _mpdec.mpd_qpow(res._mpd, a._mpd, b._mpd,
                                ctx, status_ptr)
        return res

    to_integral = _make_unary_method('to_integral', 'mpd_qround_to_int')
    to_integral_value = to_integral
    to_integral_exact = _make_unary_method('to_integral_exact',
                                           'mpd_qround_to_intx')

    def fma(self, a, b, c):
        a = self._convert_unaryop(a)
        b = self._convert_unaryop(b)
        c = self._convert_unaryop(c)
        res = Decimal._new_empty()
        with _CatchStatus(self) as (ctx, status_ptr):
            _mpdec.mpd_qfma(res._mpd, a._mpd, b._mpd, c._mpd,
                            ctx, status_ptr)
        return res

    def copy_decimal(self, a):
        return self._convert_unaryop(a)

    def number_class(self, a):
        a = self._convert_unaryop(a)
        cp = _mpdec.mpd_class(a._mpd, self._ctx)
        return _ffi.string(cp).decode()

    def to_eng_string(self, a):
        a = self._convert_unaryop(a)
        output = _mpdec.mpd_to_eng(a._mpd, self._capitals)
        if not output:
            raise MemoryError
        try:
            result = _ffi.string(output)
        finally:
            _mpdec.mpd_free(output)
        return result.decode()

    def to_sci_string(self, a):
        a = self._convert_unaryop(a)
        output = _mpdec.mpd_to_sci(a._mpd, self._capitals)
        if not output:
            raise MemoryError
        try:
            result = _ffi.string(output)
        finally:
            _mpdec.mpd_free(output)
        return result.decode()

    if _sys.maxsize < 2**63-1:
        def _unsafe_setprec(self, value):
            _unsafe_check('prec', 1, 1070000000, value)
            self._ctx.prec = value

        def _unsafe_setemin(self, value):
            _unsafe_check('emin', -1070000000, 0, value)
            self._ctx.emin = value

        def _unsafe_setemax(self, value):
            _unsafe_check('emax', 0, 1070000000, value)
            self._ctx.emax = value


class _SignalDict(_collections_abc.MutableMapping):

    def __init__(self, ctx, attrname):
        self.ctx = ctx
        self.attrname = attrname

    def __repr__(self):
        value = getattr(self.ctx, self.attrname)
        buf = _ffi.new("char[]", _mpdec.MPD_MAX_SIGNAL_LIST)
        n = _mpdec.mpd_lsnprint_signals(buf, len(buf), value,
                                        _mpdec.dec_signal_string)
        if not 0 <= n < len(buf):
            raise SystemError("flags repr")
        return _ffi.buffer(buf, n)[:].decode()

    def _as_list(self):
        value = getattr(self.ctx, self.attrname)
        names = []
        for name, flag in _SIGNALS.items():
            if value & flag:
                names.append(name)
        return names

    def _as_dict(self):
        value = getattr(self.ctx, self.attrname)
        return {name: bool(value & flag)
                for (name, flag) in _SIGNALS.items()}

    def copy(self):
        return self._as_dict()

    def __len__(self):
        return len(_SIGNALS)

    def __iter__(self):
        return iter(_SIGNALS)

    def __getitem__(self, key):
        return bool(getattr(self.ctx, self.attrname) & _SIGNALS[key])

    def __setitem__(self, key, value):
        if value:
            setattr(self.ctx, self.attrname,
                    getattr(self.ctx, self.attrname) | _SIGNALS[key])
        else:
            setattr(self.ctx, self.attrname,
                    getattr(self.ctx, self.attrname) & ~_SIGNALS[key])

    def __delitem__(self, key):
        raise ValueError("signal keys cannot be deleted")


class _CatchConversions:
    def __init__(self, mpd, context, exact):
        self.mpd = mpd
        self.context = _getcontext(context)
        self.exact = exact

    def __enter__(self):
        if self.exact:
            self.ctx = _ffi.new("struct mpd_context_t*")
            _mpdec.mpd_maxcontext(self.ctx)
        else:
            self.ctx = self.context._ctx
        self.status_ptr = _ffi.new("uint32_t*")
        return self.ctx, self.status_ptr

    def __exit__(self, *args):
        if self.exact:
            # we want exact results
            status = self.status_ptr[0]
            if status & (_mpdec.MPD_Inexact |
                         _mpdec.MPD_Rounded |
                         _mpdec.MPD_Clamped):
                _mpdec.mpd_seterror(
                    self.mpd, _mpdec.MPD_Invalid_operation, self.status_ptr)
        status = self.status_ptr[0]
        if self.exact:
            status &= _mpdec.MPD_Errors
        # May raise a DecimalException
        self.context._add_status(status)

class _CatchStatus:
    def __init__(self, context):
        self.context = context

    def __enter__(self):
        self.status_ptr = _ffi.new("uint32_t*")
        return self.context._ctx, self.status_ptr

    def __exit__(self, *args):
        status = self.status_ptr[0]
        # May raise a DecimalException
        self.context._add_status(status)

##### Setup Specific Contexts ############################################

# The default context prototype used by Context()
# Is mutable, so that new contexts can have different default values

DefaultContext = Context(
    prec=28, rounding=ROUND_HALF_EVEN,
    traps=[DivisionByZero, Overflow, InvalidOperation],
    flags=[],
    Emax=999999,
    Emin=-999999,
    capitals=1,
    clamp=0
)

# Pre-made alternate contexts offered by the specification
# Don't change these; the user should be able to select these
# contexts and be able to reproduce results from other implementations
# of the spec.

BasicContext = Context(
    prec=9, rounding=ROUND_HALF_UP,
    traps=[DivisionByZero, Overflow, InvalidOperation, Clamped, Underflow],
    flags=[],
)

ExtendedContext = Context(
    prec=9, rounding=ROUND_HALF_EVEN,
    traps=[],
    flags=[],
)
