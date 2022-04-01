import py, sys
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.rarithmetic import r_longlong, r_ulonglong, r_uint, intmask
from rpython.jit.metainterp.test.support import LLJitMixin

class WrongResult(Exception):
    pass

def compare(xll, highres, lores):
    xll = r_ulonglong(xll)
    if intmask(xll) != lores:
        raise WrongResult
    if intmask(xll >> 32) != highres:
        raise WrongResult


class LongLongTests:
    def setup_class(cls):
        if sys.maxint > 2147483647:
            py.test.skip("only for 32-bit platforms")

    def test_long_long_1(self):
        def g(n, m, o, p):
            # On 64-bit platforms, long longs == longs.  On 32-bit platforms,
            # this function should be either completely marked as residual
            # (with supports_longlong==False), or be compiled as a
            # sequence of residual calls (with long long arguments).
            n = r_longlong(n)
            m = r_longlong(m)
            return intmask((n*m + p) // o)
        def f(n, m, o, p):
            return g(n, m, o, p) // 3
        #
        res = self.interp_operations(f, [1000000000, 90, 91, -17171],
                                     supports_longlong=False)
        assert res == ((1000000000 * 90 - 17171) // 91) // 3
        #
        res = self.interp_operations(f, [1000000000, 90, 91, -17171],
                                     supports_longlong=True)
        assert res == ((1000000000 * 90 - 17171) // 91) // 3

    def test_simple_ops(self):
        def f(n1, n2, m1, m2):
            # n == -30000000000000, m == -20000000000
            n = (r_longlong(n1) << 32) | r_longlong(n2)
            m = (r_longlong(m1) << 32) | r_longlong(m2)
            compare(n, -6985, 346562560)
            compare(m, -5, 1474836480)
            if not n: raise WrongResult
            if not r_longlong(m2): raise WrongResult
            if n-n: raise WrongResult
            compare(-n, 6984, -346562560)
            compare(~n, 6984, -346562561)
            compare(n + m, -6990, 1821399040)
            compare(n - m, -6981, -1128273920)
            compare(n * (-3), 20954, -1039687680)
            compare((-4) * m, 18, -1604378624)
            return 1
        self.interp_operations(f, [-6985, 346562560, -5, 1474836480])

    def test_compare_ops(self):
        def f(n1, n2):
            # n == -30000000000000
            n = (r_longlong(n1) << 32) | r_longlong(n2)
            compare(n < n,  0, 0)
            compare(n <= n, 0, 1)
            compare(n == n, 0, 1)
            compare(n != n, 0, 0)
            compare(n >  n, 0, 0)
            compare(n >= n, 0, 1)
            o = n + 2000000000
            compare(o, -6985, -1948404736)
            compare(n <  o, 0, 1)     # low word differs
            compare(n <= o, 0, 1)
            compare(o <  n, 0, 0)
            compare(o <= n, 0, 0)
            compare(n >  o, 0, 0)
            compare(n >= o, 0, 0)
            compare(o >  n, 0, 1)
            compare(o >= n, 0, 1)
            compare(n == o, 0, 0)
            compare(n != o, 0, 1)
            p = -o
            compare(n <  p, 0, 1)     # high word differs
            compare(n <= p, 0, 1)
            compare(p <  n, 0, 0)
            compare(p <= n, 0, 0)
            compare(n >  p, 0, 0)
            compare(n >= p, 0, 0)
            compare(p >  n, 0, 1)
            compare(p >= n, 0, 1)
            compare(n == p, 0, 0)
            compare(n != p, 0, 1)
            return 1
        self.interp_operations(f, [-6985, 346562560])

    def test_binops(self):
        def f(n1, n2, m1, m2, ii):
            # n == -30000000000000, m == -20000000000, ii == 42
            n = (r_longlong(n1) << 32) | r_longlong(n2)
            m = (r_longlong(m1) << 32) | r_longlong(m2)
            compare(n & m, -6989, 346562560)
            compare(n | m, -1, 1474836480)
            compare(n ^ m, 6988, 1128273920)
            compare(n << 1, -13970, 693125120)
            compare(r_longlong(5) << ii, 5120, 0)
            compare(n >> 1, -3493, -1974202368)
            compare(n >> 42, -1, -7)
            return 1
        self.interp_operations(f, [-6985, 346562560, -5, 1474836480, 42])

    def test_floats(self):
        def f(i):
            # i == 1000000000
            f = i * 123.5
            n = r_longlong(f)
            compare(n, 28, -1054051584)
            return float(n)
        res = self.interp_operations(f, [1000000000])
        assert res == 123500000000.0

    def test_floats_negative(self):
        def f(i):
            # i == 1000000000
            f = i * -123.5
            n = r_longlong(f)
            compare(n, -29, 1054051584)
            return float(n)
        res = self.interp_operations(f, [1000000000])
        assert res == -123500000000.0

    def test_floats_ulonglong(self):
        def f(i):
            # i == 1000000000
            f = i * 12350000000.0
            n = r_ulonglong(f)
            compare(n, -1419508847, 538116096)
            return float(n)
        res = self.interp_operations(f, [1000000000])
        assert res == 12350000000000000000.0

    def test_float_to_longlong(self):
        from rpython.rtyper.lltypesystem import lltype, rffi
        def f(x):
            compare(r_longlong(x), 0x12, 0x34567800)
            compare(rffi.cast(lltype.SignedLongLong, x), 0x12, 0x34567800)
            return 1
        res = self.interp_operations(f, [0x12345678 * 256.0])
        assert res == 1

    def test_unsigned_compare_ops(self):
        def f(n1, n2):
            # n == 30002000000000
            n = (r_ulonglong(n1) << 32) | r_ulonglong(n2)
            compare(n, 6985, 1653437440)
            compare(n < n,  0, 0)
            compare(n <= n, 0, 1)
            compare(n == n, 0, 1)
            compare(n != n, 0, 0)
            compare(n >  n, 0, 0)
            compare(n >= n, 0, 1)
            o = (r_ulonglong(n1) << 32) | r_ulonglong(r_uint(n2) + 1000000000)
            compare(o, 6985, -1641529856)
            compare(n <  o, 0, 1)     # low word differs
            compare(n <= o, 0, 1)
            compare(o <  n, 0, 0)
            compare(o <= n, 0, 0)
            compare(n >  o, 0, 0)
            compare(n >= o, 0, 0)
            compare(o >  n, 0, 1)
            compare(o >= n, 0, 1)
            compare(n == o, 0, 0)
            compare(n != o, 0, 1)
            p = ~n
            compare(n <  p, 0, 1)     # high word differs
            compare(n <= p, 0, 1)
            compare(p <  n, 0, 0)
            compare(p <= n, 0, 0)
            compare(n >  p, 0, 0)
            compare(n >= p, 0, 0)
            compare(p >  n, 0, 1)
            compare(p >= n, 0, 1)
            compare(n == p, 0, 0)
            compare(n != p, 0, 1)
            return 1
        f(6985, 1653437440)
        self.interp_operations(f, [6985, 1653437440])

    def test_unsigned_binops(self):
        def f(n1, n2, ii):
            # n == 30002000000000, ii == 42
            n = (r_ulonglong(n1) << 32) | r_ulonglong(n2)
            compare(n << 1, 13970, -988092416)
            compare(r_ulonglong(5) << ii, 5120, 0)
            compare(n >> 1, 3492, -1320764928)
            compare(n >> 42, 0, 6)
            p = ~n
            compare(p >> 1, 2147480155, 1320764927)
            compare(p >> 42, 0, 4194297)
            return 1
        self.interp_operations(f, [6985, 1653437440, 42])

    def test_long_long_field(self):
        from rpython.rlib.rarithmetic import r_longlong, intmask
        class A:
            pass
        def g(a, n, m):
            a.n = r_longlong(n)
            a.m = r_longlong(m)
            a.n -= a.m
            return intmask(a.n)
        def f(n, m):
            return g(A(), n, m)
        #
        res = self.interp_operations(f, [2147483647, -21474],
                                     supports_longlong=False)
        assert res == intmask(2147483647 + 21474)
        #
        res = self.interp_operations(f, [2147483647, -21474],
                                     supports_longlong=True)
        assert res == intmask(2147483647 + 21474)

    def test_truncate(self):
        def f(n):
            m = r_longlong(n) << 20
            return r_uint(m)
        res = self.interp_operations(f, [0x01234567])
        assert res == 0x56700000
        res = self.interp_operations(f, [0x56789ABC])
        assert intmask(res) == intmask(0xABC00000)

    def test_cast_longlong_to_bool(self):
        def f(n):
            m = r_longlong(n) << 20
            return lltype.cast_primitive(lltype.Bool, m)
        res = self.interp_operations(f, [2**12])
        assert res == 1

    def test_cast_ulonglong_to_bool(self):
        def f(n):
            m = r_ulonglong(n) << 20
            return lltype.cast_primitive(lltype.Bool, m)
        res = self.interp_operations(f, [2**12])
        assert res == 1


class TestLLtype(LongLongTests, LLJitMixin):
    pass
