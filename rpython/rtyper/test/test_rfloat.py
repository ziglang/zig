import math
import sys
from rpython.translator.translator import TranslationContext
from rpython.rtyper.test import snippet
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rlib.rarithmetic import (
    r_uint, r_longlong, r_ulonglong, r_singlefloat)
from rpython.rlib.objectmodel import compute_hash

class TestSnippet(object):

    def _test(self, func, types):
        t = TranslationContext()
        t.buildannotator().build_types(func, types)
        t.buildrtyper().specialize()
        t.checkgraphs()

    def test_not1(self):
        self._test(snippet.not1, [float])

    def test_not2(self):
        self._test(snippet.not2, [float])

    def test_float1(self):
        self._test(snippet.float1, [float])

    def test_float_cast1(self):
        self._test(snippet.float_cast1, [float])


class TestRfloat(BaseRtypingTest):

    inf = 'inf'
    minus_inf = '-inf'
    nan = 'nan'

    def test_float2str(self):
        def fn(f):
            return str(f)

        res = self.interpret(fn, [1.5])
        assert float(self.ll_to_string(res)) == 1.5
        res = self.interpret(fn, [-1.5])
        assert float(self.ll_to_string(res)) == -1.5
        inf = 1e200 * 1e200
        nan = inf/inf
        res = self.interpret(fn, [inf])
        assert self.ll_to_string(res) == self.inf
        res = self.interpret(fn, [-inf])
        assert self.ll_to_string(res) == self.minus_inf
        res = self.interpret(fn, [nan])
        assert self.ll_to_string(res) == self.nan

    def test_string_mod_float(self):
        def fn(f):
            return '%f' % f

        res = self.interpret(fn, [1.5])
        assert float(self.ll_to_string(res)) == 1.5

    def test_int_conversion(self):
        def fn(f):
            return int(f)

        res = self.interpret(fn, [1.0])
        assert res == 1
        assert type(res) is int
        res = self.interpret(fn, [2.34])
        assert res == fn(2.34)

    def test_longlong_conversion(self):
        def fn(f):
            return r_longlong(f)

        res = self.interpret(fn, [1.0])
        assert res == 1
        # r_longlong is int on a 64 bit system
        if sys.maxint == 2**63 - 1:
            assert self.is_of_type(res, int)
        else:
            assert self.is_of_type(res, r_longlong)
        res = self.interpret(fn, [2.34])
        assert res == fn(2.34)
        big = float(0x7fffffffffffffff)
        x = big - 1.e10
        assert x != big
        assert fn(x) == 9223372026854775808

    def test_to_r_uint(self):
        def fn(x):
            return r_uint(x)

        res = self.interpret(fn, [12.34])
        assert res == 12
        bigval = sys.maxint * 1.234
        res = self.interpret(fn, [bigval])
        assert long(res) == long(bigval)

    def test_from_r_uint(self):
        def fn(n):
            return float(r_uint(n)) / 2

        res = self.interpret(fn, [41])
        assert self.float_eq(res, 20.5)
        res = self.interpret(fn, [-9])
        assert self.float_eq(res, 0.5 * ((sys.maxint+1)*2 - 9))

    def test_to_r_ulonglong(self):
        def fn(x):
            return r_ulonglong(x)
        res = self.interpret(fn, [12.34])
        assert res == 12
        bigval = sys.maxint * 1.234
        res = self.interpret(fn, [bigval])
        assert long(res) == long(bigval)

    def test_from_r_ulonglong(self):
        def fn(n):
            return float(r_ulonglong(n)) / 2
        res = self.interpret(fn, [41])
        assert self.float_eq(res, 20.5)

    def test_r_singlefloat(self):
        def fn(x):
            y = r_singlefloat(x)
            return float(y)

        res = self.interpret(fn, [2.1])
        assert res != 2.1     # precision lost
        assert abs(res - 2.1) < 1E-6

    def test_float_constant_conversions(self):
        DIV = r_longlong(10 ** 10)
        def fn():
            return 420000000000.0 / DIV

        res = self.interpret(fn, [])
        assert self.float_eq(res, 42.0)

    def test_exceptions(self):
        def fn(x, y, z):
            try:
                # '/', when float-based, cannot raise in RPython!
                # the try:finally: only tests an annotation bug.
                x /= (y / z)
            finally:
                return x
        self.interpret(fn, [1.0, 2.0, 3.0])

    def test_copysign(self):
        def fn(x, y):
            return math.copysign(x, y)
        assert self.interpret(fn, [42, -1]) == -42
        assert self.interpret(fn, [42, -0.0]) == -42
        assert self.interpret(fn, [42, 0.0]) == 42

    def test_rstring_to_float(self):
        from rpython.rlib.rfloat import rstring_to_float
        def fn(i):
            s = ['42.3', '123.4'][i]
            return rstring_to_float(s)
        assert self.interpret(fn, [0]) == 42.3

    def test_isnan(self):
        def fn(x, y):
            n1 = x * x
            n2 = y * y * y
            return math.isnan(n1 / n2)
        assert self.interpret(fn, [1e200, 1e200])   # nan
        assert not self.interpret(fn, [1e200, 1.0])   # +inf
        assert not self.interpret(fn, [1e200, -1.0])  # -inf
        assert not self.interpret(fn, [42.5, 2.3])    # +finite
        assert not self.interpret(fn, [42.5, -2.3])   # -finite

    def test_isinf(self):
        def fn(x, y):
            n1 = x * x
            n2 = y * y * y
            return math.isinf(n1 / n2)
        assert self.interpret(fn, [1e200, 1.0])       # +inf
        assert self.interpret(fn, [1e200, -1.0])      # -inf
        assert not self.interpret(fn, [1e200, 1e200]) # nan
        assert not self.interpret(fn, [42.5, 2.3])    # +finite
        assert not self.interpret(fn, [42.5, -2.3])   # -finite

    def test_isfinite(self):
        from rpython.rlib import rfloat
        def fn(x, y):
            n1 = x * x
            n2 = y * y * y
            return rfloat.isfinite(n1 / n2)
        assert self.interpret(fn, [42.5, 2.3])        # +finite
        assert self.interpret(fn, [42.5, -2.3])       # -finite
        assert not self.interpret(fn, [1e200, 1.0])   # +inf
        assert not self.interpret(fn, [1e200, -1.0])  # -inf
        assert not self.interpret(fn, [1e200, 1e200]) # nan

    def test_formatd(self):
        from rpython.rlib.rfloat import formatd
        def f(x):
            return formatd(x, 'f', 2, 0)
        res = self.ll_to_string(self.interpret(f, [10/3.0]))
        assert res == '3.33'

    def test_formatd_g(self):
        from rpython.rlib import rfloat
        for flags in [0, rfloat.DTSF_ADD_DOT_0]:
            def f(y):
                return rfloat.formatd(y, 'g', 2, flags)

            assert self.ll_to_string(self.interpret(f, [3.0])) == f(3.0)

    def test_formatd_repr(self):
        from rpython.rlib.rfloat import formatd
        def f(x):
            return formatd(x, 'r', 0, 0)
        res = self.ll_to_string(self.interpret(f, [1.1]))
        assert res == '1.1'

    def test_formatd_huge(self):
        from rpython.rlib.rfloat import formatd
        def f(x):
            return formatd(x, 'f', 1234, 0)
        res = self.ll_to_string(self.interpret(f, [1.0]))
        assert res == '1.' + 1234 * '0'

    def test_formatd_F(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rlib.rfloat import formatd

        def func(x):
            # Test the %F format, which is not supported by
            # the Microsoft's msvcrt library.
            return formatd(x, 'F', 4)

        f = compile(func, [float])
        assert f(10/3.0) == '3.3333'

    def test_string_to_float(self):
        from rpython.rlib.rfloat import rstring_to_float
        def func(x):
            if x == 0:
                s = '1e23'
            else:
                s = '-1e23'
            return rstring_to_float(s)

        assert self.interpret(func, [0]) == 1e23
        assert self.interpret(func, [1]) == -1e23

    def test_hash(self):
        def fn(f):
            return compute_hash(f)
        res = self.interpret(fn, [1.5])
        assert res == compute_hash(1.5)

    def test_float_constant_inf(self):
        from rpython.rlib.rfloat import INFINITY
        def fn():
            return INFINITY   # float('inf') is not supported by RPython so far
        res = self.interpret(fn, [])
        assert res == float('inf')
