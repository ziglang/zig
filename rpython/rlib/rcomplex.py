import math
from math import fabs
from rpython.rlib.rfloat import asinh, log1p, isfinite
from rpython.rlib.constant import DBL_MIN, CM_SCALE_UP, CM_SCALE_DOWN
from rpython.rlib.constant import CM_LARGE_DOUBLE, DBL_MANT_DIG
from rpython.rlib.constant import M_LN2, M_LN10
from rpython.rlib.constant import CM_SQRT_LARGE_DOUBLE, CM_SQRT_DBL_MIN
from rpython.rlib.constant import CM_LOG_LARGE_DOUBLE
from rpython.rlib.special_value import special_type, INF, NAN
from rpython.rlib.special_value import sqrt_special_values
from rpython.rlib.special_value import acos_special_values
from rpython.rlib.special_value import acosh_special_values
from rpython.rlib.special_value import asinh_special_values
from rpython.rlib.special_value import atanh_special_values
from rpython.rlib.special_value import log_special_values
from rpython.rlib.special_value import exp_special_values
from rpython.rlib.special_value import cosh_special_values
from rpython.rlib.special_value import sinh_special_values
from rpython.rlib.special_value import tanh_special_values
from rpython.rlib.special_value import rect_special_values

#binary

def c_add(x, y):
    (r1, i1), (r2, i2) = x, y
    r = r1 + r2
    i = i1 + i2
    return (r, i)

def c_sub(x, y):
    (r1, i1), (r2, i2) = x, y
    r = r1 - r2
    i = i1 - i2
    return (r, i)

def c_mul(x, y):
    (r1, i1), (r2, i2) = x, y
    r = r1 * r2 - i1 * i2
    i = r1 * i2 + i1 * r2
    return (r, i)

def c_div(x, y): #x/y
    (r1, i1), (r2, i2) = x, y
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
            raise ZeroDivisionError
        else:
            ratio = i2 / r2
            denom = r2 + i2 * ratio
            rr = (r1 + i1 * ratio) / denom
            ir = (i1 - r1 * ratio) / denom
    elif math.isnan(r2):
        rr = NAN
        ir = NAN
    else:
        ratio = r2 / i2
        denom = r2 * ratio + i2
        assert i2 != 0.0
        rr = (r1 * ratio + i1) / denom
        ir = (i1 * ratio - r1) / denom
    return (rr, ir)

def c_pow(x, y):
    (r1, i1), (r2, i2) = x, y
    if i1 == 0 and i2 == 0 and r1 > 0:
        rr = math.pow(r1, r2)
        ir = 0.
    elif r2 == 0.0 and i2 == 0.0:
        rr, ir = 1, 0
    elif r1 == 1.0 and i1 == 0.0:
        rr, ir = (1.0, 0.0)
    elif r1 == 0.0 and i1 == 0.0:
        if i2 != 0.0 or r2 < 0.0:
            raise ZeroDivisionError
        rr, ir = (0.0, 0.0)
    else:
        vabs = math.hypot(r1,i1)
        len = math.pow(vabs,r2)
        at = math.atan2(i1,r1)
        phase = at * r2
        if i2 != 0.0:
            len /= math.exp(at * i2)
            phase += i2 * math.log(vabs)
        try:
            rr = len * math.cos(phase)
            ir = len * math.sin(phase)
        except ValueError:
            rr = NAN
            ir = NAN
    return (rr, ir)

#unary

def c_neg(r, i):
    return (-r, -i)


def c_sqrt(x, y):
    '''
    Method: use symmetries to reduce to the case when x = z.real and y
    = z.imag are nonnegative.  Then the real part of the result is
    given by
    
      s = sqrt((x + hypot(x, y))/2)
    
    and the imaginary part is
    
      d = (y/2)/s
    
    If either x or y is very large then there's a risk of overflow in
    computation of the expression x + hypot(x, y).  We can avoid this
    by rewriting the formula for s as:
    
      s = 2*sqrt(x/8 + hypot(x/8, y/8))
    
    This costs us two extra multiplications/divisions, but avoids the
    overhead of checking for x and y large.
    
    If both x and y are subnormal then hypot(x, y) may also be
    subnormal, so will lack full precision.  We solve this by rescaling
    x and y by a sufficiently large power of 2 to ensure that x and y
    are normal.
    '''
    if not isfinite(x) or not isfinite(y):
        return sqrt_special_values[special_type(x)][special_type(y)]

    if x == 0. and y == 0.:
        return (0., y)

    ax = fabs(x)
    ay = fabs(y)

    if ax < DBL_MIN and ay < DBL_MIN and (ax > 0. or ay > 0.):
        # here we catch cases where hypot(ax, ay) is subnormal
        ax = math.ldexp(ax, CM_SCALE_UP)
        ay1= math.ldexp(ay, CM_SCALE_UP)
        s = math.ldexp(math.sqrt(ax + math.hypot(ax, ay1)),
                       CM_SCALE_DOWN)
    else:
        ax /= 8.
        s = 2.*math.sqrt(ax + math.hypot(ax, ay/8.))

    d = ay/(2.*s)

    if x >= 0.:
        return (s, math.copysign(d, y))
    else:
        return (d, math.copysign(s, y))



def c_acos(x, y):
    if not isfinite(x) or not isfinite(y):
        return acos_special_values[special_type(x)][special_type(y)]

    if fabs(x) > CM_LARGE_DOUBLE or fabs(y) > CM_LARGE_DOUBLE:
        # avoid unnecessary overflow for large arguments
        real = math.atan2(fabs(y), x)
        # split into cases to make sure that the branch cut has the
        # correct continuity on systems with unsigned zeros
        if x < 0.:
            imag = -math.copysign(math.log(math.hypot(x/2., y/2.)) +
                             M_LN2*2., y)
        else:
            imag = math.copysign(math.log(math.hypot(x/2., y/2.)) +
                            M_LN2*2., -y)
    else:
        s1x, s1y = c_sqrt(1.-x, -y)
        s2x, s2y = c_sqrt(1.+x, y)
        real = 2.*math.atan2(s1x, s2x)
        imag = asinh(s2x*s1y - s2y*s1x)
    return (real, imag)


def c_acosh(x, y):
    # XXX the following two lines seem unnecessary at least on Linux;
    # the tests pass fine without them
    if not isfinite(x) or not isfinite(y):
        return acosh_special_values[special_type(x)][special_type(y)]

    if fabs(x) > CM_LARGE_DOUBLE or fabs(y) > CM_LARGE_DOUBLE:
        # avoid unnecessary overflow for large arguments
        real = math.log(math.hypot(x/2., y/2.)) + M_LN2*2.
        imag = math.atan2(y, x)
    else:
        s1x, s1y = c_sqrt(x - 1., y)
        s2x, s2y = c_sqrt(x + 1., y)
        real = asinh(s1x*s2x + s1y*s2y)
        imag = 2.*math.atan2(s1y, s2x)
    return (real, imag)


def c_asin(x, y):
    # asin(z) = -i asinh(iz)
    sx, sy = c_asinh(-y, x)
    return (sy, -sx)


def c_asinh(x, y):
    if not isfinite(x) or not isfinite(y):
        return asinh_special_values[special_type(x)][special_type(y)]

    if fabs(x) > CM_LARGE_DOUBLE or fabs(y) > CM_LARGE_DOUBLE:
        if y >= 0.:
            real = math.copysign(math.log(math.hypot(x/2., y/2.)) +
                            M_LN2*2., x)
        else:
            real = -math.copysign(math.log(math.hypot(x/2., y/2.)) +
                             M_LN2*2., -x)
        imag = math.atan2(y, fabs(x))
    else:
        s1x, s1y = c_sqrt(1.+y, -x)
        s2x, s2y = c_sqrt(1.-y, x)
        real = asinh(s1x*s2y - s2x*s1y)
        imag = math.atan2(y, s1x*s2x - s1y*s2y)
    return (real, imag)


def c_atan(x, y):
    # atan(z) = -i atanh(iz)
    sx, sy = c_atanh(-y, x)
    return (sy, -sx)


def c_atanh(x, y):
    if not isfinite(x) or not isfinite(y):
        return atanh_special_values[special_type(x)][special_type(y)]

    # Reduce to case where x >= 0., using atanh(z) = -atanh(-z).
    if x < 0.:
        return c_neg(*c_atanh(*c_neg(x, y)))

    ay = fabs(y)
    if x > CM_SQRT_LARGE_DOUBLE or ay > CM_SQRT_LARGE_DOUBLE:
        # if abs(z) is large then we use the approximation
        # atanh(z) ~ 1/z +/- i*pi/2 (+/- depending on the sign
        # of y
        h = math.hypot(x/2., y/2.)   # safe from overflow
        real = x/4./h/h
        # the two negations in the next line cancel each other out
        # except when working with unsigned zeros: they're there to
        # ensure that the branch cut has the correct continuity on
        # systems that don't support signed zeros
        imag = -math.copysign(math.pi/2., -y)
    elif x == 1. and ay < CM_SQRT_DBL_MIN:
        # C99 standard says:  atanh(1+/-0.) should be inf +/- 0i
        if ay == 0.:
            raise ValueError("math domain error")
            #real = INF
            #imag = y
        else:
            real = -math.log(math.sqrt(ay)/math.sqrt(math.hypot(ay, 2.)))
            imag = math.copysign(math.atan2(2., -ay) / 2, y)
    else:
        real = log1p(4.*x/((1-x)*(1-x) + ay*ay))/4.
        imag = -math.atan2(-2.*y, (1-x)*(1+x) - ay*ay) / 2.
    return (real, imag)


def c_log(x, y):
    # The usual formula for the real part is log(hypot(z.real, z.imag)).
    # There are four situations where this formula is potentially
    # problematic:
    #
    # (1) the absolute value of z is subnormal.  Then hypot is subnormal,
    # so has fewer than the usual number of bits of accuracy, hence may
    # have large relative error.  This then gives a large absolute error
    # in the log.  This can be solved by rescaling z by a suitable power
    # of 2.
    #
    # (2) the absolute value of z is greater than DBL_MAX (e.g. when both
    # z.real and z.imag are within a factor of 1/sqrt(2) of DBL_MAX)
    # Again, rescaling solves this.
    #
    # (3) the absolute value of z is close to 1.  In this case it's
    # difficult to achieve good accuracy, at least in part because a
    # change of 1ulp in the real or imaginary part of z can result in a
    # change of billions of ulps in the correctly rounded answer.
    #
    # (4) z = 0.  The simplest thing to do here is to call the
    # floating-point log with an argument of 0, and let its behaviour
    # (returning -infinity, signaling a floating-point exception, setting
    # errno, or whatever) determine that of c_log.  So the usual formula
    # is fine here.

    # XXX the following two lines seem unnecessary at least on Linux;
    # the tests pass fine without them
    if not isfinite(x) or not isfinite(y):
        return log_special_values[special_type(x)][special_type(y)]

    ax = fabs(x)
    ay = fabs(y)

    if ax > CM_LARGE_DOUBLE or ay > CM_LARGE_DOUBLE:
        real = math.log(math.hypot(ax/2., ay/2.)) + M_LN2
    elif ax < DBL_MIN and ay < DBL_MIN:
        if ax > 0. or ay > 0.:
            # catch cases where hypot(ax, ay) is subnormal
            real = math.log(math.hypot(math.ldexp(ax, DBL_MANT_DIG),
                                       math.ldexp(ay, DBL_MANT_DIG)))
            real -= DBL_MANT_DIG*M_LN2
        else:
            # log(+/-0. +/- 0i)
            raise ValueError("math domain error")
            #real = -INF
            #imag = atan2(y, x)
    else:
        h = math.hypot(ax, ay)
        if 0.71 <= h and h <= 1.73:
            am = max(ax, ay)
            an = min(ax, ay)
            real = log1p((am-1)*(am+1) + an*an) / 2.
        else:
            real = math.log(h)
    imag = math.atan2(y, x)
    return (real, imag)


def c_log10(x, y):
    rx, ry = c_log(x, y)
    return (rx / M_LN10, ry / M_LN10)

def c_exp(x, y):
    if not isfinite(x) or not isfinite(y):
        if math.isinf(x) and isfinite(y) and y != 0.:
            if x > 0:
                real = math.copysign(INF, math.cos(y))
                imag = math.copysign(INF, math.sin(y))
            else:
                real = math.copysign(0., math.cos(y))
                imag = math.copysign(0., math.sin(y))
            r = (real, imag)
        else:
            r = exp_special_values[special_type(x)][special_type(y)]

        # need to raise ValueError if y is +/- infinity and x is not
        # a NaN and not -infinity
        if math.isinf(y) and (isfinite(x) or (math.isinf(x) and x > 0)):
            raise ValueError("math domain error")
        return r

    if x > CM_LOG_LARGE_DOUBLE:
        l = math.exp(x-1.)
        real = l * math.cos(y) * math.e
        imag = l * math.sin(y) * math.e
    else:
        l = math.exp(x)
        real = l * math.cos(y)
        imag = l * math.sin(y)
    if math.isinf(real) or math.isinf(imag):
        raise OverflowError("math range error")
    return real, imag


def c_cosh(x, y):
    if not isfinite(x) or not isfinite(y):
        if math.isinf(x) and isfinite(y) and y != 0.:
            if x > 0:
                real = math.copysign(INF, math.cos(y))
                imag = math.copysign(INF, math.sin(y))
            else:
                real = math.copysign(INF, math.cos(y))
                imag = -math.copysign(INF, math.sin(y))
            r = (real, imag)
        else:
            r = cosh_special_values[special_type(x)][special_type(y)]

        # need to raise ValueError if y is +/- infinity and x is not
        # a NaN
        if math.isinf(y) and not math.isnan(x):
            raise ValueError("math domain error")
        return r

    if fabs(x) > CM_LOG_LARGE_DOUBLE:
        # deal correctly with cases where cosh(x) overflows but
        # cosh(z) does not.
        x_minus_one = x - math.copysign(1., x)
        real = math.cos(y) * math.cosh(x_minus_one) * math.e
        imag = math.sin(y) * math.sinh(x_minus_one) * math.e
    else:
        real = math.cos(y) * math.cosh(x)
        imag = math.sin(y) * math.sinh(x)
    if math.isinf(real) or math.isinf(imag):
        raise OverflowError("math range error")
    return real, imag


def c_sinh(x, y):
    # special treatment for sinh(+/-inf + iy) if y is finite and nonzero
    if not isfinite(x) or not isfinite(y):
        if math.isinf(x) and isfinite(y) and y != 0.:
            if x > 0:
                real = math.copysign(INF, math.cos(y))
                imag = math.copysign(INF, math.sin(y))
            else:
                real = -math.copysign(INF, math.cos(y))
                imag = math.copysign(INF, math.sin(y))
            r = (real, imag)
        else:
            r = sinh_special_values[special_type(x)][special_type(y)]

        # need to raise ValueError if y is +/- infinity and x is not
        # a NaN
        if math.isinf(y) and not math.isnan(x):
            raise ValueError("math domain error")
        return r

    if fabs(x) > CM_LOG_LARGE_DOUBLE:
        x_minus_one = x - math.copysign(1., x)
        real = math.cos(y) * math.sinh(x_minus_one) * math.e
        imag = math.sin(y) * math.cosh(x_minus_one) * math.e
    else:
        real = math.cos(y) * math.sinh(x)
        imag = math.sin(y) * math.cosh(x)
    if math.isinf(real) or math.isinf(imag):
        raise OverflowError("math range error")
    return real, imag


def c_tanh(x, y):
    # Formula:
    #
    #   tanh(x+iy) = (tanh(x)(1+tan(y)^2) + i tan(y)(1-tanh(x))^2) /
    #   (1+tan(y)^2 tanh(x)^2)
    #
    #   To avoid excessive roundoff error, 1-tanh(x)^2 is better computed
    #   as 1/cosh(x)^2.  When abs(x) is large, we approximate 1-tanh(x)^2
    #   by 4 exp(-2*x) instead, to avoid possible overflow in the
    #   computation of cosh(x).

    if not isfinite(x) or not isfinite(y):
        if math.isinf(x) and isfinite(y) and y != 0.:
            if x > 0:
                real = 1.0        # vv XXX why is the 2. there?
                imag = math.copysign(0., 2. * math.sin(y) * math.cos(y))
            else:
                real = -1.0
                imag = math.copysign(0., 2. * math.sin(y) * math.cos(y))
            r = (real, imag)
        else:
            r = tanh_special_values[special_type(x)][special_type(y)]

        # need to raise ValueError if y is +/-infinity and x is finite
        if math.isinf(y) and isfinite(x):
            raise ValueError("math domain error")
        return r

    if fabs(x) > CM_LOG_LARGE_DOUBLE:
        real = math.copysign(1., x)
        imag = 4. * math.sin(y) * math.cos(y) * math.exp(-2.*fabs(x))
    else:
        tx = math.tanh(x)
        ty = math.tan(y)
        cx = 1. / math.cosh(x)
        txty = tx * ty
        denom = 1. + txty * txty
        real = tx * (1. + ty*ty) / denom
        imag = ((ty / denom) * cx) * cx
    return real, imag


def c_cos(r, i):
    # cos(z) = cosh(iz)
    return c_cosh(-i, r)

def c_sin(r, i):
    # sin(z) = -i sinh(iz)
    sr, si = c_sinh(-i, r)
    return si, -sr

def c_tan(r, i):
    # tan(z) = -i tanh(iz)
    sr, si = c_tanh(-i, r)
    return si, -sr


def c_rect(r, phi):
    if not isfinite(r) or not isfinite(phi):
        # if r is +/-infinity and phi is finite but nonzero then
        # result is (+-INF +-INF i), but we need to compute cos(phi)
        # and sin(phi) to figure out the signs.
        if math.isinf(r) and isfinite(phi) and phi != 0.:
            if r > 0:
                real = math.copysign(INF, math.cos(phi))
                imag = math.copysign(INF, math.sin(phi))
            else:
                real = -math.copysign(INF, math.cos(phi))
                imag = -math.copysign(INF, math.sin(phi))
            z = (real, imag)
        else:
            z = rect_special_values[special_type(r)][special_type(phi)]

        # need to raise ValueError if r is a nonzero number and phi
        # is infinite
        if r != 0. and not math.isnan(r) and math.isinf(phi):
            raise ValueError("math domain error")
        return z

    real = r * math.cos(phi)
    imag = r * math.sin(phi)
    return real, imag


def c_phase(x, y):
    # Windows screws up atan2 for inf and nan, and alpha Tru64 5.1 doesn't
    # follow C99 for atan2(0., 0.).
    if math.isnan(x) or math.isnan(y):
        return NAN
    if math.isinf(y):
        if math.isinf(x):
            if math.copysign(1., x) == 1.:
                # atan2(+-inf, +inf) == +-pi/4
                return math.copysign(0.25 * math.pi, y)
            else:
                # atan2(+-inf, -inf) == +-pi*3/4
                return math.copysign(0.75 * math.pi, y)
        # atan2(+-inf, x) == +-pi/2 for finite x
        return math.copysign(0.5 * math.pi, y)
    if math.isinf(x) or y == 0.:
        if math.copysign(1., x) == 1.:
            # atan2(+-y, +inf) = atan2(+-0, +x) = +-0.
            return math.copysign(0., y)
        else:
            # atan2(+-y, -inf) = atan2(+-0., -x) = +-pi.
            return math.copysign(math.pi, y)
    return math.atan2(y, x)


def c_abs(r, i):
    if not isfinite(r) or not isfinite(i):
        # C99 rules: if either the real or the imaginary part is an
        # infinity, return infinity, even if the other part is a NaN.
        if math.isinf(r):
            return INF
        if math.isinf(i):
            return INF

        # either the real or imaginary part is a NaN,
        # and neither is infinite. Result should be NaN.
        return NAN

    result = math.hypot(r, i)
    if not isfinite(result):
        raise OverflowError("math range error")
    return result


def c_polar(r, i):
    real = c_abs(r, i)
    phi = c_phase(r, i)
    return real, phi


def c_isinf(r, i):
    return math.isinf(r) or math.isinf(i)


def c_isnan(r, i):
    return math.isnan(r) or math.isnan(i)


def c_isfinite(r, i):
    return isfinite(r) and isfinite(i)
