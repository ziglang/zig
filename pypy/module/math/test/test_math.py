import py
import sys
from pypy.interpreter.function import Function
from pypy.interpreter.gateway import BuiltinCode
from pypy.module.math.test import test_direct
from rpython.rlib.rfloat import INFINITY, NAN

class AppTestMath:
    spaceconfig = {
        "usemodules": ['math', 'struct', 'itertools', 'time', 'binascii'],
    }

    def setup_class(cls):
        from rpython.rtyper.lltypesystem.module.test import math_cases
        filename = math_cases.__file__
        if filename.endswith('.pyc'):
            filename = filename[:-1]
        space = cls.space
        cls.w_math_cases = space.wrap(filename)
        cls.w_maxint = space.wrap(sys.maxint)

    @classmethod
    def make_callable_wrapper(cls, func):
        def f(space, w_x):
            return space.wrap(func(space.unwrap(w_x)))
        return Function(cls.space, BuiltinCode(f))

    def w_ftest(self, actual, expected):
        assert abs(actual - expected) < 10E-5

    def w_cases(self):
        with open(self.math_cases) as f:
            mod = compile(f.read(), "math_cases.py", "exec")
        ns = {}
        eval(mod, ns)
        TESTCASES = ns['MathTests'].TESTCASES
        INFINITY = ns['INFINITY']
        NAN = ns['NAN']

        for fnname, args, expected in TESTCASES:
            # marked as OverflowError to match 2.x/ll_math in
            # test_direct, but this is a ValueError on 3.x
            if (fnname, args, expected) == ('log1p', (-1.0,), OverflowError):
                expected = ValueError
            # 3.x ceil/floor differ from 2.x
            if fnname in ('ceil', 'floor'):
                if args[0] in (INFINITY, -INFINITY):
                    expected = OverflowError
                elif args[0] is NAN:
                    expected = ValueError

            yield fnname, args, expected

    def test_all_cases(self):
        import math
        for fnname, args, expected in self.cases():
            fn = getattr(math, fnname)
            print(fn, args, expected)
            try:
                got = fn(*args)
            except ValueError:
                assert expected == ValueError
            except OverflowError:
                assert expected == OverflowError
            else:
                if type(expected) is type(Exception):
                    ok = False
                elif callable(expected):
                    ok = expected(got)
                else:
                    gotsign = expectedsign = 1
                    if got < 0.0: gotsign = -gotsign
                    if expected < 0.0: expectedsign = -expectedsign
                    ok = got == expected and gotsign == expectedsign
                if not ok:
                    raise AssertionError("%s(%s): got %s" % (
                        fnname, ', '.join(map(str, args)), got))

    def test_ldexp(self):
        import math
        assert math.ldexp(float("inf"), -10**20) == float("inf")

    def test_fsum(self):
        import math

        # detect evidence of double-rounding: fsum is not always correctly
        # rounded on machines that suffer from double rounding.
        # It is a known problem with IA32 floating-point arithmetic.
        # It should work fine e.g. with x86-64.
        x, y = 1e16, 2.9999 # use temporary values to defeat peephole optimizer
        HAVE_DOUBLE_ROUNDING = (x + y == 1e16 + 4)
        if HAVE_DOUBLE_ROUNDING:
            skip("fsum is not exact on machines with double rounding")

        test_values = [
            ([], 0.0),
            ([0.0], 0.0),
            ([1e100, 1.0, -1e100, 1e-100, 1e50, -1.0, -1e50], 1e-100),
            ([2.0**53, -0.5, -2.0**-54], 2.0**53-1.0),
            ([2.0**53, 1.0, 2.0**-100], 2.0**53+2.0),
            ([2.0**53+10.0, 1.0, 2.0**-100], 2.0**53+12.0),
            ([2.0**53-4.0, 0.5, 2.0**-54], 2.0**53-3.0),
            ([1./n for n in range(1, 1001)],
             float.fromhex('0x1.df11f45f4e61ap+2')),
            ([(-1.)**n/n for n in range(1, 1001)],
             float.fromhex('-0x1.62a2af1bd3624p-1')),
            ([1.7**(i+1)-1.7**i for i in range(1000)] + [-1.7**1000], -1.0),
            ([1e16, 1., 1e-16], 10000000000000002.0),
            ([1e16-2., 1.-2.**-53, -(1e16-2.), -(1.-2.**-53)], 0.0),
            # exercise code for resizing partials array
            ([2.**n - 2.**(n+50) + 2.**(n+52) for n in range(-1074, 972, 2)] +
             [-2.**1022],
             float.fromhex('0x1.5555555555555p+970')),
            # infinity and nans
            ([float("inf")], float("inf")),
            ([float("-inf")], float("-inf")),
            ([float("nan")], float("nan")),
            ]

        for i, (vals, expected) in enumerate(test_values):
            try:
                actual = math.fsum(vals)
            except OverflowError:
                py.test.fail("test %d failed: got OverflowError, expected %r "
                          "for math.fsum(%.100r)" % (i, expected, vals))
            except ValueError:
                py.test.fail("test %d failed: got ValueError, expected %r "
                          "for math.fsum(%.100r)" % (i, expected, vals))
            assert actual == expected or (
                math.isnan(actual) and math.isnan(expected))

    def test_factorial(self):
        import math, sys
        assert math.factorial(0) == 1
        assert math.factorial(1) == 1
        assert math.factorial(2) == 2
        assert math.factorial(5) == 120
        assert math.factorial(5.) == 120
        raises(ValueError, math.factorial, -1)
        raises(ValueError, math.factorial, -1.)
        raises(ValueError, math.factorial, 1.1)
        raises(OverflowError, math.factorial, sys.maxsize+1)
        raises(OverflowError, math.factorial, 10e100)

    def test_log1p(self):
        import math
        self.ftest(math.log1p(1/math.e-1), -1)
        self.ftest(math.log1p(0), 0)
        self.ftest(math.log1p(math.e-1), 1)
        self.ftest(math.log1p(1), math.log(2))
        raises(ValueError, math.log1p, -1)
        raises(ValueError, math.log1p, -100)

    def test_log2(self):
        import math
        self.ftest(math.log2(0.125), -3)
        self.ftest(math.log2(0.5), -1)
        self.ftest(math.log2(4), 2)

    def test_log10(self):
        import math
        self.ftest(math.log10(0.1), -1)
        self.ftest(math.log10(10), 1)
        self.ftest(math.log10(100), 2)
        self.ftest(math.log10(0.01), -2)

    def test_log_largevalue(self):
        import math
        assert math.log2(2**1234) == 1234.0

    def test_acosh(self):
        import math
        self.ftest(math.acosh(1), 0)
        self.ftest(math.acosh(2), 1.3169578969248168)
        assert math.isinf(math.asinh(float("inf")))
        raises(ValueError, math.acosh, 0)

    def test_asinh(self):
        import math
        self.ftest(math.asinh(0), 0)
        self.ftest(math.asinh(1), 0.88137358701954305)
        self.ftest(math.asinh(-1), -0.88137358701954305)
        assert math.isinf(math.asinh(float("inf")))

    def test_atanh(self):
        import math
        self.ftest(math.atanh(0), 0)
        self.ftest(math.atanh(0.5), 0.54930614433405489)
        self.ftest(math.atanh(-0.5), -0.54930614433405489)
        raises(ValueError, math.atanh, 1.)
        assert math.isnan(math.atanh(float("nan")))

    def test_trunc(self):
        import math
        assert math.trunc(1.9) == 1.0
        raises((AttributeError, TypeError), math.trunc, 1.9j)
        class foo(object):
            def __trunc__(self):
                return "truncated"
        assert math.trunc(foo()) == "truncated"

    def test_copysign_nan(self):
        skip('sign of nan is undefined')
        import math
        assert math.copysign(1.0, float('-nan')) == -1.0

    def test_special_methods(self):
        import math
        class Z:
            pass
        for i, name in enumerate(('ceil', 'floor', 'trunc')):
            setattr(Z, '__{}__'.format(name), lambda self: i)
            func = getattr(math, name)
            assert func(Z()) == i

    def test_int_results(self):
        import math
        for func in math.ceil, math.floor:
            assert type(func(0.5)) is int
            raises(OverflowError, func, float('inf'))
            raises(ValueError, func, float('nan'))

    def test_ceil(self):
        # adapted from the cpython test case
        import math
        raises(TypeError, math.ceil)
        assert type(math.ceil(0.4)) is int
        assert math.ceil(0.5) == 1
        assert math.ceil(1.0) == 1
        assert math.ceil(1.5) == 2
        assert math.ceil(-0.5) == 0
        assert math.ceil(-1.0) == -1
        assert math.ceil(-1.5) == -1

        class TestCeil:
            def __ceil__(self):
                return 42
        class TestNoCeil:
            pass
        assert math.ceil(TestCeil()) == 42
        raises(TypeError, math.ceil, TestNoCeil())

        t = TestNoCeil()
        t.__ceil__ = lambda *args: args
        raises(TypeError, math.ceil, t)
        raises(TypeError, math.ceil, t, 0)

        # observed in a cpython interactive shell
        raises(OverflowError, math.ceil, float("inf"))
        raises(OverflowError, math.ceil, float("-inf"))
        raises(ValueError, math.ceil, float("nan"))

        class StrangeCeil:
            def __ceil__(self):
                return "this is a string"

        assert math.ceil(StrangeCeil()) == "this is a string"

        class CustomFloat:
            def __float__(self):
                return 99.9

        assert math.ceil(CustomFloat()) == 100

    def test_floor(self):
        # adapted from the cpython test case
        import math
        raises(TypeError, math.floor)
        assert type(math.floor(0.4)) is int
        assert math.floor(0.5) == 0
        assert math.floor(1.0) == 1
        assert math.floor(1.5) == 1
        assert math.floor(-0.5) == -1
        assert math.floor(-1.0) == -1
        assert math.floor(-1.5) == -2
        assert math.floor(1.23e167) == int(1.23e167)
        assert math.floor(-1.23e167) == int(-1.23e167)

        class TestFloor:
            def __floor__(self):
                return 42
        class TestNoFloor:
            pass
        assert math.floor(TestFloor()) == 42
        raises(TypeError, math.floor, TestNoFloor())

        t = TestNoFloor()
        t.__floor__ = lambda *args: args
        raises(TypeError, math.floor, t)
        raises(TypeError, math.floor, t, 0)

        # observed in a cpython interactive shell
        raises(OverflowError, math.floor, float("inf"))
        raises(OverflowError, math.floor, float("-inf"))
        raises(ValueError, math.floor, float("nan"))

        class StrangeCeil:
            def __floor__(self):
                return "this is a string"

        assert math.floor(StrangeCeil()) == "this is a string"

        assert math.floor(1.23e167) - 1.23e167 == 0.0

        class CustomFloat:
            def __float__(self):
                return 99.9

        assert math.floor(CustomFloat()) == 99

    def test_erf(self):
        import math
        assert math.erf(100.0) == 1.0
        assert math.erf(-1000.0) == -1.0
        assert math.erf(float("inf")) == 1.0
        assert math.erf(float("-inf")) == -1.0
        assert math.isnan(math.erf(float("nan")))
        # proper tests are in rpython/rlib/test/test_rfloat
        assert round(math.erf(1.0), 9) == 0.842700793

    def test_erfc(self):
        import math
        assert math.erfc(0.0) == 1.0
        assert math.erfc(-0.0) == 1.0
        assert math.erfc(float("inf")) == 0.0
        assert math.erfc(float("-inf")) == 2.0
        assert math.isnan(math.erf(float("nan")))
        assert math.erfc(1e-308) == 1.0

    def test_gamma(self):
        import math
        assert raises(ValueError, math.gamma, 0.0)
        assert math.gamma(5.0) == 24.0
        assert math.gamma(6.0) == 120.0
        assert raises(ValueError, math.gamma, -1)
        assert math.gamma(0.5) == math.pi ** 0.5

    def test_lgamma(self):
        import math
        math.lgamma(1.0) == 0.0
        math.lgamma(2.0) == 0.0
        # proper tests are in rpython/rlib/test/test_rfloat
        assert round(math.lgamma(5.0), 9) == round(math.log(24.0), 9)
        assert round(math.lgamma(6.0), 9) == round(math.log(120.0), 9)
        assert raises(ValueError, math.gamma, -1)
        assert round(math.lgamma(0.5), 9) == round(math.log(math.pi ** 0.5), 9)

    def test_isclose(self):
        import math
        assert math.isclose(0, 1) is False
        assert math.isclose(0, 0.0) is True
        assert math.isclose(1000.1, 1000.2, abs_tol=0.2) is True
        assert math.isclose(1000.1, 1000.2, rel_tol=1e-3) is True
        assert math.isclose(1000.1, 1000.2, abs_tol=0.02) is False
        assert math.isclose(1000.1, 1000.2, rel_tol=1e-5) is False
        assert math.isclose(float("inf"), float("inf")) is True
        assert math.isclose(float("-inf"), float("-inf")) is True
        assert math.isclose(float("inf"), float("-inf")) is False
        assert math.isclose(float("-inf"), float("inf")) is False
        assert math.isclose(float("-inf"), 12.34) is False
        assert math.isclose(float("-inf"), float("nan")) is False
        assert math.isclose(float("nan"), 12.34) is False
        assert math.isclose(float("nan"), float("nan")) is False
        #
        raises(TypeError, math.isclose, 0, 1, rel_tol=None)
        raises(TypeError, math.isclose, 0, 1, abs_tol=None)

    def test_gcd(self):
        import math
        assert math.gcd(-4, -10) == 2
        assert math.gcd(0, -10) == 10
        assert math.gcd(0, 0) == 0
        raises(TypeError, math.gcd, 0, 0.0)
        raises(TypeError, math.gcd, 0.0)
        assert math.gcd(-3**10*5**20*11**8, 2**5*3**5*7**20) == 3**5
        assert math.gcd(64, 200) == 8

        assert math.gcd(-self.maxint-1, 3) == 1
        assert math.gcd(-self.maxint-1, -self.maxint-1) == self.maxint+1
        assert math.gcd() == 0
        assert math.gcd(2, 4, 6, 8) == 2
        assert math.gcd(36) == 36
        assert math.gcd(-36) == 36

    def test_lcm(self):
        import math
        assert math.lcm() == 1
        assert math.lcm(-5) == 5
        assert math.lcm(5) == 5
        assert math.lcm(6, 10) == 30
        assert math.lcm(6, 10, 14) == 210
        assert math.lcm(0, 0) == 0
        assert math.lcm(0, 1) == 0
        assert math.lcm(1, 0) == 0
        assert math.lcm(3, 5, 7, 0) == 0
        raises(TypeError, math.lcm, 12.0)

    def test_inf_nan(self):
        import math
        assert math.isinf(math.inf)
        assert math.inf > -math.inf
        assert math.isnan(math.nan)

    def test_pi_tau(self):
        import math
        assert math.tau == math.pi * 2.0

    def test_remainder(self):
        import math
        assert math.remainder(3, math.pi) == 3 - math.pi
        assert math.remainder(-3, math.pi) == math.pi - 3
        assert math.remainder(3, -math.pi) == 3 - math.pi
        assert math.remainder(4, math.pi) == 4 - math.pi
        assert math.remainder(6, math.pi) == 6 - 2 * math.pi
        assert math.remainder(3, math.inf) == 3
        assert math.remainder(3, -math.inf) == 3
        assert math.isnan(math.remainder(3, math.nan))
        assert math.isnan(math.remainder(math.nan, 3))
        raises(ValueError, math.remainder, 3, 0)
        raises(ValueError, math.remainder, math.inf, 3)
        raises(TypeError, math.remainder, "abc", 1)

    def test_isqrt(self):
        import math
        x = math.isqrt(9)
        assert x == 3
        assert type(x) is int

        test_values = list(range(10)) + [1 << 100 - 1]

        for value in test_values:
            s = math.isqrt(value)
            assert type(s) is int
            assert s*s <= value
            assert value < (s+1)*(s+1)

        with raises(ValueError):
            math.isqrt(-1)

