import py
from rpython.rlib.jit import JitDriver, dont_look_inside
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib import rgc
from rpython.jit.metainterp.test.support import LLJitMixin


class DelTests:

    def test_del_keep_obj(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x'])
        class Foo:
            def __del__(self):
                pass
        def f(n):
            x = None
            while n > 0:
                myjitdriver.can_enter_jit(x=x, n=n)
                myjitdriver.jit_merge_point(x=x, n=n)
                x = Foo()
                Foo()
                n -= 1
            return 42
        self.meta_interp(f, [20])
        self.check_resops({'call_r': 4,      # calls to a helper function
                           'guard_no_exception': 4,    # follows the calls
                           'int_sub': 2,
                           'int_gt': 2,
                           'guard_true': 2,
                           'jump': 1})

    def test_class_of_allocated(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x'])
        class Foo:
            def __del__(self):
                pass
            def f(self):
                return self.meth()
        class X(Foo):
            def meth(self):
                return 456
        class Y(Foo):
            def meth(self):
                return 123
        def f(n):
            x = None
            while n > 0:
                myjitdriver.can_enter_jit(x=x, n=n)
                myjitdriver.jit_merge_point(x=x, n=n)
                x = X()
                y = Y()
                assert x.f() == 456
                assert y.f() == 123
                n -= 1
            return 42
        res = self.meta_interp(f, [20])
        assert res == 42

    def test_instantiate_with_or_without_del(self):
        import gc
        mydriver = JitDriver(reds = ['n', 'x'], greens = [])
        class Base: pass
        class A(Base): foo = 72
        class B(Base):
            foo = 8
            def __del__(self):
                pass
        def f(n):
            x = 0
            while n > 0:
                mydriver.can_enter_jit(n=n, x=x)
                mydriver.jit_merge_point(n=n, x=x)
                if n % 2 == 0:
                    cls = A
                else:
                    cls = B
                inst = cls()
                x += inst.foo
                n -= 1
            return 1
        res = self.meta_interp(f, [20], enable_opts='')
        assert res == 1
        self.check_resops(call_r=1)   # for the case B(), but not for the case A()

class TestLLtype(DelTests, LLJitMixin):
    pass
