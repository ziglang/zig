import py
from rpython.rlib.objectmodel import newlist_hint
from rpython.rlib.jit import JitDriver, promote
from rpython.jit.metainterp.test.support import LLJitMixin


class ListTests:

    def check_all_virtualized(self):
        self.check_resops(setarrayitem_gc=0, new_array=0, arraylen_gc=0,
                          getarrayitem_gc_i=0, getarrayitem_gc_r=0,
                          getarrayitem_gc_f=0)        

    def test_simple_array(self):
        jitdriver = JitDriver(greens = [], reds = ['n'])
        def f(n):
            while n > 0:
                jitdriver.can_enter_jit(n=n)
                jitdriver.jit_merge_point(n=n)
                lst = [n]
                n = lst[0] - 1
            return n
        res = self.meta_interp(f, [10], listops=True)
        assert res == 0
        self.check_resops(int_sub=2)
        self.check_all_virtualized()

    def test_list_pass_around(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'l'])
        def f(n):
            l = [3]
            while n > 0:
                jitdriver.can_enter_jit(n=n, l=l)
                jitdriver.jit_merge_point(n=n, l=l)
                x = l[0]
                l = [x + 1]
                n -= 1
            return l[0]

        res = self.meta_interp(f, [10], listops=True)
        assert res == f(10)
        self.check_all_virtualized()

    def test_cannot_be_virtual(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'l'])
        def f(n):
            l = [3] * 200
            while n > 0:
                jitdriver.can_enter_jit(n=n, l=l)
                jitdriver.jit_merge_point(n=n, l=l)
                x = l[n]
                l = [3] * 200
                l[3] = x
                l[4] = x + 1
                n -= 1
            return l[0]

        res = self.meta_interp(f, [10], listops=True)
        assert res == f(10)
        # one setitem should be gone by now
        self.check_resops(setarrayitem_gc=4, getarrayitem_gc_i=2, call_r=2)


    def test_ll_fixed_setitem_fast(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'l'])

        def f(n):
            l = [1, 2, 3]

            while n > 0:
                jitdriver.can_enter_jit(n=n, l=l)
                jitdriver.jit_merge_point(n=n, l=l)
                l = l[:]
                n -= 1
            return l[0]

        res = self.meta_interp(f, [10], listops=True)
        assert res == 1
        py.test.skip("Constant propagation of length missing")
        self.check_loops(setarrayitem_gc=0, call=0)

    def test_vlist_with_default_read(self):
        jitdriver = JitDriver(greens=[], reds=['n'])
        def f(n):
            l = [1] * 20
            while n > 0:
                jitdriver.can_enter_jit(n=n)
                jitdriver.jit_merge_point(n=n)
                l = [0] * 20
                l[3] = 5
                x = l[-17] + l[5] # that should be zero
                if n < 3:
                    return x
                n -= 1
            return l[0]

        res = self.meta_interp(f, [10], listops=True, backendopt=True)
        assert res == f(10)
        self.check_resops(setarrayitem_gc=0, call=0, getarrayitem_gc_i=0)

    def test_arraycopy_simpleoptimize(self):
        def f():
            l = [1, 2, 3, 4]
            l2 = l[:]
            return l2[0] + l2[1] + l2[2] + l2[3]

        res = self.interp_operations(f, [], listops=True)
        assert res == 10

    def test_arraycopy_bug(self):
        def f():
            l = [1, 2, 3, 4]
            l2 = [1, 2, 3, 5]
            l[2] = 13
            l2[0:len(l2)] = l[:]
            return l2[0] + l2[1] + l2[2] + l2[3]

        res = self.interp_operations(f, [], listops=True)
        assert res == f()

    def test_arraycopy_full(self):
        jitdriver = JitDriver(greens = [], reds = ['n'])
        def f(n):
            l = []
            l2 = []
            while n > 0:
                jitdriver.can_enter_jit(n=n)
                jitdriver.jit_merge_point(n=n)
                l = [1, 2, 3, n]
                l2 = l[:]
                n -= 1
            return l2[0] + l2[1] + l2[2] + l2[3]

        res = self.meta_interp(f, [5], listops=True)
        assert res == 7
        self.check_resops(call=0)

    def test_arraymove_simpleoptimize(self):
        def f():
            l = [10, 20, 30, 40]
            l.insert(1, 999)
            return len(l) + l[1] + l[-1]

        res = self.interp_operations(f, [], listops=True)
        assert res == 5 + 999 + 40

    def test_fold_getitem_1(self):
        jitdriver = JitDriver(greens = ['pc', 'n', 'l'], reds = ['total'])
        def f(n):
            l = [100, n, 300, n, 500]
            total = 0
            pc = n
            while True:
                jitdriver.can_enter_jit(l=l, pc=pc, n=n, total=total)
                jitdriver.jit_merge_point(l=l, pc=pc, n=n, total=total)
                total += l[pc]
                if total > 10000:
                    return total
                pc -= 1
                if pc < 0:
                    pc = n

        res = self.meta_interp(f, [4], listops=True)
        assert res == f(4)
        self.check_resops(call=0)

    def test_fold_getitem_2(self):
        jitdriver = JitDriver(greens = ['pc', 'n', 'l'], reds = ['total', 'x'])
        class X:
            pass
        def f(n):
            l = [100, n, 300, n, 500]
            total = 0
            x = X()
            x.pc = n
            while True:
                pc = x.pc
                jitdriver.can_enter_jit(l=l, pc=pc, n=n, total=total, x=x)
                jitdriver.jit_merge_point(l=l, pc=pc, n=n, total=total, x=x)
                x.pc = pc
                total += l[x.pc]
                if total > 10000:
                    return total
                x.pc -= 1
                if x.pc < 0:
                    x.pc = n

        res = self.meta_interp(f, [4], listops=True)
        assert res == f(4)
        self.check_resops(call=0, getfield_gc=0)

    def test_fold_indexerror(self):
        jitdriver = JitDriver(greens = [], reds = ['total', 'n', 'lst'])
        def f(n):
            lst = []
            total = 0
            while n > 0:
                jitdriver.can_enter_jit(lst=lst, n=n, total=total)
                jitdriver.jit_merge_point(lst=lst, n=n, total=total)
                lst.append(n)
                try:
                    total += lst[n]
                except IndexError:
                    total += 1000
                n -= 1
            return total

        res = self.meta_interp(f, [15], listops=True)
        assert res == f(15)
        self.check_resops(guard_exception=0)

    def test_virtual_resize(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 's'])
        def f(n):
            s = 0
            while n > 0:
                jitdriver.jit_merge_point(n=n, s=s)
                lst = []
                lst += [1]
                n -= len(lst)
                s += lst[0]
                lst.pop()
                lst.append(1)
                lst.insert(0, 5)
                lst.insert(0, 5)
                lst.insert(1, 6)
                s *= lst.pop()
            return s
        res = self.meta_interp(f, [15], listops=True)
        assert res == f(15)
        self.check_resops({'jump': 1, 'int_gt': 2, 'int_add': 2,
                           'guard_true': 2, 'int_sub': 2})

    def test_newlist_hint(self):
        def f(i):
            l = newlist_hint(i)
            l[0] = 55
            return len(l)

        r = self.interp_operations(f, [3])
        assert r == 0

    def test_newlist_hint_optimized(self):
        driver = JitDriver(greens = [], reds = ['i'])

        def f(i):
            while i > 0:
                driver.jit_merge_point(i=i)
                l = newlist_hint(5)
                l.append(1)
                i -= l[0]

        self.meta_interp(f, [10], listops=True)
        self.check_resops(new_array=0, call=0)

    def test_list_mul(self):
        def f(i):
            l = [0] * i
            return len(l)

        r = self.interp_operations(f, [3])
        assert r == 3
        r = self.interp_operations(f, [-1])
        assert r == 0

    def test_list_mul_nonzero(self):
        driver = JitDriver(greens=[], reds=['i', 'n'])

        def f(n):
            i = 0
            while i < n:
                driver.jit_merge_point(i=i, n=n)
                x = promote(n)
                l = [-1] * x
                i -= l[2]
            return i
        res = self.meta_interp(f, [5])
        assert res == 5
        self.check_resops(call=0)

    def test_list_mul_virtual(self):
        class Foo:
            def __init__(self, l):
                self.l = l
                l[0] = self

        myjitdriver = JitDriver(greens = [], reds = ['y'])
        def f(y):
            while y > 0:
                myjitdriver.jit_merge_point(y=y)
                Foo([None] * 5)
                y -= 1
            return 42

        self.meta_interp(f, [5])
        self.check_resops({'int_sub': 2,
                           'int_gt': 2,
                           'guard_true': 2,
                           'jump': 1})

    def test_list_mul_virtual_nonzero(self):
        class base:
            pass
        class Foo(base):
            def __init__(self, l):
                self.l = l
                l[0] = self
        class nil(base):
            pass

        nil = nil()

        myjitdriver = JitDriver(greens = [], reds = ['y'])
        def f(y):
            while y > 0:
                myjitdriver.jit_merge_point(y=y)
                Foo([nil] * 5)
                y -= 1
            return 42

        self.meta_interp(f, [5])
        self.check_resops({'int_sub': 2,
                           'int_gt': 2,
                           'guard_true': 2,
                           'jump': 1})

    def test_list_mul_unsigned_virtual(self):
        from rpython.rlib.rarithmetic import r_uint

        class Foo:
            def __init__(self, l):
                self.l = l
                l[0] = self

        myjitdriver = JitDriver(greens = [], reds = ['y'])
        def f(y):
            while y > 0:
                myjitdriver.jit_merge_point(y=y)
                Foo([None] * r_uint(5))
                y -= 1
            return 42

        self.meta_interp(f, [5])
        self.check_resops({'int_sub': 2,
                           'int_gt': 2,
                           'guard_true': 2,
                           'jump': 1})

    def test_conditional_call_append(self):
        jitdriver = JitDriver(greens = [], reds = 'auto')

        def f(n):
            l = []
            while n > 0:
                jitdriver.jit_merge_point()
                l.append(n)
                n -= 1
            return len(l)

        res = self.meta_interp(f, [10])
        assert res == 10
        self.check_resops(call=0, cond_call=2)

    def test_conditional_call_pop(self):
        jitdriver = JitDriver(greens = [], reds = 'auto')

        def f(n):
            l = range(n)
            while n > 0:
                jitdriver.jit_merge_point()
                l.pop()
                n -= 1
            return len(l)

        res = self.meta_interp(f, [10])
        assert res == 0
        self.check_resops(call=0, cond_call=2)

class TestLLtype(ListTests, LLJitMixin):
    def test_listops_dont_invalidate_caches(self):
        class A(object):
            pass
        jitdriver = JitDriver(greens = [], reds = ['n', 'a', 'lst'])
        def f(n):
            a = A()
            a.x = 1
            if n < 1091212:
                a.x = 2 # fool the annotator
            lst = [n * 5, n * 10, n * 20]
            while n > 0:
                jitdriver.can_enter_jit(n=n, a=a, lst=lst)
                jitdriver.jit_merge_point(n=n, a=a, lst=lst)
                n += a.x
                n = lst.pop()
                lst.append(n - 10 + a.x)
                if a.x in lst:
                    pass
                a.x = a.x + 1 - 1
            a = lst.pop()
            b = lst.pop()
            return a * b
        res = self.meta_interp(f, [37])
        assert res == f(37)
        # There is the one actual field on a, plus several fields on the list
        # itself
        self.check_resops(getfield_gc_i=2, getfield_gc_r=5)

    def test_zero_init_resizable(self):
        def f(n):
            l = [0] * n
            l.append(123)
            return len(l) + l[0] + l[1] + l[2] + l[3] + l[4] + l[5] + l[6]

        res = self.interp_operations(f, [10], listops=True, inline=True)
        assert res == 11
        self.check_operations_history(new_array_clear=1)
