from __future__ import with_statement
from pypy.module.cmath import interp_cmath
import os, sys, math


def test_special_values():
    from rpython.rlib.special_value import sqrt_special_values
    assert len(sqrt_special_values) == 7
    assert len(sqrt_special_values[4]) == 7
    assert isinstance(sqrt_special_values[5][1], tuple)
    assert sqrt_special_values[5][1][0] == 1e200 * 1e200
    assert sqrt_special_values[5][1][1] == -0.
    assert math.copysign(1., sqrt_special_values[5][1][1]) == -1.


class AppTestCMath:
    spaceconfig = dict(usemodules=['cmath'])

    def test_sign(self):
        import math
        z = eval("-0j")
        assert z == -0j
        assert math.copysign(1., z.real) == -1.0
        assert math.copysign(1., z.imag) == -1.0

    def test_sqrt(self):
        import cmath, math
        assert cmath.sqrt(3+4j) == 2+1j
        z = cmath.sqrt(-0j)
        assert math.copysign(1., z.real) == 1.
        assert math.copysign(1., z.imag) == -1.
        dbl_min = 2.2250738585072014e-308
        z = cmath.sqrt((dbl_min * 0.00000000000001) + 0j)
        assert abs(z.real - 1.49107189843e-161) < 1e-170
        assert z.imag == 0.0
        z = cmath.sqrt(1e200*1e200 - 10j)
        assert math.isinf(z.real) and z.real > 0.0
        assert z.imag == 0.0 and math.copysign(1., z.imag) == -1.

    def test_log(self):
        import cmath, math
        z = cmath.log(100j, 10j)
        assert abs(z - (1.6824165174565446-0.46553647994440367j)) < 1e-10

    def test_pi_e(self):
        import cmath, math
        assert cmath.pi == math.pi
        assert cmath.e == math.e

    def test_rect(self):
        import cmath
        z = cmath.rect(2.0, cmath.pi/2)
        assert abs(z - 2j) < 1e-10

    def test_polar(self):
        import cmath
        r, phi = cmath.polar(2j)
        assert r == 2
        assert abs(phi - cmath.pi/2) < 1e-10

    def test_phase(self):
        import cmath
        phi = cmath.phase(2j)
        assert abs(phi - cmath.pi/2) < 1e-10

    def test_valueerror(self):
        import cmath
        raises(ValueError, cmath.log, 0j)

    def test_stringarg(self):
        import cmath
        raises(TypeError, cmath.log, "-3j")

    def test_isinf(self):
        import cmath
        assert not cmath.isinf(2+3j)
        assert cmath.isinf(float("inf"))
        assert cmath.isinf(-float("inf"))
        assert cmath.isinf(complex("infj"))
        assert cmath.isinf(complex("2-infj"))
        assert cmath.isinf(complex("inf+nanj"))
        assert cmath.isinf(complex("nan+infj"))

    def test_isnan(self):
        import cmath
        assert not cmath.isnan(2+3j)
        assert cmath.isnan(float("nan"))
        assert cmath.isnan(complex("nanj"))
        assert cmath.isnan(complex("inf+nanj"))
        assert cmath.isnan(complex("nan+infj"))

    def test_isfinite(self):
        import cmath
        import math

        real_vals = [
            float('-inf'), -2.3, -0.0, 0.0, 2.3, float('inf'), float('nan')
        ]
        for x in real_vals:
            for y in real_vals:
                z = complex(x, y)
                assert cmath.isfinite(z) == (math.isfinite(x) and math.isfinite(y))

    def test_user_defined_complex(self):
        import cmath
        class Foo(object):
            def __complex__(self):
                return 2j
        r, phi = cmath.polar(Foo())
        assert r == 2
        assert abs(phi - cmath.pi/2) < 1e-10

    def test_user_defined_float(self):
        import cmath
        class Foo(object):
            def __float__(self):
                return 2.0
        assert cmath.polar(Foo()) == (2, 0)

    def test_isclose(self):
        import cmath
        raises(ValueError, cmath.isclose, 2, 3, rel_tol=-0.5)
        raises(ValueError, cmath.isclose, 2, 3, abs_tol=-0.5)
        for z in [0.0, 1.0, 1j,
                  complex("inf"), complex("infj"),
                  complex("-inf"), complex("-infj")]:
            assert cmath.isclose(z, z)
        assert not cmath.isclose(complex("infj"), complex("-infj"))
        assert cmath.isclose(1j, 1j+1e-12)
        assert not cmath.isclose(1j, 1j+1e-12, rel_tol=1e-13)
        assert not cmath.isclose(100000j, 100001j)
        assert cmath.isclose(100000j, 100001j, rel_tol=1e-4)
        assert cmath.isclose(100000j, 100001j, abs_tol=1.5)
        assert not cmath.isclose(100000j, 100001j, abs_tol=0.5)

    def test_infinity_and_nan_constants(self):
        import cmath, math
        assert cmath.inf.real == math.inf
        assert cmath.inf.imag == 0.0
        assert cmath.infj.real == 0.0
        assert cmath.infj.imag == math.inf

        assert math.isnan(cmath.nan.real)
        assert cmath.nan.imag == 0.0
        assert cmath.nanj.real == 0.0
        assert math.isnan(cmath.nanj.imag)

        # Check consistency with reprs.
        assert repr(cmath.inf) == "inf"
        assert repr(cmath.infj) == "infj"
        assert repr(cmath.nan) == "nan"
        assert repr(cmath.nanj) == "nanj"


def parse_testfile(fname):
    """Parse a file with test values

    Empty lines or lines starting with -- are ignored
    yields id, fn, arg_real, arg_imag, exp_real, exp_imag
    """
    with open(fname) as fp:
        for line in fp:
            # skip comment lines and blank lines
            if line.startswith('--') or not line.strip():
                continue

            lhs, rhs = line.split('->')
            id, fn, arg_real, arg_imag = lhs.split()
            rhs_pieces = rhs.split()
            exp_real, exp_imag = rhs_pieces[0], rhs_pieces[1]
            flags = rhs_pieces[2:]

            yield (id, fn,
                   float(arg_real), float(arg_imag),
                   float(exp_real), float(exp_imag),
                   flags
                  )

def rAssertAlmostEqual(a, b, rel_err = 2e-15, abs_err = 5e-323, msg=''):
    """Fail if the two floating-point numbers are not almost equal.

    Determine whether floating-point values a and b are equal to within
    a (small) rounding error.  The default values for rel_err and
    abs_err are chosen to be suitable for platforms where a float is
    represented by an IEEE 754 double.  They allow an error of between
    9 and 19 ulps.
    """

    # special values testing
    if math.isnan(a):
        if math.isnan(b):
            return
        raise AssertionError(msg + '%r should be nan' % (b,))

    if math.isinf(a):
        if a == b:
            return
        raise AssertionError(msg + 'finite result where infinity expected: '
                                   'expected %r, got %r' % (a, b))

    # if both a and b are zero, check whether they have the same sign
    # (in theory there are examples where it would be legitimate for a
    # and b to have opposite signs; in practice these hardly ever
    # occur).
    if not a and not b:
        if math.copysign(1., a) != math.copysign(1., b):
            raise AssertionError(msg + 'zero has wrong sign: expected %r, '
                                       'got %r' % (a, b))

    # if a-b overflows, or b is infinite, return False.  Again, in
    # theory there are examples where a is within a few ulps of the
    # max representable float, and then b could legitimately be
    # infinite.  In practice these examples are rare.
    try:
        absolute_error = abs(b-a)
    except OverflowError:
        pass
    else:
        # test passes if either the absolute error or the relative
        # error is sufficiently small.  The defaults amount to an
        # error of between 9 ulps and 19 ulps on an IEEE-754 compliant
        # machine.
        if absolute_error <= max(abs_err, rel_err * abs(a)):
            return
    raise AssertionError(msg + '%r and %r are not sufficiently close' % (a, b))

def test_specific_values():
    #if not float.__getformat__("double").startswith("IEEE"):
    #    return

    import rpython
    # too fragile...
    fname = os.path.join(os.path.dirname(rpython.rlib.__file__), 'test', 'rcomplex_testcases.txt')
    for id, fn, ar, ai, er, ei, flags in parse_testfile(fname):
        arg = (ar, ai)
        expected = (er, ei)
        function = getattr(interp_cmath, 'c_' + fn)
        #
        if 'divide-by-zero' in flags or 'invalid' in flags:
            try:
                actual = function(*arg)
            except ValueError:
                continue
            else:
                raise AssertionError('ValueError not raised in test '
                                     '%s: %s(complex(%r, %r))' % (id, fn,
                                                                  ar, ai))
        if 'overflow' in flags:
            try:
                actual = function(*arg)
            except OverflowError:
                continue
            else:
                raise AssertionError('OverflowError not raised in test '
                                     '%s: %s(complex(%r, %r))' % (id, fn,
                                                                  ar, ai))
        actual = function(*arg)

        if 'ignore-real-sign' in flags:
            actual = (abs(actual[0]), actual[1])
            expected = (abs(expected[0]), expected[1])
        if 'ignore-imag-sign' in flags:
            actual = (actual[0], abs(actual[1]))
            expected = (expected[0], abs(expected[1]))

        # for the real part of the log function, we allow an
        # absolute error of up to 2e-15.
        if fn in ('log', 'log10'):
            real_abs_err = 2e-15
        else:
            real_abs_err = 5e-323

        error_message = (
            '%s: %s(complex(%r, %r))\n'
            'Expected: complex(%r, %r)\n'
            'Received: complex(%r, %r)\n'
            ) % (id, fn, ar, ai,
                 expected[0], expected[1],
                 actual[0], actual[1])

        rAssertAlmostEqual(expected[0], actual[0],
                           abs_err=real_abs_err,
                           msg=error_message)
        rAssertAlmostEqual(expected[1], actual[1],
                           msg=error_message)
