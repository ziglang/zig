import py
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.jit import JitDriver
from rpython.rlib import objectmodel
from collections import OrderedDict

class DictTests:
    @staticmethod
    def newdict():   # overridden in TestLLOrderedDict
        return {}

    def _freeze_(self):
        return True

    def test_dict_set_none(self):
        def fn(n):
            d = self.newdict()
            d[0] = None
            return bool(d[n])
        res = self.interp_operations(fn, [0])
        assert not res

    def test_dict_of_classes_as_values(self):
        class A:
            x = 5
        class B(A):
            x = 8
        def fn(n):
            A()
            B()
            d = self.newdict()
            d[42] = A
            d[43] = B
            return d[n].x
        res = self.interp_operations(fn, [43])
        assert res == 8

    def test_dict_keys_values_items(self):
        for name, extract, expected in [('keys', None, 'k'),
                                        ('values', None, 'v'),
                                        ('items', 0, 'k'),
                                        ('items', 1, 'v'),
                                        ]:
            myjitdriver = JitDriver(greens = [], reds = ['n', 'dct'])
            def f(n):
                dct = self.newdict()
                while n > 0:
                    myjitdriver.can_enter_jit(n=n, dct=dct)
                    myjitdriver.jit_merge_point(n=n, dct=dct)
                    dct[n] = n*n
                    n -= 1
                sum = 0
                for x in getattr(dct, name)():
                    if extract is not None:
                        x = x[extract]
                    sum += x
                return sum

            if expected == 'k':
                expected = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10
            else:
                expected = 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100

            assert f(10) == expected
            res = self.meta_interp(f, [10], listops=True)
            assert res == expected

    def test_dict_iter(self):
        for name, extract, expected in [('iterkeys', None, 60),
                                        ('itervalues', None, 111),
                                        ('iteritems', 0, 60),
                                        ('iteritems', 1, 111),
                                        ]:
            myjitdriver = JitDriver(greens = [], reds = ['total', 'it'])
            def f(n):
                dct = self.newdict()
                dct[n] = 100
                dct[50] = n + 1
                it = getattr(dct, name)()
                total = 0
                while True:
                    myjitdriver.can_enter_jit(total=total, it=it)
                    myjitdriver.jit_merge_point(total=total, it=it)
                    try:
                        x = it.next()
                    except StopIteration:
                        break
                    if extract is not None:
                        x = x[extract]
                    total += x
                return total

            assert f(10) == expected
            res = self.meta_interp(f, [10], listops=True)
            assert res == expected

    def test_dict_trace_hash(self):
        if type(self.newdict()) is not dict:
            py.test.skip("this is an r_dict test")
        myjitdriver = JitDriver(greens = [], reds = ['total', 'dct'])
        def key(x):
            return x & 1
        def eq(x, y):
            return (x & 1) == (y & 1)

        def f(n):
            dct = objectmodel.r_dict(eq, key)
            total = n
            while total:
                myjitdriver.jit_merge_point(total=total, dct=dct)
                if total not in dct:
                    dct[total] = []
                dct[total].append(total)
                total -= 1
            return len(dct[0])

        res1 = f(100)
        res2 = self.meta_interp(f, [100], listops=True)
        assert res1 == res2
        self.check_resops(int_and=2) # the hash was traced and eq, but cached

    def test_dict_setdefault(self):
        myjitdriver = JitDriver(greens = [], reds = ['total', 'dct'])
        def f(n):
            dct = self.newdict()
            total = n
            while total:
                myjitdriver.jit_merge_point(total=total, dct=dct)
                dct.setdefault(total % 2, []).append(total)
                total -= 1
            return len(dct[0])

        assert f(100) == 50
        res = self.meta_interp(f, [100], listops=True)
        assert res == 50
        self.check_resops(new=0, new_with_vtable=0)

    def test_dict_as_counter(self):
        if type(self.newdict()) is not dict:
            py.test.skip("this is an r_dict test")
        myjitdriver = JitDriver(greens = [], reds = ['total', 'dct'])
        def key(x):
            return x & 1
        def eq(x, y):
            return (x & 1) == (y & 1)

        def f(n):
            dct = objectmodel.r_dict(eq, key)
            total = n
            while total:
                myjitdriver.jit_merge_point(total=total, dct=dct)
                dct[total] = dct.get(total, 0) + 1
                total -= 1
            return dct[0]

        assert f(100) == 50
        res = self.meta_interp(f, [100], listops=True)
        assert res == 50
        self.check_resops(int_and=2) # key + eq, but cached

    def test_repeated_lookup(self):
        if type(self.newdict()) is not dict:
            py.test.skip("this is an r_dict test")
        myjitdriver = JitDriver(greens = [], reds = ['n', 'd'])
        class Wrapper(object):
            _immutable_fields_ = ["value"]
            def __init__(self, value):
                self.value = value
        def eq_func(a, b):
            return a.value == b.value
        def hash_func(x):
            return objectmodel.compute_hash(x.value)

        def f(n):
            d = None
            while n > 0:
                myjitdriver.jit_merge_point(n=n, d=d)
                d = objectmodel.r_dict(eq_func, hash_func)
                y = Wrapper(str(n))
                d[y] = n - 1
                n = d[y]
            return d[Wrapper(str(n + 1))]

        # XXX <arigo> unsure I see the point of this test: the repeated
        # dict lookup is *not* elided so far, and the test happens to
        # check this...  with rdict.py, it's a write followed by a read,
        # where the dict cache is thrown away after the first lookup
        # (correctly: we don't want the two lookups to return the exact
        # same result!).  With rordereddict.py, FLAG_STORE lookups are
        # not cached anyway.
        res = self.meta_interp(f, [100], listops=True)
        assert res == f(50)
        self.check_resops({'new_array_clear': 2, 'getfield_gc_r': 2,
                           'guard_true': 4, 'jump': 1,
                           'new_with_vtable': 2, 'getinteriorfield_gc_i': 2,
                           'setfield_gc': 14, 'int_gt': 2, 'int_sub': 2,
                           'call_i': 4, 'call_n': 2, 'call_r': 2, 'int_ge': 2,
                           'cond_call_value_i': 2, 'strhash': 4,
                           'guard_no_exception': 8, 'new': 2,
                           'guard_nonnull': 2})

    def test_unrolling_of_dict_iter(self):
        driver = JitDriver(greens = [], reds = ['n'])

        def f(n):
            while n > 0:
                driver.jit_merge_point(n=n)
                d = self.newdict()
                d[1] = 1
                for elem in d:
                    n -= elem
            return n

        res = self.meta_interp(f, [10], listops=True)
        assert res == 0
        self.check_simple_loop({'int_sub': 1, 'int_gt': 1, 'guard_true': 1,
                                'jump': 1})

    def test_dict_two_lookups(self):
        driver = JitDriver(greens = [], reds = 'auto')
        d = {'a': 3, 'b': 4}
        indexes = ['a', 'b']

        def f(n):
            s = 0
            while n > 0:
                driver.jit_merge_point()
                s += d[indexes[n & 1]]
                s += d[indexes[n & 1]]
                n -= 1
            return s

        self.meta_interp(f, [10])
        # XXX should be one getinteriorfield_gc.  At least it's one call.
        self.check_simple_loop(call_i=1, getinteriorfield_gc_i=2,
                               guard_no_exception=1)

    def test_ordered_dict_two_lookups(self):
        driver = JitDriver(greens = [], reds = 'auto')
        d = OrderedDict()
        d['a'] = 3
        d['b'] = 4
        indexes = ['a', 'b']

        def f(n):
            s = 0
            while n > 0:
                driver.jit_merge_point()
                s += d[indexes[n & 1]]
                s += d[indexes[n & 1]]
                n -= 1
            return s

        self.meta_interp(f, [10])
        # XXX should be one getinteriorfield_gc.  At least it's one call.
        self.check_simple_loop(call_i=1, getinteriorfield_gc_i=2,
                               guard_no_exception=1)

    def test_dict_insert_invalidates_caches(self):
        driver = JitDriver(greens = [], reds = 'auto')
        indexes = ['aa', 'b', 'cc']

        def f(n):
            d = {'aa': 3, 'b': 4, 'cc': 5}
            s = 0
            while n > 0:
                driver.jit_merge_point()
                index = indexes[n & 1]
                s += d[index]
                d['aa'] = 13 # this will invalidate the index
                s += d[index]
                n -= 1
            return s

        res = self.meta_interp(f, [10])
        assert res == f(10)
        self.check_simple_loop(call_i=3, cond_call_value_i=1, call_n=1)

    def test_dict_array_write_invalidates_caches(self):
        driver = JitDriver(greens = [], reds = 'auto')
        indexes = ['aa', 'b', 'cc']

        def f(n):
            d = {'aa': 3, 'b': 4, 'cc': 5}
            s = 0
            while n > 0:
                driver.jit_merge_point()
                index = indexes[n & 1]
                s += d[index]
                del d['cc']
                s += d[index]
                d['cc'] = 3
                n -= 1
            return s

        exp = f(10)
        res = self.meta_interp(f, [10])
        assert res == exp
        self.check_simple_loop(call_i=4, cond_call_value_i=1, call_n=2)

    def test_dict_double_lookup_2(self):
        driver = JitDriver(greens = [], reds = 'auto')
        indexes = ['aa', 'b', 'cc']

        def f(n):
            d = {'aa': 3, 'b': 4, 'cc': 5}
            s = 0
            while n > 0:
                driver.jit_merge_point()
                index = indexes[n & 1]
                s += d[index]
                d[index] += 1
                n -= 1
            return s

        res = self.meta_interp(f, [10])
        assert res == f(10)
        self.check_simple_loop(call_i=1, cond_call_value_i=1, call_n=1)

    def test_dict_eq_can_release_gil(self):
        from rpython.rtyper.lltypesystem import lltype, rffi
        if type(self.newdict()) is not dict:
            py.test.skip("this is an r_dict test")
        T = rffi.CArrayPtr(rffi.TIME_T)
        external = rffi.llexternal("time", [T], rffi.TIME_T, releasegil=True)
        myjitdriver = JitDriver(greens = [], reds = ['total', 'dct'])
        def key(x):
            return x % 2
        def eq(x, y):
            external(lltype.nullptr(T.TO))
            return (x % 2) == (y % 2)

        def f(n):
            dct = objectmodel.r_dict(eq, key)
            total = n
            x = 44444
            y = 55555
            z = 66666
            while total:
                myjitdriver.jit_merge_point(total=total, dct=dct)
                dct[total] = total
                x = dct[total]
                y = dct[total]
                z = dct[total]
                total -= 1
            return len(dct) + x + y + z

        res = self.meta_interp(f, [10], listops=True)
        assert res == 2 + 1 + 1 + 1
        self.check_simple_loop(call_may_force_i=4,
                              # ll_dict_lookup_trampoline
                              call_n=1) # ll_dict_setitem_lookup_done_trampoline

    def test_bug42(self):
        myjitdriver = JitDriver(greens = [], reds = 'auto')
        def f(n):
            mdict = {0: None, 1: None, 2: None, 3: None, 4: None,
                     5: None, 6: None, 7: None, 8: None, 9: None}
            while n > 0:
                myjitdriver.jit_merge_point()
                n -= 1
                if n in mdict:
                    del mdict[n]
                    if n in mdict:
                        raise Exception
        self.meta_interp(f, [10])
        self.check_simple_loop(call_may_force_i=0, call_i=2, call_n=1)

    def test_dict_virtual(self):
        myjitdriver = JitDriver(greens = [], reds = 'auto')
        def f(n):
            d = {}
            while n > 0:
                myjitdriver.jit_merge_point()
                if n & 7 == 0:
                    n -= len(d)
                d = {}
                d["a"] = n
                n -= 1
            return len(d)
        self.meta_interp(f, [100])
        self.check_simple_loop(call_may_force_i=0, call_i=0, new=0)

    def test_loop_over_virtual_dict_gives_constants(self):
        def fn(n):
            d = self.newdict()
            d[0] = n
            d[1] = n
            d2 = self.newdict()
            d2[3] = n + 2
            for key, value in d2.iteritems():
                d[key] = value
            return d[3]
        res = self.interp_operations(fn, [0])
        assert res == 2
        self.check_operations_history(getinteriorfield_gc_i=0)


class TestLLtype(DictTests, LLJitMixin):
    pass

class TestLLOrderedDict(DictTests, LLJitMixin):
    @staticmethod
    def newdict():
        return OrderedDict()

    def test_dict_is_ordered(self):
        def fn(n):
            d = OrderedDict()
            d[3] = 5
            d[n] = 9
            d[2] = 6
            d[1] = 4
            lst = d.items()
            assert len(lst) == 4
            return (    lst[0][0] +       10*lst[0][1] +
                    100*lst[1][0] +     1000*lst[1][1] +
                  10000*lst[3][0] +   100000*lst[2][1] +
                1000000*lst[2][0] + 10000000*lst[3][1])

        res = self.interp_operations(fn, [0])
        assert res == fn(0)

    def test_unrolling_of_dict_iter(self):
        py.test.skip("XXX fix me: ordereddict generates a mess for now")
