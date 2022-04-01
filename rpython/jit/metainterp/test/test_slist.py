import py
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.jit import JitDriver

class ListTests(object):

    def test_basic_list(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'lst'])
        def f(n):
            lst = []
            while n > 0:
                myjitdriver.can_enter_jit(n=n, lst=lst)
                myjitdriver.jit_merge_point(n=n, lst=lst)
                lst.append(n)
                n -= len(lst)
            return len(lst)
        res = self.meta_interp(f, [42], listops=True)
        assert res == 9

    def test_list_operations(self):
        class FooBar:
            def __init__(self, z):
                self.z = z
        def f(n):
            lst = [41, 42]
            lst[0] = len(lst)     # [2, 42]
            lst.append(lst[1])    # [2, 42, 42]
            m = lst.pop()         # 42
            m += lst.pop(0)       # 44
            lst2 = [FooBar(3)]
            lst2.append(FooBar(5))
            m += lst2.pop().z     # 49
            return m
        res = self.interp_operations(f, [11], listops=True)
        assert res == 49
        self.check_operations_history(call_i=1, call_n=2)

    def test_list_of_voids(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'lst'])
        def f(n):
            lst = [None]
            while n > 0:
                myjitdriver.can_enter_jit(n=n, lst=lst)
                myjitdriver.jit_merge_point(n=n, lst=lst)
                lst = [None, None]
                n -= 1
            return len(lst)
        res = self.meta_interp(f, [21], listops=True)
        assert res == 2

    def test_make_list(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'lst'])
        def f(n):
            lst = None
            while n > 0:
                lst = [0] * 10
                myjitdriver.can_enter_jit(n=n, lst=lst)
                myjitdriver.jit_merge_point(n=n, lst=lst)
                n -= 1
            return lst[n]
        res = self.meta_interp(f, [21], listops=True, enable_opts='')
        assert res == 0

    def test_getitem(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'i', 'lst'])
        def f(n):
            lst = []
            for i in range(n):
                lst.append(i)
            i = 0
            while n > 0:
                myjitdriver.can_enter_jit(n=n, lst=lst, i=i)
                myjitdriver.jit_merge_point(n=n, lst=lst, i=i)
                n -= lst[i]
                i += 1
            return lst[i]
        res = self.meta_interp(f, [21], listops=True)
        assert res == f(21)
        self.check_resops(call=0)

    def test_getitem_neg(self):
        myjitdriver = JitDriver(greens = [], reds = ['i', 'n'])
        def f(n):
            x = i = 0
            while i < 10:
                myjitdriver.can_enter_jit(n=n, i=i)
                myjitdriver.jit_merge_point(n=n, i=i)
                lst = [41]
                lst.append(42)
                x = lst[n]
                i += 1
            return x
        res = self.meta_interp(f, [-2], listops=True)
        assert res == 41
        self.check_resops(call=0, guard_value=0)


class TestLLtype(ListTests, LLJitMixin):
    pass
