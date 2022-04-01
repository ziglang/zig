"""Float constants"""

import math, struct
from math import acosh, asinh, atanh, log1p, expm1
import sys

from rpython.annotator.model import SomeString, SomeChar
from rpython.rlib import objectmodel, unroll
from rpython.rtyper.extfunc import register_external
from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.objectmodel import not_rpython


if sys.platform == 'win32':
    libraries = []
else:
    libraries = ["m"]

class CConfig:
    _compilation_info_ = ExternalCompilationInfo(
            includes=["float.h", "math.h"], libraries=libraries)

float_constants = ["DBL_MAX", "DBL_MIN", "DBL_EPSILON"]
int_constants = ["DBL_MAX_EXP", "DBL_MAX_10_EXP",
                 "DBL_MIN_EXP", "DBL_MIN_10_EXP",
                 "DBL_DIG", "DBL_MANT_DIG",
                 "FLT_RADIX", "FLT_ROUNDS"]
for const in float_constants:
    setattr(CConfig, const, rffi_platform.DefinedConstantDouble(const))
for const in int_constants:
    setattr(CConfig, const, rffi_platform.DefinedConstantInteger(const))
del float_constants, int_constants, const

nextafter = rffi.llexternal(
    'nextafter', [rffi.DOUBLE, rffi.DOUBLE], rffi.DOUBLE,
    compilation_info=CConfig._compilation_info_, sandboxsafe=True)

globals().update(rffi_platform.configure(CConfig))

INVALID_MSG = "could not convert string to float"

def string_to_float(s):
    """
    Conversion of string to float.
    This version tries to only raise on invalid literals.
    Overflows should be converted to infinity whenever possible.

    Expects an unwrapped string and return an unwrapped float.
    """
    from rpython.rlib.rstring import strip_spaces, ParseStringError

    if not s:
        raise ParseStringError(INVALID_MSG)
    def iswhitespace(ch):
        return (ch == ' ' or ch == '\f' or ch == '\n' or ch == '\r' or
            ch == '\t' or ch == '\v')
    if iswhitespace(s[0]) or iswhitespace(s[-1]):
        s = strip_spaces(s)
    try:
        return rstring_to_float(s)
    except ValueError:
        low = s.lower()
        if low == "-inf" or low == "-infinity":
            return -INFINITY
        elif low == "inf" or low == "+inf":
            return INFINITY
        elif low == "infinity" or low == "+infinity":
            return INFINITY
        elif low == "nan" or low == "+nan":
            return NAN
        elif low == "-nan":
            return -NAN
        raise ParseStringError(INVALID_MSG)

def rstring_to_float(s):
    from rpython.rlib.rdtoa import strtod
    return strtod(s)

# float -> string

DTSF_STR_PRECISION = 12

DTSF_SIGN      = 0x1
DTSF_ADD_DOT_0 = 0x2
DTSF_ALT       = 0x4
DTSF_CUT_EXP_0 = 0x8

DIST_FINITE   = 1
DIST_NAN      = 2
DIST_INFINITY = 3

@objectmodel.enforceargs(float, SomeChar(), int, int)
def formatd(x, code, precision, flags=0):
    from rpython.rlib.rdtoa import dtoa_formatd
    return dtoa_formatd(x, code, precision, flags)

def double_to_string(value, tp, precision, flags):
    if isfinite(value):
        special = DIST_FINITE
    elif math.isinf(value):
        special = DIST_INFINITY
    else:  #isnan(value):
        special = DIST_NAN
    result = formatd(value, tp, precision, flags)
    return result, special

def round_double(value, ndigits, half_even=False):
    """Round a float half away from zero.

    Specify half_even=True to round half even instead.
    The argument 'value' must be a finite number.  This
    function may return an infinite number in case of
    overflow (only if ndigits is a very negative integer).
    """
    if ndigits == 0:
        # fast path for this common case
        if half_even:
            return round_half_even(value)
        else:
            return round_away(value)

    if value == 0.0:
        return 0.0

    # The basic idea is very simple: convert and round the double to
    # a decimal string using _Py_dg_dtoa, then convert that decimal
    # string back to a double with _Py_dg_strtod.  There's one minor
    # difficulty: Python 2.x expects round to do
    # round-half-away-from-zero, while _Py_dg_dtoa does
    # round-half-to-even.  So we need some way to detect and correct
    # the halfway cases.

    # a halfway value has the form k * 0.5 * 10**-ndigits for some
    # odd integer k.  Or in other words, a rational number x is
    # exactly halfway between two multiples of 10**-ndigits if its
    # 2-valuation is exactly -ndigits-1 and its 5-valuation is at
    # least -ndigits.  For ndigits >= 0 the latter condition is
    # automatically satisfied for a binary float x, since any such
    # float has nonnegative 5-valuation.  For 0 > ndigits >= -22, x
    # needs to be an integral multiple of 5**-ndigits; we can check
    # this using fmod.  For -22 > ndigits, there are no halfway
    # cases: 5**23 takes 54 bits to represent exactly, so any odd
    # multiple of 0.5 * 10**n for n >= 23 takes at least 54 bits of
    # precision to represent exactly.

    sign = math.copysign(1.0, value)
    value = abs(value)

    # find 2-valuation value
    m, expo = math.frexp(value)
    while m != math.floor(m):
        m *= 2.0
        expo -= 1

    # determine whether this is a halfway case.
    halfway_case = 0
    if not half_even and expo == -ndigits - 1:
        if ndigits >= 0:
            halfway_case = 1
        elif ndigits >= -22:
            # 22 is the largest k such that 5**k is exactly
            # representable as a double
            five_pow = 1.0
            for i in range(-ndigits):
                five_pow *= 5.0
            if math.fmod(value, five_pow) == 0.0:
                halfway_case = 1

    # round to a decimal string; use an extra place for halfway case
    strvalue = formatd(value, 'f', ndigits + halfway_case)

    if not half_even and halfway_case:
        buf = [c for c in strvalue]
        if ndigits >= 0:
            endpos = len(buf) - 1
        else:
            endpos = len(buf) + ndigits
        # Sanity checks: there should be exactly ndigits+1 places
        # following the decimal point, and the last digit in the
        # buffer should be a '5'
        if not objectmodel.we_are_translated():
            assert buf[endpos] == '5'
            if '.' in buf:
                assert endpos == len(buf) - 1
                assert buf.index('.') == len(buf) - ndigits - 2

        # increment and shift right at the same time
        i = endpos - 1
        carry = 1
        while i >= 0:
            digit = ord(buf[i])
            if digit == ord('.'):
                buf[i+1] = chr(digit)
                i -= 1
                digit = ord(buf[i])

            carry += digit - ord('0')
            buf[i+1] = chr(carry % 10 + ord('0'))
            carry /= 10
            i -= 1
        buf[0] = chr(carry + ord('0'))
        if ndigits < 0:
            buf.append('0')

        strvalue = ''.join(buf)

    return sign * rstring_to_float(strvalue)


INFINITY = 1e200 * 1e200
NAN = abs(INFINITY / INFINITY)    # bah, INF/INF gives us -NAN?


def log2(x):
    # Uses an algorithm that should:
    #   (a) produce exact results for powers of 2, and
    #   (b) be monotonic, assuming that the system log is monotonic.
    if not isfinite(x):
        if math.isnan(x):
            return x  # log2(nan) = nan
        elif x > 0.0:
            return x  # log2(+inf) = +inf
        else:
            # log2(-inf) = nan, invalid-operation
            raise ValueError("math domain error")

    if x > 0.0:
        if 0:  # HAVE_LOG2
            return math.log2(x)
        m, e = math.frexp(x)
        # We want log2(m * 2**e) == log(m) / log(2) + e.  Care is needed when
        # x is just greater than 1.0: in that case e is 1, log(m) is negative,
        # and we get significant cancellation error from the addition of
        # log(m) / log(2) to e.  The slight rewrite of the expression below
        # avoids this problem.
        if x >= 1.0:
            return math.log(2.0 * m) / math.log(2.0) + (e - 1)
        else:
            return math.log(m) / math.log(2.0) + e
    else:
        raise ValueError("math domain error")

def round_away(x):
    # round() from libm, which is not available on all platforms!
    # This version rounds away from zero.
    absx = abs(x)
    r = math.floor(absx + 0.5)
    if r - absx < 1.0:
        return math.copysign(r, x)
    else:
        # 'absx' is just in the wrong range: its exponent is precisely
        # the one for which all integers are representable but not any
        # half-integer.  It means that 'absx + 0.5' computes equal to
        # 'absx + 1.0', which is not equal to 'absx'.  So 'r - absx'
        # computes equal to 1.0.  In this situation, we can't return
        # 'r' because 'absx' was already an integer but 'r' is the next
        # integer!  But just returning the original 'x' is fine.
        return x

def round_half_even(x):
    absx = abs(x)
    r = math.floor(absx + 0.5)
    frac = r - absx
    if frac >= 0.5:
        # two rare cases: either 'absx' is precisely half-way between
        # two integers (frac == 0.5); or we're in the same situation as
        # described in round_away above (frac == 1.0).
        if frac >= 1.0:
            return x
        # absx == n + 0.5  for a non-negative integer 'n'
        # absx * 0.5 == n//2 + 0.25 or 0.75, which we round to nearest
        r = math.floor(absx * 0.5 + 0.5) * 2.0
    return math.copysign(r, x)

@not_rpython
def isfinite(x):
    return not math.isinf(x) and not math.isnan(x)

def float_as_rbigint_ratio(value):
    from rpython.rlib.rbigint import rbigint

    if math.isinf(value):
        raise OverflowError("cannot pass infinity to as_integer_ratio()")
    elif math.isnan(value):
        raise ValueError("cannot pass nan to as_integer_ratio()")
    float_part, exp_int = math.frexp(value)
    for i in range(300):
        if float_part == math.floor(float_part):
            break
        float_part *= 2.0
        exp_int -= 1
    num = rbigint.fromfloat(float_part)
    den = rbigint.fromint(1)
    exp = den.lshift(abs(exp_int))
    if exp_int > 0:
        num = num.mul(exp)
    else:
        den = exp
    return num, den



# Implementation of the error function, the complimentary error function, the
# gamma function, and the natural log of the gamma function.  These exist in
# libm, but I hear those implementations are horrible.

ERF_SERIES_CUTOFF = 1.5
ERF_SERIES_TERMS = 25
ERFC_CONTFRAC_CUTOFF = 30.
ERFC_CONTFRAC_TERMS = 50
_sqrtpi = 1.772453850905516027298167483341145182798

def _erf_series(x):
    x2 = x * x
    acc = 0.
    fk = ERF_SERIES_TERMS + .5
    for i in range(ERF_SERIES_TERMS):
        acc = 2.0 + x2 * acc / fk
        fk -= 1.
    return acc * x * math.exp(-x2) / _sqrtpi

def _erfc_contfrac(x):
    if x >= ERFC_CONTFRAC_CUTOFF:
        return 0.
    x2 = x * x
    a = 0.
    da = .5
    p = 1.
    p_last = 0.
    q = da + x2
    q_last = 1.
    for i in range(ERFC_CONTFRAC_TERMS):
        a += da
        da += 2.
        b = da + x2
        p_last, p = p, b * p - a * p_last
        q_last, q = q, b * q - a * q_last
    return p / q * x * math.exp(-x2) / _sqrtpi

def erf(x):
    """The error function at x."""
    if math.isnan(x):
        return x
    absx = abs(x)
    if absx < ERF_SERIES_CUTOFF:
        return _erf_series(x)
    else:
        cf = _erfc_contfrac(absx)
        return 1. - cf if x > 0. else cf - 1.

def erfc(x):
    """The complementary error function at x."""
    if math.isnan(x):
        return x
    absx = abs(x)
    if absx < ERF_SERIES_CUTOFF:
        return 1. - _erf_series(x)
    else:
        cf = _erfc_contfrac(absx)
        return cf if x > 0. else 2. - cf

def _sinpi(x):
    y = math.fmod(abs(x), 2.)
    n = int(round_away(2. * y))
    if n == 0:
        r = math.sin(math.pi * y)
    elif n == 1:
        r = math.cos(math.pi * (y - .5))
    elif n == 2:
        r = math.sin(math.pi * (1. - y))
    elif n == 3:
        r = -math.cos(math.pi * (y - 1.5))
    elif n == 4:
        r = math.sin(math.pi * (y - 2.))
    else:
        raise AssertionError("should not reach")
    return math.copysign(1., x) * r

_lanczos_g = 6.024680040776729583740234375
_lanczos_g_minus_half = 5.524680040776729583740234375
_lanczos_num_coeffs = [
    23531376880.410759688572007674451636754734846804940,
    42919803642.649098768957899047001988850926355848959,
    35711959237.355668049440185451547166705960488635843,
    17921034426.037209699919755754458931112671403265390,
    6039542586.3520280050642916443072979210699388420708,
    1439720407.3117216736632230727949123939715485786772,
    248874557.86205415651146038641322942321632125127801,
    31426415.585400194380614231628318205362874684987640,
    2876370.6289353724412254090516208496135991145378768,
    186056.26539522349504029498971604569928220784236328,
    8071.6720023658162106380029022722506138218516325024,
    210.82427775157934587250973392071336271166969580291,
    2.5066282746310002701649081771338373386264310793408
]
_lanczos_den_coeffs = [
    0.0, 39916800.0, 120543840.0, 150917976.0, 105258076.0, 45995730.0,
    13339535.0, 2637558.0, 357423.0, 32670.0, 1925.0, 66.0, 1.0]
LANCZOS_N = len(_lanczos_den_coeffs)
_lanczos_n_iter = unroll.unrolling_iterable(range(LANCZOS_N))
_lanczos_n_iter_back = unroll.unrolling_iterable(range(LANCZOS_N - 1, -1, -1))
_gamma_integrals = [
    1.0, 1.0, 2.0, 6.0, 24.0, 120.0, 720.0, 5040.0, 40320.0, 362880.0,
    3628800.0, 39916800.0, 479001600.0, 6227020800.0, 87178291200.0,
    1307674368000.0, 20922789888000.0, 355687428096000.0,
    6402373705728000.0, 121645100408832000.0, 2432902008176640000.0,
    51090942171709440000.0, 1124000727777607680000.0]

def _lanczos_sum(x):
    num = 0.
    den = 0.
    assert x > 0.
    if x < 5.:
        for i in _lanczos_n_iter_back:
            num = num * x + _lanczos_num_coeffs[i]
            den = den * x + _lanczos_den_coeffs[i]
    else:
        for i in _lanczos_n_iter:
            num = num / x + _lanczos_num_coeffs[i]
            den = den / x + _lanczos_den_coeffs[i]
    return num / den

def gamma(x):
    """Compute the gamma function for x."""
    if math.isnan(x) or (math.isinf(x) and x > 0.):
        return x
    if math.isinf(x):
        raise ValueError("math domain error")
    if x == 0.:
        raise ValueError("math domain error")
    if x == math.floor(x):
        if x < 0.:
            raise ValueError("math domain error")
        if x < len(_gamma_integrals):
            return _gamma_integrals[int(x) - 1]
    absx = abs(x)
    if absx < 1e-20:
        r = 1. / x
        if math.isinf(r):
            raise OverflowError("math range error")
        return r
    if absx > 200.:
        if x < 0.:
            return 0. / -_sinpi(x)
        else:
            raise OverflowError("math range error")
    y = absx + _lanczos_g_minus_half
    if absx > _lanczos_g_minus_half:
        q = y - absx
        z = q - _lanczos_g_minus_half
    else:
        q = y - _lanczos_g_minus_half
        z = q - absx
    z = z * _lanczos_g / y
    if x < 0.:
        r = -math.pi / _sinpi(absx) / absx * math.exp(y) / _lanczos_sum(absx)
        r -= z * r
        if absx < 140.:
            r /= math.pow(y, absx - .5)
        else:
            sqrtpow = math.pow(y, absx / 2. - .25)
            r /= sqrtpow
            r /= sqrtpow
    else:
        r = _lanczos_sum(absx) / math.exp(y)
        r += z * r
        if absx < 140.:
            r *= math.pow(y, absx - .5)
        else:
            sqrtpow = math.pow(y, absx / 2. - .25)
            r *= sqrtpow
            r *= sqrtpow
    if math.isinf(r):
        raise OverflowError("math range error")
    return r

def lgamma(x):
    """Compute the natural logarithm of the gamma function for x."""
    if math.isnan(x):
        return x
    if math.isinf(x):
        return INFINITY
    if x == math.floor(x) and x <= 2.:
        if x <= 0.:
            raise ValueError("math range error")
        return 0.
    absx = abs(x)
    if absx < 1e-20:
        return -math.log(absx)
    if x > 0.:
        r = (math.log(_lanczos_sum(x)) - _lanczos_g + (x - .5) *
             (math.log(x + _lanczos_g - .5) - 1))
    else:
        r = (math.log(math.pi) - math.log(abs(_sinpi(absx))) - math.log(absx) -
             (math.log(_lanczos_sum(absx)) - _lanczos_g +
              (absx - .5) * (math.log(absx + _lanczos_g - .5) - 1)))
    if math.isinf(r):
        raise OverflowError("math domain error")
    return r


def to_ulps(x):
    """Convert a non-NaN float x to an integer, in such a way that
    adjacent floats are converted to adjacent integers.  Then
    abs(ulps(x) - ulps(y)) gives the difference in ulps between two
    floats.

    The results from this function will only make sense on platforms
    where C doubles are represented in IEEE 754 binary64 format.

    """
    n = struct.unpack('<q', struct.pack('<d', x))[0]
    if n < 0:
        n = ~(n+2**63)
    return n

def ulps_check(expected, got, ulps=20):
    """Given non-NaN floats `expected` and `got`,
    check that they're equal to within the given number of ulps.

    Returns None on success and an error message on failure."""

    ulps_error = to_ulps(got) - to_ulps(expected)
    if abs(ulps_error) <= ulps:
        return None
    return "error = {} ulps; permitted error = {} ulps".format(ulps_error,
                                                               ulps)

def acc_check(expected, got, rel_err=2e-15, abs_err = 5e-323):
    """Determine whether non-NaN floats a and b are equal to within a
    (small) rounding error.  The default values for rel_err and
    abs_err are chosen to be suitable for platforms where a float is
    represented by an IEEE 754 double.  They allow an error of between
    9 and 19 ulps."""

    # need to special case infinities, since inf - inf gives nan
    if math.isinf(expected) and got == expected:
        return None

    error = got - expected

    permitted_error = max(abs_err, rel_err * abs(expected))
    if abs(error) < permitted_error:
        return None
    return "error = {}; permitted error = {}".format(error,
                                                     permitted_error)
