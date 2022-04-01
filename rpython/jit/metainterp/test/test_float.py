import math, sys
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.rarithmetic import intmask, r_uint


class FloatTests:

    def test_simple(self):
        def f(a, b, c, d, e):
            return (((a + b) - c) * d) / e
        res = self.interp_operations(f, [41.5, 2.25, 17.5, 3.0, 2.5])
        assert res == 31.5

    def test_cast_bool_to_float(self):
        def f(a):
            return float(a == 12.0)
        res = self.interp_operations(f, [41.5])
        assert res == 0.0
        res = self.interp_operations(f, [12.0])
        assert res == 1.0

    def test_abs(self):
        def f(a):
            return abs(a)
        res = self.interp_operations(f, [-5.25])
        assert res == 5.25
        x = 281474976710656.31
        res = self.interp_operations(f, [x])
        assert res == x

    def test_neg(self):
        def f(a):
            return -a
        res = self.interp_operations(f, [-5.25])
        assert res == 5.25
        x = 281474976710656.31
        res = self.interp_operations(f, [x])
        assert res == -x

    def test_singlefloat(self):
        from rpython.rlib.rarithmetic import r_singlefloat
        def f(a):
            a = float(r_singlefloat(a))
            a *= 4.25
            return float(r_singlefloat(a))
        res = self.interp_operations(f, [-2.0], supports_singlefloats=True)
        assert res == -8.5

    def test_cast_float_to_int(self):
        def g(f):
            return int(f)
        res = self.interp_operations(g, [-12345.9])
        assert res == -12345

    def test_cast_float_to_uint(self):
        def g(f):
            return intmask(r_uint(f))
        res = self.interp_operations(g, [sys.maxint*2.0])
        assert res == intmask(long(sys.maxint*2.0))
        res = self.interp_operations(g, [-12345.9])
        assert res == -12345

    def test_cast_int_to_float(self):
        def g(i):
            return float(i)
        res = self.interp_operations(g, [-12345])
        assert type(res) is float and res == -12345.0

    def test_cast_int_to_float_constant(self):
        def h(i):
            if i < 10:
                i = 10
            return i
        def g(i):
            return float(h(i))
        res = self.interp_operations(g, [-12345])
        assert type(res) is float and res == 10.0

    def test_cast_uint_to_float(self):
        def g(i):
            return float(r_uint(i))
        res = self.interp_operations(g, [intmask(sys.maxint*2)])
        assert type(res) is float and res == float(sys.maxint*2)
        res = self.interp_operations(g, [-12345])
        assert type(res) is float and res == float(long(r_uint(-12345)))


class TestLLtype(FloatTests, LLJitMixin):
    pass
