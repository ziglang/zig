import math
import sys

from rpython.rlib import rfloat
from rpython.rlib.objectmodel import specialize
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault

class State:
    def __init__(self, space):
        self.w_e = space.newfloat(math.e)
        self.w_pi = space.newfloat(math.pi)
        self.w_tau = space.newfloat(math.pi * 2.0)
        self.w_inf = space.newfloat(rfloat.INFINITY)
        self.w_nan = space.newfloat(rfloat.NAN)
def get(space):
    return space.fromcache(State)

def _get_double(space, w_x):
    if space.is_w(space.type(w_x), space.w_float):
        return space.float_w(w_x)
    else:
        return space.float_w(space.float(w_x))

@specialize.arg(1)
def math1(space, f, w_x):
    x = _get_double(space, w_x)
    try:
        y = f(x)
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    return space.newfloat(y)

@specialize.arg(1)
def math1_w(space, f, w_x):
    x = _get_double(space, w_x)
    try:
        r = f(x)
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    return r

@specialize.arg(1)
def math2(space, f, w_x, w_snd):
    x = _get_double(space, w_x)
    snd = _get_double(space, w_snd)
    try:
        r = f(x, snd)
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    return space.newfloat(r)

def trunc(space, w_x):
    """Truncate x."""
    w_descr = space.lookup(w_x, '__trunc__')
    if w_descr is not None:
        return space.get_and_call_function(w_descr, w_x)
    return space.trunc(w_x)

def copysign(space, w_x, w_y):
    """Return x with the sign of y."""
    # No exceptions possible.
    x = _get_double(space, w_x)
    y = _get_double(space, w_y)
    return space.newfloat(math.copysign(x, y))

def isinf(space, w_x):
    """Return True if x is infinity."""
    return space.newbool(math.isinf(_get_double(space, w_x)))

def isnan(space, w_x):
    """Return True if x is not a number."""
    return space.newbool(math.isnan(_get_double(space, w_x)))

def isfinite(space, w_x):
    """isfinite(x) -> bool

    Return True if x is neither an infinity nor a NaN, and False otherwise."""
    return space.newbool(rfloat.isfinite(_get_double(space, w_x)))

def pow(space, w_x, w_y):
    """pow(x,y)

       Return x**y (x to the power of y).
    """
    return math2(space, math.pow, w_x, w_y)

def cosh(space, w_x):
    """cosh(x)

       Return the hyperbolic cosine of x.
    """
    return math1(space, math.cosh, w_x)

def ldexp(space, w_x,  w_i):
    """ldexp(x, i) -> x * (2**i)
    """
    x = _get_double(space, w_x)
    if space.isinstance_w(w_i, space.w_int):
        try:
            exp = space.int_w(w_i)
        except OperationError as e:
            if not e.match(space, space.w_OverflowError):
                raise
            if space.is_true(space.lt(w_i, space.newint(0))):
                exp = -sys.maxint
            else:
                exp = sys.maxint
    else:
        raise oefmt(space.w_TypeError, "integer required for second argument")
    try:
        r = math.ldexp(x, exp)
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    return space.newfloat(r)

def hypot(space, args_w):
    """
    Multidimensional Euclidean distance from the origin to a point.

    Roughly equivalent to:
        sqrt(sum(x**2 for x in args))

    For a two dimensional point (x, y), gives the hypotenuse
    using the Pythagorean theorem:  sqrt(x*x + y*y).

    For example, the hypotenuse of a 3/4/5 right triangle is:

        >>> hypot(3.0, 4.0)
        5.0
    """
    vec = [0.0] * len(args_w)
    found_nan = False
    max = 0.0
    for i in range(len(args_w)):
        w_x = args_w[i]
        x = math.fabs(_get_double(space, w_x))
        found_nan = math.isnan(x) or found_nan
        if x > max:
            max = x
        vec[i] = x
    result = _vector_norm(vec, max, found_nan)
    return space.newfloat(result)

def dist(space, w_p, w_q, __posonly__=None):
    """
    Return the Euclidean distance between two points p and q.

    The points should be specified as sequences (or iterables) of
    coordinates.  Both inputs must have the same dimension.

    Roughly equivalent to:
        sqrt(sum((px - qx) ** 2.0 for px, qx in zip(p, q)))
    """
    p_w = space.unpackiterable(w_p)
    q_w = space.unpackiterable(w_q)
    if len(p_w) != len(q_w):
        raise oefmt(space.w_ValueError, "both points must have the same number of dimensions")

    vec = [0.0] * len(p_w)
    found_nan = False
    max = 0.0
    for i in range(len(p_w)):
        px = _get_double(space, p_w[i])
        qx = _get_double(space, q_w[i])
        x = math.fabs(px - qx)
        found_nan = math.isnan(x) or found_nan
        if x > max:
            max = x
        vec[i] = x
    result = _vector_norm(vec, max, found_nan)
    return space.newfloat(result)


def _vector_norm(vec, max, found_nan):
    # code and comment from CPython's vector_norm

    # Given an *n* length *vec* of values and a value *max*, compute:
    #
    #     max * sqrt(sum((x / max) ** 2 for x in vec))
    #
    # The value of the *max* variable must be non-negative and equal to the
    # absolute value of the largest magnitude entry in the vector.  If n==0,
    # then *max* should be 0.0. If an infinity is present in the vec, *max*
    # should be INF.
    #
    # The *found_nan* variable indicates whether some member of the *vec* is a
    # NaN.
    #
    # To improve accuracy and to increase the number of cases where
    # vector_norm() is commutative, we use a variant of Neumaier summation
    # specialized to exploit that we always know that |csum| >= |x|.
    #
    # The *csum* variable tracks the cumulative sum and *frac* tracks the
    # cumulative fractional errors at each step.  Since this variant assumes
    # that |csum| >= |x| at each step, we establish the precondition by
    # starting the accumulation from 1.0 which represents the largest possible
    # value of (x/max)**2.
    #
    # After the loop is finished, the initial 1.0 is subtracted out for a net
    # zero effect on the final sum.  Since *csum* will be greater than 1.0, the
    # subtraction of 1.0 will not cause fractional digits to be dropped from
    # *csum*.

    x = csum = 1.0
    oldsum = frac = 0.0
    if math.isinf(max):
        return max
    if found_nan:
        return rfloat.NAN
    if max == 0.0 or len(vec) <= 1:
        return max
    for x in vec:
        assert rfloat.isfinite(x) and math.fabs(x) <= max
        x /= max
        x = x * x
        oldcsum = csum
        csum += x
        assert csum >= x
        frac += (oldcsum - csum) + x
    return max * math.sqrt(csum - 1.0 + frac)


def tan(space, w_x):
    """tan(x)

       Return the tangent of x (measured in radians).
    """
    return math1(space, math.tan, w_x)

def asin(space, w_x):
    """asin(x)

       Return the arc sine (measured in radians) of x.
    """
    return math1(space, math.asin, w_x)

def fabs(space, w_x):
    """fabs(x)

       Return the absolute value of the float x.
    """
    return math1(space, math.fabs, w_x)

def floor(space, w_x):
    """floor(x)

       Return the floor of x as an int.
       This is the largest integral value <= x.
    """
    from pypy.objspace.std.floatobject import newint_from_float
    w_descr = space.lookup(w_x, '__floor__')
    if w_descr is not None:
        return space.get_and_call_function(w_descr, w_x)
    x = _get_double(space, w_x)
    return newint_from_float(space, math.floor(x))

def sqrt(space, w_x):
    """sqrt(x)

       Return the square root of x.
    """
    return math1(space, math.sqrt, w_x)

def frexp(space, w_x):
    """frexp(x)

       Return the mantissa and exponent of x, as pair (m, e).
       m is a float and e is an int, such that x = m * 2.**e.
       If x is 0, m and e are both 0.  Else 0.5 <= abs(m) < 1.0.
    """
    mant, expo = math1_w(space, math.frexp, w_x)
    return space.newtuple([space.newfloat(mant), space.newint(expo)])

degToRad = math.pi / 180.0

def degrees(space, w_x):
    """degrees(x) -> converts angle x from radians to degrees
    """
    return space.newfloat(_get_double(space, w_x) / degToRad)

def _log_any(space, w_x, base):
    # base is supposed to be positive or 0.0, which means we use e
    try:
        try:
            x = _get_double(space, w_x)
        except OperationError as e:
            if not e.match(space, space.w_OverflowError):
                raise
            if not space.isinstance_w(w_x, space.w_int):
                raise
            # special case to support log(extremely-large-long)
            num = space.bigint_w(w_x)
            result = num.log(base)
        else:
            if base == 10.0:
                result = math.log10(x)
            elif base == 2.0:
                result = rfloat.log2(x)
            else:
                result = math.log(x)
                if base != 0.0:
                    den = math.log(base)
                    result /= den
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    return space.newfloat(result)

def log(space, w_x, w_base=None):
    """log(x[, base]) -> the logarithm of x to the given base.
       If the base not specified, returns the natural logarithm (base e) of x.
    """
    if w_base is None:
        base = 0.0
    else:
        base = _get_double(space, w_base)
        if base <= 0.0:
            # just for raising the proper errors
            return math1(space, math.log, w_base)
    return _log_any(space, w_x, base)

def log2(space, w_x):
    """log2(x) -> the base 2 logarithm of x.
    """
    return _log_any(space, w_x, 2.0)

def log10(space, w_x):
    """log10(x) -> the base 10 logarithm of x.
    """
    return _log_any(space, w_x, 10.0)

def fmod(space, w_x, w_y):
    """fmod(x,y)

       Return fmod(x, y), according to platform C.  x % y may differ.
    """
    return math2(space, math.fmod, w_x, w_y)

def atan(space, w_x):
    """atan(x)

       Return the arc tangent (measured in radians) of x.
    """
    return math1(space, math.atan, w_x)

def ceil(space, w_x):
    """ceil(x)

       Return the ceiling of x as an int.
       This is the smallest integral value >= x.
    """
    from pypy.objspace.std.floatobject import newint_from_float
    w_descr = space.lookup(w_x, '__ceil__')
    if w_descr is not None:
        return space.get_and_call_function(w_descr, w_x)
    return newint_from_float(space, math1_w(space, math.ceil, w_x))

def sinh(space, w_x):
    """sinh(x)

       Return the hyperbolic sine of x.
    """
    return math1(space, math.sinh, w_x)

def cos(space, w_x):
    """cos(x)

       Return the cosine of x (measured in radians).
    """
    return math1(space, math.cos, w_x)

def tanh(space, w_x):
    """tanh(x)

       Return the hyperbolic tangent of x.
    """
    return math1(space, math.tanh, w_x)

def radians(space, w_x):
    """radians(x) -> converts angle x from degrees to radians
    """
    return space.newfloat(_get_double(space, w_x) * degToRad)

def sin(space, w_x):
    """sin(x)

       Return the sine of x (measured in radians).
    """
    return math1(space, math.sin, w_x)

def atan2(space, w_y, w_x):
    """atan2(y, x)

       Return the arc tangent (measured in radians) of y/x.
       Unlike atan(y/x), the signs of both x and y are considered.
    """
    return math2(space, math.atan2, w_y,  w_x)

def modf(space, w_x):
    """modf(x)

       Return the fractional and integer parts of x.  Both results carry the sign
       of x.  The integer part is returned as a real.
    """
    frac, intpart = math1_w(space, math.modf, w_x)
    return space.newtuple([space.newfloat(frac), space.newfloat(intpart)])

def exp(space, w_x):
    """exp(x)

       Return e raised to the power of x.
    """
    return math1(space, math.exp, w_x)

def acos(space, w_x):
    """acos(x)

       Return the arc cosine (measured in radians) of x.
    """
    return math1(space, math.acos, w_x)

def fsum(space, w_iterable):
    """Sum an iterable of floats, trying to keep precision."""
    w_iter = space.iter(w_iterable)
    inf_sum = special_sum = 0.0
    partials = []
    while True:
        try:
            w_value = space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            break
        v = _get_double(space, w_value)
        original = v
        added = 0
        for y in partials:
            if abs(v) < abs(y):
                v, y = y, v
            hi = v + y
            yr = hi - v
            lo = y - yr
            if lo != 0.0:
                partials[added] = lo
                added += 1
            v = hi
        del partials[added:]
        if v != 0.0:
            if not rfloat.isfinite(v):
                if rfloat.isfinite(original):
                    raise oefmt(space.w_OverflowError, "intermediate overflow")
                if math.isinf(original):
                    inf_sum += original
                special_sum += original
                del partials[:]
            else:
                partials.append(v)
    if special_sum != 0.0:
        if math.isnan(inf_sum):
            raise oefmt(space.w_ValueError, "-inf + inf")
        return space.newfloat(special_sum)
    hi = 0.0
    if partials:
        hi = partials[-1]
        j = 0
        lo = 0
        for j in range(len(partials) - 2, -1, -1):
            v = hi
            y = partials[j]
            assert abs(y) < abs(v)
            hi = v + y
            yr = hi - v
            lo = y - yr
            if lo != 0.0:
                break
        if j > 0 and (lo < 0.0 and partials[j - 1] < 0.0 or
                      lo > 0.0 and partials[j - 1] > 0.0):
            y = lo * 2.0
            v = hi + y
            yr = v - hi
            if y == yr:
                hi = v
    return space.newfloat(hi)

def log1p(space, w_x):
    """Find log(x + 1)."""
    try:
        return math1(space, rfloat.log1p, w_x)
    except OperationError as e:
        # Python 2.x (and thus ll_math) raises a OverflowError improperly.
        if not e.match(space, space.w_OverflowError):
            raise
        raise oefmt(space.w_ValueError, "math domain error")

def acosh(space, w_x):
    """Inverse hyperbolic cosine"""
    return math1(space, rfloat.acosh, w_x)

def asinh(space, w_x):
    """Inverse hyperbolic sine"""
    return math1(space, rfloat.asinh, w_x)

def atanh(space, w_x):
    """Inverse hyperbolic tangent"""
    return math1(space, rfloat.atanh, w_x)

def expm1(space, w_x):
    """exp(x) - 1"""
    return math1(space, rfloat.expm1, w_x)

def erf(space, w_x):
    """The error function"""
    return math1(space, rfloat.erf, w_x)

def erfc(space, w_x):
    """The complementary error function"""
    return math1(space, rfloat.erfc, w_x)

def gamma(space, w_x):
    """Compute the gamma function for x."""
    return math1(space, rfloat.gamma, w_x)

def lgamma(space, w_x):
    """Compute the natural logarithm of the gamma function for x."""
    return math1(space, rfloat.lgamma, w_x)

@unwrap_spec(w_rel_tol=WrappedDefault(1e-09), w_abs_tol=WrappedDefault(0.0))
def isclose(space, w_a, w_b, __kwonly__, w_rel_tol, w_abs_tol):
    """isclose(a, b, *, rel_tol=1e-09, abs_tol=0.0) -> bool

Determine whether two floating point numbers are close in value.

   rel_tol
       maximum difference for being considered "close", relative to the
       magnitude of the input values
   abs_tol
       maximum difference for being considered "close", regardless of the
       magnitude of the input values

Return True if a is close in value to b, and False otherwise.

For the values to be considered close, the difference between them
must be smaller than at least one of the tolerances.

-inf, inf and NaN behave similarly to the IEEE 754 Standard.  That
is, NaN is not close to anything, even itself.  inf and -inf are
only close to themselves."""
    a = _get_double(space, w_a)
    b = _get_double(space, w_b)
    rel_tol = _get_double(space, w_rel_tol)
    abs_tol = _get_double(space, w_abs_tol)
    #
    # sanity check on the inputs
    if rel_tol < 0.0 or abs_tol < 0.0:
        raise oefmt(space.w_ValueError, "tolerances must be non-negative")
    #
    # short circuit exact equality -- needed to catch two infinities of
    # the same sign. And perhaps speeds things up a bit sometimes.
    if a == b:
        return space.w_True
    #
    # This catches the case of two infinities of opposite sign, or
    # one infinity and one finite number. Two infinities of opposite
    # sign would otherwise have an infinite relative tolerance.
    # Two infinities of the same sign are caught by the equality check
    # above.
    if math.isinf(a) or math.isinf(b):
        return space.w_False
    #
    # now do the regular computation
    # this is essentially the "weak" test from the Boost library
    diff = math.fabs(b - a)
    result = ((diff <= math.fabs(rel_tol * b) or
               diff <= math.fabs(rel_tol * a)) or
              diff <= abs_tol)
    return space.newbool(result)

def gcd(space, args_w):
    """greatest common divisor"""
    if len(args_w) == 0:
        return space.newint(0)
    if len(args_w) == 1:
        space.index(args_w[0]) # for the error
        return space.abs(args_w[0])
    if len(args_w) == 2:
        return gcd_two(space, args_w[0], args_w[1])
    return _gcd_many(space, args_w)

def _gcd_many(space, args_w):
    w_res = args_w[0]
    # could jit this, but do we care?
    for i in range(1, len(args_w)):
        w_res = gcd_two(space, w_res, args_w[i])
    return w_res


def gcd_two(space, w_a, w_b):
    from rpython.rlib import rbigint
    w_a = space.abs(space.index(w_a))
    w_b = space.abs(space.index(w_b))
    try:
        a = space.int_w(w_a)
        b = space.int_w(w_b)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise

        a = space.bigint_w(w_a)
        b = space.bigint_w(w_b)
        g = a.gcd(b)
        return space.newlong_from_rbigint(g)
    else:
        g = rbigint.gcd_binary(a, b)
        return space.newint(g)

def nextafter(space, w_a, w_b):
    """ Return the next floating-point value after x towards y. """
    a = _get_double(space, w_a)
    b = _get_double(space, w_b)
    return space.newfloat(rfloat.nextafter(a, b))

def ulp(space, w_x):
    """Return the value of the least significant bit of the
    float x.
    """
    x = _get_double(space, w_x)
    if math.isnan(x):
        return w_x
    x = math.fabs(float(x))
    if math.isinf(x):
        return space.newfloat(x)

    x2 = rfloat.nextafter(x, rfloat.INFINITY)
    if math.isinf(x2):
        # special case: x is the largest positive representable float
        x2 = rfloat.nextafter(x, -rfloat.INFINITY)
        return space.newfloat(x - x2)
    return space.newfloat(x2 - x)

