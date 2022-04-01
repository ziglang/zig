from __future__ import with_statement

import math
import sys, os
import py

from rpython.rlib.rstackovf import StackOverflow
from rpython.rlib.objectmodel import compute_hash, current_object_addr_as_int
from rpython.rlib.nonconst import NonConstant
from rpython.rlib.rarithmetic import r_uint, r_ulonglong, r_longlong, intmask, longlongmask
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.test import snippet
from rpython.translator.c.test.test_genc import compile


class TestTypedTestCase(object):
    def getcompiled(self, func, argtypes):
        return compile(func, argtypes, backendopt=False)

    def test_set_attr(self):
        set_attr = self.getcompiled(snippet.set_attr, [])
        assert set_attr() == 2

    def test_inheritance2(self):
        def wrap():
            res = snippet.inheritance2()
            return res == ((-12, -12.0), (3, 12.3))
        fn = self.getcompiled(wrap, [])
        assert fn()

    def test_factorial2(self):
        factorial2 = self.getcompiled(snippet.factorial2, [int])
        assert factorial2(5) == 120

    def test_factorial(self):
        factorial = self.getcompiled(snippet.factorial, [int])
        assert factorial(5) == 120

    def test_simple_method(self):
        simple_method = self.getcompiled(snippet.simple_method, [int])
        assert simple_method(55) == 55

    def test_sieve_of_eratosthenes(self):
        sieve_of_eratosthenes = self.getcompiled(snippet.sieve_of_eratosthenes,
                                                 [])
        assert sieve_of_eratosthenes() == 1028

    def test_nested_whiles(self):
        nested_whiles = self.getcompiled(snippet.nested_whiles, [int, int])
        assert nested_whiles(5, 3) == '!!!!!'

    def test_call_unpack_56(self):
        def wrap():
            res = snippet.call_unpack_56()
            return res == (2, 5, 6)
        fn = self.getcompiled(wrap, [])
        assert fn()

    def test_class_defaultattr(self):
        class K:
            n = "hello"
        def class_defaultattr():
            k = K()
            k.n += " world"
            return k.n
        fn = self.getcompiled(class_defaultattr, [])
        assert fn() == "hello world"

    def test_tuple_repr(self):
        def tuple_repr(x, y):
            z = x, y
            while x:
                x = x - 1
            return z == (6, 'a')
        fn = self.getcompiled(tuple_repr, [int, str])
        assert fn(6, "a")
        assert not fn(6, "xyz")

    def test_classattribute(self):
        fn = self.getcompiled(snippet.classattribute, [int])
        assert fn(1) == 123
        assert fn(2) == 456
        assert fn(3) == 789
        assert fn(4) == 789
        assert fn(5) == 101112

    def test_type_conversion(self):
        # obfuscated test case specially for typer.insert_link_conversions()
        def type_conversion(n):
            if n > 3:
                while n > 0:
                    n = n - 1
                    if n == 5:
                        n += 3.1416
            return n
        fn = self.getcompiled(type_conversion, [int])
        assert fn(3) == 3
        assert fn(5) == 0
        assert abs(fn(7) + 0.8584) < 1E-5

    def test_do_try_raise_choose(self):
        fn = self.getcompiled(snippet.try_raise_choose, [int])
        result = []
        for n in [-1, 0, 1, 2]:
            result.append(fn(n))
        assert result == [-1, 0, 1, 2]

    def test_is_perfect_number(self):
        fn = self.getcompiled(snippet.is_perfect_number, [int])
        for i in range(1, 33):
            perfect = fn(i)
            assert perfect is (i in (6, 28))

    def test_prime(self):
        fn = self.getcompiled(snippet.prime, [int])
        result = [fn(i) for i in range(1, 21)]
        assert result == [False, True, True, False, True, False, True, False,
                          False, False, True, False, True, False, False, False,
                          True, False, True, False]

    def test_mutate_global(self):
        class Stuff:
            pass
        g1 = Stuff(); g1.value = 1
        g2 = Stuff(); g2.value = 2
        g3 = Stuff(); g3.value = 3
        g1.next = g3
        g2.next = g3
        g3.next = g3
        def do_things():
            g1.next = g1
            g2.next = g1
            g3.next = g2
            return g3.next.next.value
        fn = self.getcompiled(do_things, [])
        assert fn() == 1

    def test_float_ops(self):
        def f(x):
            return abs(math.pow(-x, 3) + 1)
        fn = self.getcompiled(f, [float])
        assert fn(-4.5) == 92.125
        assert fn(4.5) == 90.125

    def test_memoryerror(self):
        def g(i):
            return [0] * i
        
        def f(i):
            try:
                lst = g(i)
                lst[-1] = 5
                return lst[0]
            except MemoryError:
                return -1
        fn = self.getcompiled(f, [int])
        assert fn(1) == 5
        assert fn(2) == 0
        assert fn(sys.maxint // 2 + 1) == -1
        assert fn(sys.maxint) == -1

    def test_chr(self):
        def f(x):
            try:
                return 'Yes ' + chr(x)
            except ValueError:
                return 'No'
        fn = self.getcompiled(f, [int])
        assert fn(65) == 'Yes A'
        assert fn(256) == 'No'
        assert fn(-1) == 'No'

    def test_unichr(self):
        def f(x):
            try:
                return ord(unichr(x))
            except ValueError:
                return -42
        fn = self.getcompiled(f, [int])
        assert fn(65) == 65
        assert fn(-12) == -42
        assert fn(sys.maxint) == -42

    def test_UNICHR(self):
        from rpython.rlib.runicode import UNICHR
        def f(x):
            try:
                return ord(UNICHR(x))
            except ValueError:
                return -42
        fn = self.getcompiled(f, [int])
        assert fn(65) == 65
        assert fn(-12) == -42
        assert fn(sys.maxint) == -42

    def test_list_indexerror(self):
        def f(i):
            lst = [123, 456]
            try:
                lst[i] = 789
            except IndexError:
                return 42
            return lst[0]
        fn = self.getcompiled(f, [int])
        assert fn(1) == 123
        assert fn(2) == 42
        assert fn(-2) == 789
        assert fn(-3) == 42

    def test_long_long(self):
        def f(i):
            return 4 * i
        fn = self.getcompiled(f, [r_ulonglong])
        assert fn(r_ulonglong(2147483647)) == 4 * 2147483647

        def g(i):
            return 4 * i
        gn = self.getcompiled(g, [r_longlong])
        assert gn(r_longlong(2147483647)) == 4 * 2147483647

        def g(i):
            return i << 12
        gn = self.getcompiled(g, [r_longlong])
        assert gn(r_longlong(2147483647)) == 2147483647 << 12

        def g(i):
            return i >> 12
        gn = self.getcompiled(g, [r_longlong])
        assert gn(r_longlong(-2147483647)) == (-2147483647) >> 12

        def g(i):
            return i >> 12
        gn = self.getcompiled(g, [r_ulonglong])
        assert gn(r_ulonglong(2 ** 64 - 12345678)) == (2 ** 64 - 12345678) >> 12

    def test_specializing_int_functions(self):
        def f(i):
            return i + 1
        f._annspecialcase_ = "specialize:argtype(0)"
        def g(n):
            if n > 0:
                return intmask(f(r_longlong(0)))
            else:
                return f(0)

        fn = self.getcompiled(g, [int])
        assert fn(0) == 1
        assert fn(1) == 1

    def test_downcast_int(self):
        def f(i):
            return int(i)
        fn = self.getcompiled(f, [r_longlong])
        assert fn(r_longlong(0)) == 0

    def test_upcast_int(self):
        def f(v):
            v = rffi.cast(rffi.USHORT, v)
            return intmask(v)
        fn = self.getcompiled(f, [int])
        assert fn(0x1234CDEF) == 0xCDEF

    def test_function_ptr(self):
        def f1():
            return 1
        def f2():
            return 2
        def g(i):
            if i:
                f = f1
            else:
                f = f2
            return f()
        fn = self.getcompiled(g, [int])
        assert fn(0) == 2
        assert fn(1) == 1

    def test_call_five(self):
        # --  the result of call_five() isn't a real list, but an rlist
        #     that can't be converted to a PyListObject
        def wrapper():
            lst = snippet.call_five()
            return (len(lst), lst[0]) == (1, 5)
        call_five = self.getcompiled(wrapper, [])
        result = call_five()
        assert result

    def test_get_set_del_slice(self):
        def get_set_del_nonneg_slice(): # no neg slices for now!
            l = [ord('a'), ord('b'), ord('c'), ord('d'), ord('e'), ord('f'), ord('g'), ord('h'), ord('i'), ord('j')]
            del l[:1]
            bound = len(l) - 1
            if bound >= 0:
                del l[bound:]
            del l[2:4]
            #l[:1] = [3]
            #bound = len(l)-1
            #assert bound >= 0
            #l[bound:] = [9]    no setting slice into lists for now
            #l[2:4] = [8,11]
            l[0], l[-1], l[2], l[3] = 3, 9, 8, 11

            list_3_c = l[:2]
            list_9 = l[5:]
            list_11_h = l[3:5]
            return str((len(l), l[0], l[1], l[2], l[3], l[4], l[5],
                    len(list_3_c),  list_3_c[0],  list_3_c[1],
                    len(list_9),    list_9[0],
                    len(list_11_h), list_11_h[0], list_11_h[1]))
        fn = self.getcompiled(get_set_del_nonneg_slice, [])
        result = fn()
        assert result == str((6, 3, ord('c'), 8, 11, ord('h'), 9,
                              2, 3, ord('c'),
                              1, 9,
                              2, 11, ord('h')))

    def test_is(self):
        def testfn():
            l1 = []
            return l1 is l1
        fn = self.getcompiled(testfn, [])
        result = fn()
        assert result is True
        def testfn():
            l1 = []
            return l1 is None
        fn = self.getcompiled(testfn, [])
        result = fn()
        assert result is False

    def test_str_compare(self):
        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] == s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] != s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] < s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] <= s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] > s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'twos', 'foobar']
            return s1[i] >= s2[j]
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(6):
                res = fn(i, j)
                assert res is testfn(i, j)

    def test_str_methods(self):
        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'ne', 'e', 'twos', 'foobar', 'fortytwo']
            return s1[i].startswith(s2[j])
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(9):
                res = fn(i, j)
                assert res is testfn(i, j)
        def testfn(i, j):
            s1 = ['one', 'two']
            s2 = ['one', 'two', 'o', 'on', 'ne', 'e', 'twos', 'foobar', 'fortytwo']
            return s1[i].endswith(s2[j])
        fn = self.getcompiled(testfn, [int, int])
        for i in range(2):
            for j in range(9):
                res = fn(i, j)
                assert res is testfn(i, j)

    def test_str_join(self):
        def testfn(i, j):
            s1 = ['', ',', ' and ']
            s2 = [[], ['foo'], ['bar', 'baz', 'bazz']]
            return s1[i].join(s2[j])
        fn = self.getcompiled(testfn, [int, int])
        for i in range(3):
            for j in range(3):
                res = fn(i, j)
                assert res == fn(i, j)

    def test_unichr_eq(self):
        l = list(u'Hello world')
        def f(i, j):
            return l[i] == l[j]
        fn = self.getcompiled(f, [int, int])
        for i in range(len(l)):
            for j in range(len(l)):
                res = fn(i, j)
                assert res == f(i, j)

    def test_unichr_ne(self):
        l = list(u'Hello world')
        def f(i, j):
            return l[i] != l[j]
        fn = self.getcompiled(f, [int, int])
        for i in range(len(l)):
            for j in range(len(l)):
                res = fn(i, j)
                assert res == f(i, j)

    def test_unichr_ord(self):
        l = list(u'Hello world')
        def f(i):
            return ord(l[i])
        fn = self.getcompiled(f, [int])
        for i in range(len(l)):
            res = fn(i)
            assert res == f(i)

    def test_unichr_unichr(self):
        l = list(u'Hello world')
        def f(i, j):
            return l[i] == unichr(j)
        fn = self.getcompiled(f, [int, int])
        for i in range(len(l)):
            for j in range(len(l)):
                res = fn(i, ord(l[j]))
                assert res == f(i, ord(l[j]))

    def test_int_overflow(self):
        fn = self.getcompiled(snippet.add_func, [int])
        fn(sys.maxint, expected_exception_name='OverflowError')

    def test_int_floordiv_ovf_zer(self):
        fn = self.getcompiled(snippet.div_func, [int])
        fn(-1, expected_exception_name='OverflowError')
        fn(0, expected_exception_name='ZeroDivisionError')

    def test_int_mul_ovf(self):
        fn = self.getcompiled(snippet.mul_func, [int, int])
        for y in range(-5, 5):
            for x in range(-5, 5):
                assert fn(x, y) == snippet.mul_func(x, y)
        n = sys.maxint / 4
        assert fn(n, 3) == snippet.mul_func(n, 3)
        assert fn(n, 4) == snippet.mul_func(n, 4)
        fn(n, 5, expected_exception_name='OverflowError')

    def test_int_mod_ovf_zer(self):
        fn = self.getcompiled(snippet.mod_func, [int])
        fn(-1, expected_exception_name='OverflowError')
        fn(0, expected_exception_name='ZeroDivisionError')

    def test_int_lshift_ovf(self):
        fn = self.getcompiled(snippet.lshift_func, [int])
        fn(1, expected_exception_name='OverflowError')

    def test_int_unary_ovf(self):
        def w(a, b):
            if not b:
                return snippet.unary_func(a)[0]
            else:
                return snippet.unary_func(a)[1]
        fn = self.getcompiled(w, [int, int])
        for i in range(-3, 3):
            assert fn(i, 0) == -(i)
            assert fn(i, 1) == abs(i - 1)
        fn(-sys.maxint - 1, 0, expected_exception_name='OverflowError')
        fn(-sys.maxint, 0, expected_exception_name='OverflowError')

    # floats
    def test_float_operations(self):
        def func(x, y):
            z = x + y / 2.1 * x
            z = math.fmod(z, 60.0)
            z = math.pow(z, 2)
            z = -z
            return int(z)

        fn = self.getcompiled(func, [float, float])
        assert fn(5.0, 6.0) == func(5.0, 6.0)

    def test_rpbc_bound_method_static_call(self):
        class R:
            def meth(self):
                return 0
        r = R()
        m = r.meth
        def fn():
            return m()
        res = self.getcompiled(fn, [])()
        assert res == 0

    def test_constant_return_disagreement(self):
        class R:
            def meth(self):
                return 0
        r = R()
        def fn():
            return r.meth()
        res = self.getcompiled(fn, [])()
        assert res == 0

    def test_stringformatting(self):
        def fn(i):
            return "you said %d, you did" % i
        f = self.getcompiled(fn, [int])
        assert f(1) == fn(1)

    def test_int2str(self):
        def fn(i):
            return str(i)
        f = self.getcompiled(fn, [int])
        assert f(1) == fn(1)

    def test_float2str(self):
        def fn(i):
            return str(i)
        f = self.getcompiled(fn, [float])
        res = f(1.0)
        assert type(res) is str and float(res) == 1.0

    def test_uint_arith(self):
        def fn(i):
            try:
                return ~(i * (i + 1)) / (i - 1)
            except ZeroDivisionError:
                return r_uint(91872331)
        f = self.getcompiled(fn, [r_uint])
        for value in range(15):
            i = r_uint(value)
            assert f(i) == fn(i)

    def test_ord_returns_a_positive(self):
        def fn(i):
            return ord(chr(i))
        f = self.getcompiled(fn, [int])
        assert f(255) == 255

    def test_hash_preservation(self):
        class C:
            pass
        class D(C):
            pass
        c = C()
        d = D()
        compute_hash(d)     # force to be cached on 'd', but not on 'c'
        #
        def fn():
            d2 = D()
            return str((compute_hash(d2),
                        current_object_addr_as_int(d2),
                        compute_hash(c),
                        compute_hash(d),
                        compute_hash(("Hi", None, (7.5, 2)))))

        f = self.getcompiled(fn, [])
        res = f()

        # xxx the next line is too precise, checking the exact implementation
        res = [int(a) for a in res[1:-1].split(",")]
        if res[0] != res[1]:
            assert res[0] == -res[1] - 1
        assert res[2] != compute_hash(c)     # likely
        assert res[3] != compute_hash(d)     # likely *not* preserved
        assert res[4] == compute_hash(("Hi", None, (7.5, 2)))
        # ^^ true as long as we're using the default 'fnv' hash for strings
        #    and not e.g. siphash24

    def _test_hash_string(self, algo):
        s = "hello"
        u = u"world"
        v = u"\u1234\u2318+\u2bcd\u2102"
        hash_s = compute_hash(s)
        hash_u = compute_hash(u)
        hash_v = compute_hash(v)
        assert hash_s == compute_hash(u"hello")   # same hash because it's
        assert hash_u == compute_hash("world")    #    a latin-1 unicode
        #
        def fn(length):
            if algo == "siphash24":
                from rpython.rlib import rsiphash
                rsiphash.enable_siphash24()
            assert length >= 1
            return str((compute_hash(s),
                        compute_hash(u),
                        compute_hash(v),
                        compute_hash(s[0] + s[1:length]),
                        compute_hash(u[0] + u[1:length]),
                        compute_hash(v[0] + v[1:length]),
                        ))

        assert fn(5) == str((hash_s, hash_u, hash_v, hash_s, hash_u, hash_v))

        f = self.getcompiled(fn, [int])
        res = f(5)
        res = [int(a) for a in res[1:-1].split(",")]
        if algo == "fnv":
            assert res[0] == hash_s
            assert res[1] == hash_u
            assert res[2] == hash_v
        else:
            assert res[0] != hash_s
            assert res[1] != hash_u
            assert res[2] != hash_v
        assert res[3] == res[0]
        assert res[4] == res[1]
        assert res[5] == res[2]

    def test_hash_string_fnv(self):
        self._test_hash_string("fnv")

    def test_hash_string_siphash24(self):
        self._test_hash_string("siphash24")

    def test_iterkeys_with_hash_on_prebuilt_dict(self):
        from rpython.rlib import objectmodel
        prebuilt_d = {"hello": 10, "world": 20}
        #
        def fn(n):
            from rpython.rlib import rsiphash
            rsiphash.enable_siphash24()
            #assert str(n) not in prebuilt_d <- this made the test pass,
            #       before the fix which was that iterkeys_with_hash()
            #       didn't do the initial rehashing on its own
            for key, h in objectmodel.iterkeys_with_hash(prebuilt_d):
                print key, h
                assert h == compute_hash(key)
            return 42

        f = self.getcompiled(fn, [int])
        res = f(0)
        assert res == 42

    def test_list_basic_ops(self):
        def list_basic_ops(i, j):
            l = [1, 2, 3]
            l.insert(0, 42)
            del l[1]
            l.append(i)
            listlen = len(l)
            l.extend(l)
            del l[listlen:]
            l += [5, 6]
            l[1] = i
            return l[j]
        f = self.getcompiled(list_basic_ops, [int, int])
        for i in range(6):
            for j in range(6):
                assert f(i, j) == list_basic_ops(i, j)

    def test_range2list(self):
        def fn():
            r = range(10, 37, 4)
            r.reverse()
            return r[0]
        f = self.getcompiled(fn, [])
        assert f() == fn()

    def test_range_idx(self):
        def fn(idx):
            r = range(10, 37, 4)
            try:
                return r[idx]
            except IndexError:
                return -1
        f = self.getcompiled(fn, [int])
        assert f(0) == fn(0)
        assert f(-1) == fn(-1)
        assert f(42) == -1

    def test_range_step(self):
        def fn(step):
            r = range(10, 37, step)
            return r[-2]
        f = self.getcompiled(fn, [int])
        assert f(1) == fn(1)
        assert f(3) == fn(3)

    def test_range_iter(self):
        def fn(start, stop, step):
            res = 0
            if step == 0:
                if stop >= start:
                    r = range(start, stop, 1)
                else:
                    r = range(start, stop, -1)
            else:
                r = range(start, stop, step)
            for i in r:
                res = res * 51 + i
            return res
        f = self.getcompiled(fn, [int, int, int])
        for args in [2, 7, 0], [7, 2, 0], [10, 50, 7], [50, -10, -3]:
            assert f(*args) == intmask(fn(*args))

    def test_list_len_is_true(self):

        class X(object):
            pass
        class A(object):
            def __init__(self):
                self.l = []

            def append_to_list(self, e):
                self.l.append(e)

            def check_list_is_true(self):
                did_loop = 0
                while self.l:
                    did_loop = 1
                    if len(self.l):
                        break
                return did_loop

        a1 = A()
        def f():
            for ii in range(1):
                a1.append_to_list(X())
            return a1.check_list_is_true()
        fn = self.getcompiled(f, [])
        assert fn() == 1

    def test_recursion_detection(self):
        def g(n):
            try:
                return f(n)
            except StackOverflow:
                return -42
        
        def f(n):
            if n == 0:
                return 1
            else:
                return n * f(n - 1)
        fn = self.getcompiled(g, [int])
        assert fn(7) == 5040
        assert fn(7) == 5040    # detection must work several times, too
        assert fn(7) == 5040
        assert fn(-1) == -42

    def test_infinite_recursion(self):
        def f(x):
            if x:
                return 1 + f(x)
            return 1
        def g(x):
            try:
                f(x)
            except RuntimeError:
                return 42
            return 1
        fn = self.getcompiled(g, [int])
        assert fn(0) == 1
        assert fn(1) == 42

    def test_r_dict_exceptions(self):
        from rpython.rlib.objectmodel import r_dict

        def raising_hash(obj):
            if obj.startswith("bla"):
                raise TypeError
            return 1
        def eq(obj1, obj2):
            return obj1 is obj2
        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                x = d1["blabla"]
            except Exception:
                return 42
            return x
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                x = d1["blabla"]
            except TypeError:
                return 42
            return x
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                d1["blabla"] = 2
            except TypeError:
                return 42
            return 0
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

    def test_float(self):
        ex = ['', '    ', '0', '1', '-1.5', '1.5E2', '2.5e-1', ' 0 ', '?']
        def f(i):
            s = ex[i]
            try:
                return float(s)
            except ValueError:
                return -999.0

        fn = self.getcompiled(f, [int])

        for i in range(len(ex)):
            expected = f(i)
            res = fn(i)
            assert res == expected

    def test_swap(self):
        def func_swap():
            a = []
            b = range(10)
            while b:
                b.pop()
                a.extend(b)
                tmp = a
                a = b
                b = tmp
                del a[:]

        self.getcompiled(func_swap, [])

    def test_ovfcheck_float_to_int(self):
        from rpython.rlib.rarithmetic import ovfcheck_float_to_int

        def func(fl):
            try:
                return ovfcheck_float_to_int(fl)
            except OverflowError:
                return -666
        f = self.getcompiled(func, [float])
        assert f(-123.0) == -123

        for frac in [0.0, 0.01, 0.99]:
            # strange things happening for float to int on 64 bit:
            # int(float(i)) != i  because of rounding issues
            x = sys.maxint
            while int(x + frac) > sys.maxint:
                x -= 1
            assert f(x + frac) == int(x + frac)

            x = sys.maxint
            while int(x - frac) <= sys.maxint:
                x += 1
            assert f(x - frac) == -666

            x = -sys.maxint - 1
            while int(x - frac) < -sys.maxint - 1:
                x += 1
            assert f(x - frac) == int(x - frac)

            x = -sys.maxint - 1
            while int(x + frac) >= -sys.maxint- 1:
                x -= 1
            assert f(x + frac) == -666

    def test_context_manager(self):
        state = []
        class C:
            def __init__(self, name):
                self.name = name
            def __enter__(self):
                state.append('acquire')
                return self
            def __exit__(self, typ, value, tb):
                if typ is not None:
                    if value is None:
                        raise RuntimeError('test failed')
                    state.append('raised')
                else:
                    if value is not None:
                        raise RuntimeError('test failed')
                state.append('release')

        def func(n):
            del state[:]
            try:
                with C('hello') as c:
                    state.append(c.name)
                    if n == 1:
                        raise ValueError
                    elif n == 2:
                        raise TypeError
            except (ValueError, TypeError):
                pass
            return ', '.join(state)
        f = self.getcompiled(func, [int])
        res = f(0)
        assert res == 'acquire, hello, release'
        res = f(1)
        assert res == 'acquire, hello, raised, release'
        res = f(2)
        assert res == 'acquire, hello, raised, release'

    def test_longlongmask(self):
        def func(n):
            m = r_ulonglong(n)
            m *= 100000
            return longlongmask(m)
        f = self.getcompiled(func, [int])
        res = f(-2000000000)
        assert res == -200000000000000

    def test_int128(self):
        if not hasattr(rffi, '__INT128_T'):
            py.test.skip("no '__int128_t'")
        def func(n):
            x = rffi.cast(getattr(rffi, '__INT128_T'), n)
            x *= x
            x *= x
            x *= x
            x *= x
            return intmask(x >> 96)
        f = self.getcompiled(func, [int])
        res = f(217)
        assert res == 305123851

    def test_uint128(self):
        if not hasattr(rffi, '__UINT128_T'):
            py.test.skip("no '__uint128_t'")
        def func(n):
            x = rffi.cast(getattr(rffi, '__UINT128_T'), n)
            x *= x
            x *= x
            x *= x
            x *= x
            return intmask(x >> 96)
        f = self.getcompiled(func, [int])
        res = f(217)
        assert res == 305123851

    def test_uint128_constant(self):
        if not hasattr(rffi, '__UINT128_T'):
            py.test.skip("no '__uint128_t'")
        x = rffi.cast(getattr(rffi, '__UINT128_T'), 41)
        x <<= 60
        x *= 7
        def func(n):
            y = NonConstant(x)
            y >>= 50
            return intmask(y)
        f = self.getcompiled(func, [int])
        res = f(1)
        assert res == ((41 << 60) * 7) >> 50

    def test_int128_constant(self):
        if not hasattr(rffi, '__INT128_T'):
            py.test.skip("no '__int128_t'")
        x = rffi.cast(getattr(rffi, '__INT128_T'), -41)
        x <<= 60
        x *= 7
        x |= 2**63
        def func(n):
            y = NonConstant(x)
            y >>= 50
            return intmask(y)
        f = self.getcompiled(func, [int])
        res = f(1)
        assert res == (((-41 << 60) * 7) | 2**63) >> 50

    def test_bool_2(self):
        def func(n):
            x = rffi.cast(lltype.Bool, n)
            return int(x)
        f = self.getcompiled(func, [int])
        res = f(2)
        assert res == 1     # and not 2

    def test_mulmod(self):
        from rpython.rlib.rarithmetic import mulmod

        def func(a, b, c):
            return mulmod(a, b, c)
        f = self.getcompiled(func, [int, int, int])
        res = f(1192871273, 1837632879, 2001286281)
        assert res == 1573897320

    def test_long_float(self):
        from rpython.rlib.rarithmetic import r_longfloat

        c = rffi.cast(lltype.LongFloat, 123)
        def func():
            return rffi.cast(lltype.Float, c)
        f = self.getcompiled(func, [])
        res = f()
        assert res == 123.0
