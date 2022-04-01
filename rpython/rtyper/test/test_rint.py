import py
import sys, operator
from rpython.translator.translator import TranslationContext
from rpython.rtyper.test import snippet
from rpython.rlib.rarithmetic import r_int, r_uint, r_longlong, r_ulonglong
from rpython.rlib.rarithmetic import ovfcheck, r_int64, intmask, int_between
from rpython.rlib import objectmodel
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.flowspace.model import summary


class TestSnippet(object):

    def _test(self, func, types):
        t = TranslationContext()
        t.buildannotator().build_types(func, types)
        t.buildrtyper().specialize()
        t.checkgraphs()

    def test_not1(self):
        self._test(snippet.not1, [int])

    def test_not2(self):
        self._test(snippet.not2, [int])

    def test_int1(self):
        self._test(snippet.int1, [int])

    def test_int_cast1(self):
        self._test(snippet.int_cast1, [int])


class TestRint(BaseRtypingTest):

    def test_char_constant(self):
        def dummyfn(i):
            return chr(i)
        res = self.interpret(dummyfn, [ord(' ')])
        assert res == ' '
        res = self.interpret(dummyfn, [0])
        assert res == '\0'
        res = self.interpret(dummyfn, [ord('a')])
        assert res == 'a'

    def test_str_of_int(self):
        def dummy(i):
            return str(i)

        res = self.interpret(dummy, [0])
        assert self.ll_to_string(res) == '0'

        res = self.interpret(dummy, [1034])
        assert self.ll_to_string(res) == '1034'

        res = self.interpret(dummy, [-123])
        assert self.ll_to_string(res) == '-123'

        res = self.interpret(dummy, [-sys.maxint-1])
        assert self.ll_to_string(res) == str(-sys.maxint-1)

    def test_hex_of_int(self):
        def dummy(i):
            return hex(i)

        res = self.interpret(dummy, [0])
        assert self.ll_to_string(res) == '0x0'

        res = self.interpret(dummy, [1034])
        assert self.ll_to_string(res) == '0x40a'

        res = self.interpret(dummy, [-123])
        assert self.ll_to_string(res) == '-0x7b'

        res = self.interpret(dummy, [-sys.maxint-1])
        res = self.ll_to_string(res)
        assert res == '-0x8' + '0' * (len(res)-4)

    def test_hex_of_uint(self):
        def dummy(i):
            return hex(r_uint(i))

        res = self.interpret(dummy, [-5])
        res = self.ll_to_string(res)
        assert res == '0x' + 'f' * (len(res)-3) + 'b'

    def test_oct_of_int(self):
        def dummy(i):
            return oct(i)

        res = self.interpret(dummy, [0])
        assert self.ll_to_string(res) == '0'

        res = self.interpret(dummy, [1034])
        assert self.ll_to_string(res) == '02012'

        res = self.interpret(dummy, [-123])
        assert self.ll_to_string(res) == '-0173'

        res = self.interpret(dummy, [-sys.maxint-1])
        res = self.ll_to_string(res)
        assert res == '-' + oct(sys.maxint+1).replace('L', '').replace('l', '')

    def test_str_of_longlong(self):
        def f(i):
            return str(i)

        res = self.interpret(f, [r_int64(0)])
        assert self.ll_to_string(res) == '0'

        res = self.interpret(f, [r_int64(413974738222117)])
        assert self.ll_to_string(res) == '413974738222117'

    def test_str_of_uint(self):
        def f(i):
            return str(i)

        res = self.interpret(f, [r_uint(0)])
        assert self.ll_to_string(res) == '0'

        res = self.interpret(f, [r_uint(sys.maxint)])
        assert self.ll_to_string(res) == str(sys.maxint)

        res = self.interpret(f, [r_uint(sys.maxint+1)])
        assert self.ll_to_string(res) == str(sys.maxint+1)

        res = self.interpret(f, [r_uint(-1)])
        assert self.ll_to_string(res) == str(2*sys.maxint+1)

    def test_unsigned(self):
        bigvalue = r_uint(sys.maxint + 17)
        def dummy(i):
            i = r_uint(i)
            j = bigvalue
            return i < j

        res = self.interpret(dummy,[0])
        assert res is True

        res = self.interpret(dummy, [-1])
        assert res is False    # -1 ==> 0xffffffff

    def test_specializing_int_functions(self):
        def f(i):
            return i + 1
        f._annspecialcase_ = "specialize:argtype(0)"
        def g(n):
            if n > 0:
                return f(r_int64(0))
            else:
                return f(0)
        res = self.interpret(g, [0])
        assert res == 1

        res = self.interpret(g, [1])
        assert res == 1

    def test_downcast_int(self):
        def f(i):
            return int(i)
        res = self.interpret(f, [r_int64(0)])
        assert res == 0

    def test_isinstance_vs_int_types(self):
        class FakeSpace(object):
            def wrap(self, x):
                if x is None:
                    return [None]
                if isinstance(x, str):
                    return x
                if isinstance(x, r_int64):
                    return int(x)
                return "XXX"
            wrap._annspecialcase_ = 'specialize:argtype(0)'

        space = FakeSpace()
        def wrap(x):
            return space.wrap(x)
        res = self.interpret(wrap, [r_int64(0)])
        assert res == 0

    def test_truediv(self):
        def f(n, m):
            return operator.truediv(n, m)
        res = self.interpret(f, [20, 4])
        assert type(res) is float
        assert res == 5.0

    def test_float_conversion(self):
        def f(ii):
            return float(ii)
        res = self.interpret(f, [r_int64(100000000)])
        assert type(res) is float
        assert res == 100000000.
        res = self.interpret(f, [r_int64(1234567890123456789)])
        assert type(res) is float
        assert self.float_eq(res, 1.2345678901234568e+18)

    def test_float_conversion_implicit(self):
        def f(ii):
            return 1.0 + ii
        res = self.interpret(f, [r_int64(100000000)])
        assert type(res) is float
        assert res == 100000001.
        res = self.interpret(f, [r_int64(1234567890123456789)])
        assert type(res) is float
        assert self.float_eq(res, 1.2345678901234568e+18)

    def test_rarithmetic(self):
        inttypes = [int, r_uint, r_int64, r_ulonglong]
        for inttype in inttypes:
            c = inttype()
            def f():
                return c
            res = self.interpret(f, [])
            assert res == f()
            assert type(res) == inttype

        for inttype in inttypes:
            def f():
                return inttype(0)
            res = self.interpret(f, [])
            assert res == f()
            assert type(res) == inttype

        for inttype in inttypes:
            def f(x):
                return x
            res = self.interpret(f, [inttype(0)])
            assert res == f(inttype(0))
            assert type(res) == inttype

    def test_and_or(self):
        inttypes = [int, r_uint, r_int64, r_ulonglong]
        for inttype in inttypes:
            def f(a, b, c):
                return a&b|c
            res = self.interpret(f, [inttype(0x1234), inttype(0x00FF), inttype(0x5600)])
            assert res == f(0x1234, 0x00FF, 0x5600)

    def test_neg_abs_ovf(self):
        for op in (operator.neg, abs):
            def f(x):
                try:
                    return ovfcheck(op(x))
                except OverflowError:
                    return 0
            res = self.interpret(f, [-1])
            assert res == 1
            res = self.interpret(f, [int(-1<<(r_int.BITS-1))])
            assert res == 0

    def test_lshift_rshift(self):
        for name, f in [('_lshift', lambda x, y: x << y),
                        ('_rshift', lambda x, y: x >> y)]:
            for inttype in (int, r_uint, r_int64, r_ulonglong):
                res = self.interpret(f, [inttype(2147483647), 12])
                if inttype is int:
                    assert res == intmask(f(2147483647, 12))
                else:
                    assert res == inttype(f(2147483647, 12))
                #
                # check that '*_[lr]shift' take an inttype and an
                # int as arguments, without the need for a
                # 'cast_int_to_{uint,longlong,...}'
                _, _, graph = self.gengraph(f, [inttype, int])
                block = graph.startblock
                assert len(block.operations) == 1
                assert block.operations[0].opname.endswith(name)

    def test_cast_uint_to_longlong(self):
        if r_uint.BITS == r_longlong.BITS:
            py.test.skip("only on 32-bits")
        def f(x):
            return r_longlong(r_uint(x))
        res = self.interpret(f, [-42])
        assert res == (sys.maxint+1) * 2 - 42

    div_mod_iteration_count = 1000
    def test_div_mod(self):
        import random

        for inttype in (int, r_int64):

            def d(x, y):
                return x/y

            for i in range(self.div_mod_iteration_count):
                x = inttype(random.randint(-100000, 100000))
                y = inttype(random.randint(-100000, 100000))
                if not y: continue
                if (i & 31) == 0:
                    x = (x//y) * y      # case where x is exactly divisible by y
                res = self.interpret(d, [x, y])
                assert res == d(x, y)

            def m(x, y):
                return x%y

            for i in range(self.div_mod_iteration_count):
                x = inttype(random.randint(-100000, 100000))
                y = inttype(random.randint(-100000, 100000))
                if not y: continue
                if (i & 31) == 0:
                    x = (x//y) * y      # case where x is exactly divisible by y
                res = self.interpret(m, [x, y])
                assert res == m(x, y)

    def test_protected_div_mod(self):
        def div_unpro(x, y):
            return x//y
        def div_ovf(x, y):
            try:
                return ovfcheck(x//y)
            except OverflowError:
                return 42
        def div_zer(x, y):
            try:
                return x//y
            except ZeroDivisionError:
                return 84
        def div_ovf_zer(x, y):
            try:
                return ovfcheck(x//y)
            except OverflowError:
                return 42
            except ZeroDivisionError:
                return 84

        def mod_unpro(x, y):
            return x%y
        def mod_ovf(x, y):
            try:
                return ovfcheck(x%y)
            except OverflowError:
                return 42
        def mod_zer(x, y):
            try:
                return x%y
            except ZeroDivisionError:
                return 84
        def mod_ovf_zer(x, y):
            try:
                return ovfcheck(x%y)
            except OverflowError:
                return 42
            except ZeroDivisionError:
                return 84

        for inttype in (int, r_int64):

            args = [( 5, 2), (-5, 2), ( 5,-2), (-5,-2),
                    ( 6, 2), (-6, 2), ( 6,-2), (-6,-2),
                    (-sys.maxint, -1), (4, 0)]

            funcs = [div_unpro, div_ovf, div_zer, div_ovf_zer,
                     mod_unpro, mod_ovf, mod_zer, mod_ovf_zer]

            for func in funcs:
                print func
                if 'ovf' in func.__name__ and inttype is r_longlong:
                    continue # don't have many llong_*_ovf operations...
                for x, y in args:
                    x, y = inttype(x), inttype(y)
                    try:
                        res1 = func(x, y)
                        if isinstance(res1, int):
                            res1 = ovfcheck(res1)
                    except (OverflowError, ZeroDivisionError):
                        continue
                    res2 = self.interpret(func, [x, y])
                    assert res1 == res2

    def test_int_add_nonneg_ovf(self):
        def f(x):
            try:
                a = ovfcheck(x + 50)
            except OverflowError:
                return 0
            try:
                a += ovfcheck(100 + x)
            except OverflowError:
                return 1
            return a
        t, rtyper, graph = self.gengraph(f, [int])
        assert summary(graph).get('int_add_nonneg_ovf') == 2
        res = self.interpret(f, [-3])
        assert res == 144
        res = self.interpret(f, [sys.maxint-50])
        assert res == 1
        res = self.interpret(f, [sys.maxint])
        assert res == 0

    def test_int_py_div_nonnegargs(self):
        def f(x, y):
            assert x >= 0
            assert y >= 0
            return x // y
        res = self.interpret(f, [1234567, 123])
        assert res == 1234567 // 123

    def test_int_py_mod_nonnegargs(self):
        def f(x, y):
            assert x >= 0
            assert y >= 0
            return x % y
        res = self.interpret(f, [1234567, 123])
        assert res == 1234567 % 123

    def test_cast_to_float_exc_check(self):
        def f(x):
            try:
                return float(x)
            except ValueError:
                return 3.0

        res = self.interpret(f, [3])
        assert res == 3

    def test_hash(self):
        def f(x):
            return objectmodel.compute_hash(x)
        res = self.interpret(f, [123456789])
        assert res == 123456789
        res = self.interpret(f, [r_int64(123456789012345678)])
        if sys.maxint == 2147483647:
            # check the way we compute such a hash so far
            assert res == -1506741426 + 9 * 28744523
        else:
            assert res == 123456789012345678

    def test_int_between(self):
        def fn(a, b, c):
            return int_between(a, b, c)
        assert self.interpret(fn, [1, 1, 3])
        assert self.interpret(fn, [1, 2, 3])
        assert not self.interpret(fn, [1, 0, 2])
        assert not self.interpret(fn, [1, 5, 2])
        assert not self.interpret(fn, [1, 2, 2])
        assert not self.interpret(fn, [1, 1, 1])
