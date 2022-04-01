import math
from rpython.rlib.objectmodel import specialize
from rpython.tool.sourcetools import func_with_new_name
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import unwrap_spec
from pypy.module.cmath.moduledef import names_and_docstrings
from rpython.rlib import rcomplex, rfloat

pi   = math.pi
e    = math.e
inf  = float('inf')
nan  = float('nan')
infj = complex(0.0, inf)
nanj = complex(0.0, nan)


@specialize.arg(0)
def call_c_func(c_func, space, x, y):
    try:
        result = c_func(x, y)
    except ValueError:
        raise oefmt(space.w_ValueError, "math domain error")
    except OverflowError:
        raise oefmt(space.w_OverflowError, "math range error")
    return result


def unaryfn(c_func):
    def wrapper(space, w_z):
        x, y = space.unpackcomplex(w_z)
        resx, resy = call_c_func(c_func, space, x, y)
        return space.newcomplex(resx, resy)
    #
    name = c_func.func_name
    assert name.startswith('c_')
    wrapper.func_doc = names_and_docstrings[name[2:]]
    fnname = 'wrapped_' + name[2:]
    globals()[fnname] = func_with_new_name(wrapper, fnname)
    return c_func


def c_neg(x, y):
    return rcomplex.c_neg(x,y)


@unaryfn
def c_sqrt(x, y):
    return rcomplex.c_sqrt(x,y)

@unaryfn
def c_acos(x, y):
    return rcomplex.c_acos(x,y)

@unaryfn
def c_acosh(x, y):
    return rcomplex.c_acosh(x,y)

@unaryfn
def c_asin(x, y):
    return rcomplex.c_asin(x,y)

@unaryfn
def c_asinh(x, y):
    return rcomplex.c_asinh(x,y)

@unaryfn
def c_atan(x, y):
    return rcomplex.c_atan(x,y)

@unaryfn
def c_atanh(x, y):
    return rcomplex.c_atanh(x,y)

@unaryfn
def c_log(x, y):
    return rcomplex.c_log(x,y)

_inner_wrapped_log = wrapped_log

def wrapped_log(space, w_z, w_base=None):
    w_logz = _inner_wrapped_log(space, w_z)
    if w_base is not None:
        w_logbase = _inner_wrapped_log(space, w_base)
        return space.truediv(w_logz, w_logbase)
    else:
        return w_logz
wrapped_log.func_doc = _inner_wrapped_log.func_doc


@unaryfn
def c_log10(x, y):
    return rcomplex.c_log10(x,y)

@unaryfn
def c_exp(x, y):
    return rcomplex.c_exp(x,y)

@unaryfn
def c_cosh(x, y):
    return rcomplex.c_cosh(x,y)

@unaryfn
def c_sinh(x, y):
    return rcomplex.c_sinh(x,y)

@unaryfn
def c_tanh(x, y):
    return rcomplex.c_tanh(x,y)

@unaryfn
def c_cos(x, y):
    return rcomplex.c_cos(x,y)

@unaryfn
def c_sin(x, y):
    return rcomplex.c_sin(x,y)

@unaryfn
def c_tan(x, y):
    return rcomplex.c_tan(x,y)

def c_rect(r, phi):
    return rcomplex.c_rect(r,phi)

def wrapped_rect(space, w_x, w_y):
    x = space.float_w(w_x)
    y = space.float_w(w_y)
    resx, resy = call_c_func(c_rect, space, x, y)
    return space.newcomplex(resx, resy)
wrapped_rect.func_doc = names_and_docstrings['rect']


def c_phase(x, y):
    return rcomplex.c_phase(x,y)

def wrapped_phase(space, w_z):
    x, y = space.unpackcomplex(w_z)
    result = call_c_func(c_phase, space, x, y)
    return space.newfloat(result)
wrapped_phase.func_doc = names_and_docstrings['phase']


def c_abs(x, y):
    return rcomplex.c_abs(x,y)

def c_polar(x, y):
    return rcomplex.c_polar(x,y)

def wrapped_polar(space, w_z):
    x, y = space.unpackcomplex(w_z)
    resx, resy = call_c_func(c_polar, space, x, y)
    return space.newtuple([space.newfloat(resx), space.newfloat(resy)])
wrapped_polar.func_doc = names_and_docstrings['polar']


def c_isinf(x, y):
    return rcomplex.c_isinf(x,y)

def wrapped_isinf(space, w_z):
    x, y = space.unpackcomplex(w_z)
    res = c_isinf(x, y)
    return space.newbool(res)
wrapped_isinf.func_doc = names_and_docstrings['isinf']


def c_isnan(x, y):
    return rcomplex.c_isnan(x,y)

def wrapped_isnan(space, w_z):
    x, y = space.unpackcomplex(w_z)
    res = c_isnan(x, y)
    return space.newbool(res)
wrapped_isnan.func_doc = names_and_docstrings['isnan']

def c_isfinite(x, y):
    return rcomplex.c_isfinite(x, y)

def wrapped_isfinite(space, w_z):
    x, y = space.unpackcomplex(w_z)
    res = c_isfinite(x, y)
    return space.newbool(res)
wrapped_isfinite.func_doc = names_and_docstrings['isfinite']


@unwrap_spec(rel_tol=float, abs_tol=float)
def isclose(space, w_a, w_b, __kwonly__, rel_tol=1e-09, abs_tol=0.0):
    """isclose(a, b, *, rel_tol=1e-09, abs_tol=0.0) -> bool

Determine whether two complex numbers are close in value.

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
    ax, ay = space.unpackcomplex(w_a)
    bx, by = space.unpackcomplex(w_b)
    #
    # sanity check on the inputs
    if rel_tol < 0.0 or abs_tol < 0.0:
        raise oefmt(space.w_ValueError, "tolerances must be non-negative")
    #
    # short circuit exact equality -- needed to catch two infinities of
    # the same sign. And perhaps speeds things up a bit sometimes.
    if ax == bx and ay == by:
        return space.w_True
    #
    # This catches the case of two infinities of opposite sign, or
    # one infinity and one finite number. Two infinities of opposite
    # sign would otherwise have an infinite relative tolerance.
    # Two infinities of the same sign are caught by the equality check
    # above.
    if (math.isinf(ax) or math.isinf(ay) or
        math.isinf(bx) or math.isinf(by)):
        return space.w_False
    #
    # now do the regular computation
    # this is essentially the "weak" test from the Boost library
    diff = c_abs(bx - ax, by - ay)
    result = ((diff <= rel_tol * c_abs(bx, by) or
               diff <= rel_tol * c_abs(ax, ay)) or
              diff <= abs_tol)
    return space.newbool(result)
