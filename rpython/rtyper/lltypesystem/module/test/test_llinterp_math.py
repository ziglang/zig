"""Just another bunch of tests for llmath, run on top of llinterp."""

from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem.module import ll_math
import math
from rpython.rlib import rfloat


class TestMath(BaseRtypingTest):
    def new_unary_test(name):
        try:
            fn = getattr(math, name)
            assert_exact = True
        except AttributeError:
            fn = getattr(rfloat, name)
            assert_exact = False
        if name == 'acosh':
            value = 1.3     # acosh(x) is only defined for x >= 1.0
        else:
            value = 0.3
        #
        def next_test(self):
            def f(x):
                return fn(x)
            res = self.interpret(f, [value])
            if assert_exact:
                assert res == f(value)
            else:
                assert abs(res - f(value)) < 1e-10
        return next_test

    def new_binary_test(name):
        def next_test(self):
            def f(x, y):
                return getattr(math, name)(x, y)
            assert self.interpret(f, [0.3, 0.4]) == f(0.3, 0.4)
        return next_test

    for name in ll_math.unary_math_functions + ['log', 'log10', 'log1p', 'sin', 'cos', 'sqrt']:
        func_name = 'test_%s' % (name,)
        next_test = new_unary_test(name)
        next_test.__name__ = func_name
        locals()[func_name] = next_test
        del next_test

    for name in ['atan2', 'fmod', 'hypot', 'pow']:
        func_name = 'test_%s' % (name,)
        next_test = new_binary_test(name)
        next_test.__name__ = func_name
        locals()[func_name] = next_test
        del next_test

    def test_ldexp(self):
        def f(x, y):
            return math.ldexp(x, y)

        assert self.interpret(f, [3.4, 2]) == f(3.4, 2)
        # underflows give 0.0 with no exception raised
        assert f(1.0, -10000) == 0.0     # sanity-check the host Python
        assert self.interpret(f, [1.0, -10000]) == 0.0

    def test_overflow_1(self):
        # this (probably, depending on platform) tests the case
        # where the C function pow() sets ERANGE.
        def f(x, y):
            try:
                return math.pow(x, y)
            except OverflowError:
                return -42.0

        assert self.interpret(f, [10.0, 40000.0]) == -42.0

    def test_overflow_2(self):
        # this (not on Linux but on Mac OS/X at least) tests the case
        # where the C function ldexp() does not set ERANGE, but
        # returns +infinity.
        def f(x, y):
            try:
                return math.ldexp(x, y)
            except OverflowError:
                return -42.0

        assert self.interpret(f, [10.0, 40000]) == -42.0

    def test_log1p_zero(self):
        def f(x):
            x = math.copysign(0.0, x)
            return math.copysign(1.0, rfloat.log1p(x))

        assert self.interpret(f, [3.0]) == 1.0
        assert self.interpret(f, [-2.0]) == -1.0
