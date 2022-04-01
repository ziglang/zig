
import py

from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper import rclass
from rpython.rtyper.rclass import FieldListAccessor, IR_QUASIIMMUTABLE
from rpython.jit.metainterp.quasiimmut import QuasiImmut
from rpython.jit.metainterp.quasiimmut import get_current_qmut_instance
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.rlib.jit import JitDriver, dont_look_inside, unroll_safe, promote


def test_get_current_qmut_instance():
    accessor = FieldListAccessor()
    accessor.initialize(None, {'inst_x': IR_QUASIIMMUTABLE})
    STRUCT = lltype.GcStruct('Foo', ('inst_x', lltype.Signed),
                             ('mutate_x', rclass.OBJECTPTR),
                             hints={'immutable_fields': accessor})
    foo = lltype.malloc(STRUCT, zero=True)
    foo.inst_x = 42
    assert not foo.mutate_x

    class FakeCPU:
        def bh_getfield_gc_r(self, gcref, fielddescr):
            assert fielddescr == mutatefielddescr
            foo = lltype.cast_opaque_ptr(lltype.Ptr(STRUCT), gcref)
            result = foo.mutate_x
            return lltype.cast_opaque_ptr(llmemory.GCREF, result)

        def bh_setfield_gc_r(self, gcref, newvalue_gcref, fielddescr):
            assert fielddescr == mutatefielddescr
            foo = lltype.cast_opaque_ptr(lltype.Ptr(STRUCT), gcref)
            newvalue = lltype.cast_opaque_ptr(rclass.OBJECTPTR, newvalue_gcref)
            foo.mutate_x = newvalue

    cpu = FakeCPU()
    mutatefielddescr = ('fielddescr', STRUCT, 'mutate_x')

    foo_gcref = lltype.cast_opaque_ptr(llmemory.GCREF, foo)
    qmut1 = get_current_qmut_instance(cpu, foo_gcref, mutatefielddescr)
    assert isinstance(qmut1, QuasiImmut)
    qmut2 = get_current_qmut_instance(cpu, foo_gcref, mutatefielddescr)
    assert qmut1 is qmut2


class QuasiImmutTests(object):

    def setup_method(self, meth):
        self.prev_compress_limit = QuasiImmut.compress_limit
        QuasiImmut.compress_limit = 1

    def teardown_method(self, meth):
        QuasiImmut.compress_limit = self.prev_compress_limit

    def test_simple_1(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7])
        assert res == 700
        self.check_resops(guard_not_invalidated=2)
        #
        from rpython.jit.metainterp.warmspot import get_stats
        loops = get_stats().loops
        for loop in loops:
            assert len(loop.quasi_immutable_deps) == 1
            assert isinstance(loop.quasi_immutable_deps.keys()[0], QuasiImmut)

    def test_simple_optimize_during_tracing(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7], enable_opts="")
        assert res == 700
        # there should be no getfields, even though optimizations are turned off
        self.check_resops(guard_not_invalidated=1)

    def test_nonopt_1(self):
        myjitdriver = JitDriver(greens=[], reds=['x', 'total', 'lst'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        def setup(x):
            return [Foo(100 + i) for i in range(x)]
        def f(a, x):
            lst = setup(x)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(lst=lst, x=x, total=total)
                # read a quasi-immutable field out of a variable
                x -= 1
                total += lst[x].a
            return total
        #
        assert f(100, 7) == 721
        res = self.meta_interp(f, [100, 7])
        assert res == 721
        self.check_resops(guard_not_invalidated=2, getfield_gc_r=1, getfield_gc_i=2)
        #
        from rpython.jit.metainterp.warmspot import get_stats
        loops = get_stats().loops
        for loop in loops:
            assert loop.quasi_immutable_deps is None

    def test_opt_via_virtual_1(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        class A:
            pass
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # make it a Constant after optimization only
                a = A()
                a.foo = foo
                foo = a.foo
                # read a quasi-immutable field out of it
                total += foo.a
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7])
        assert res == 700
        self.check_resops(guard_not_invalidated=2)

    def test_change_during_tracing_1(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        @dont_look_inside
        def residual_call(foo):
            foo.a += 1
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                residual_call(foo)
                x -= 1
            return total

        assert f(100, 7) == 721
        res = self.meta_interp(f, [100, 7])
        assert res == 721
        # the loop is invalid, so nothing is traced
        self.check_aborted_count(2)

    def test_change_during_tracing_2(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        @dont_look_inside
        def residual_call(foo, difference):
            foo.a += difference
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                residual_call(foo, +1)
                residual_call(foo, -1)
                x -= 1
            return total
        #
        assert f(100, 7) == 700
        res = self.meta_interp(f, [100, 7])
        assert res == 700
        self.check_resops(guard_not_invalidated=0)

    def test_change_invalidate_reentering(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        def f(foo, x):
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                x -= 1
            return total
        def g(a, x):
            foo = Foo(a)
            res1 = f(foo, x)
            foo.a += 1          # invalidation, while the jit is not running
            res2 = f(foo, x)    # should still mark the loop as invalid
            return res1 * 1000 + res2
        #
        assert g(100, 7) == 700707
        res = self.meta_interp(g, [100, 7])
        assert res == 700707
        self.check_resops(guard_not_invalidated=4)

    def test_invalidate_while_running(self):
        jitdriver = JitDriver(greens=['foo'], reds=['i', 'total'])

        class Foo(object):
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a

        def external(foo, v):
            if v:
                foo.a = 2

        def f(foo):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point(i=i, foo=foo, total=total)
                external(foo, i > 7)
                i += 1
                total += foo.a
            return total

        def g():
            return f(Foo(1))

        assert self.meta_interp(g, [], policy=StopAtXPolicy(external)) == g()

    def test_invalidate_by_setfield(self):
        jitdriver = JitDriver(greens=['bc', 'foo'], reds=['i', 'total'])

        class Foo(object):
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a

        def f(foo, bc):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point(bc=bc, i=i, foo=foo, total=total)
                if bc == 0:
                    f(foo, 1)
                if bc == 1:
                    foo.a = int(i > 5)
                i += 1
                total += foo.a
            return total

        def g():
            return f(Foo(1), 0)

        assert self.meta_interp(g, []) == g()

    def test_invalidate_bridge(self):
        jitdriver = JitDriver(greens=['foo'], reds=['i', 'total'])

        class Foo(object):
            _immutable_fields_ = ['a?']

        def f(foo):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point(i=i, total=total, foo=foo)
                if i > 5:
                    total += foo.a
                else:
                    total += 2*foo.a
                i += 1
            return total

        def main():
            foo = Foo()
            foo.a = 1
            total = f(foo)
            foo.a = 2
            total += f(foo)
            foo.a = 1
            total += f(foo)
            return total

        res = self.meta_interp(main, [])
        self.check_trace_count(6)
        self.check_jitcell_token_count(3)
        assert res == main()

    def test_change_during_running(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?']
            def __init__(self, a):
                self.a = a
        @dont_look_inside
        def residual_call(foo, x):
            if x == 10:
                foo.a += 1
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                residual_call(foo, x)
                total += foo.a
                x -= 1
            return total
        #
        assert f(100, 30) == 6019
        res = self.meta_interp(f, [100, 30])
        assert res == 6019
        self.check_resops(guard_not_invalidated=8, guard_not_forced=0,
                          call_may_force=0)

    def test_list_simple_1(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            def __init__(self, lst):
                self.lst = lst
        def f(a, x):
            lst1 = [0, 0]
            lst1[1] = a
            foo = Foo(lst1)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.lst[1]
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7])
        assert res == 700
        self.check_resops(getarrayitem_gc_pure_i=0, guard_not_invalidated=2,
                          getarrayitem_gc_pure_r=0,
                          getarrayitem_gc_i=0,
                          getarrayitem_gc_r=0,
                          getfield_gc_i=0, getfield_gc_r=0)
        #
        from rpython.jit.metainterp.warmspot import get_stats
        loops = get_stats().loops
        for loop in loops:
            assert len(loop.quasi_immutable_deps) == 1
            assert isinstance(loop.quasi_immutable_deps.keys()[0], QuasiImmut)

    def test_list_optimized_while_tracing(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            def __init__(self, lst):
                self.lst = lst
        def f(a, x):
            lst1 = [0, 0]
            lst1[1] = a
            foo = Foo(lst1)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.lst[1]
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7], enable_opts="")
        assert res == 700
        # operations must have been removed by the frontend
        self.check_resops(getarrayitem_gc_pure_i=0, guard_not_invalidated=1,
                          getarrayitem_gc_i=0, getfield_gc_i=0, getfield_gc_r=0)

    def test_list_length_1(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            def __init__(self, lst):
                self.lst = lst
        class A:
            pass
        def f(a, x):
            lst1 = [0, 0]
            lst1[1] = a
            foo = Foo(lst1)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # make it a Constant after optimization only
                a = A()
                a.foo = foo
                foo = a.foo
                # read a quasi-immutable field out of it
                total += foo.lst[1]
                # also read the length
                total += len(foo.lst)
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7])
        assert res == 714
        self.check_resops(getarrayitem_gc_pure=0, guard_not_invalidated=2,
                          arraylen_gc=0, getarrayitem_gc=0, getfield_gc=0)
        #
        from rpython.jit.metainterp.warmspot import get_stats
        loops = get_stats().loops
        for loop in loops:
            assert len(loop.quasi_immutable_deps) == 1
            assert isinstance(loop.quasi_immutable_deps.keys()[0], QuasiImmut)

    def test_list_pass_around(self):
        py.test.skip("think about a way to fix it")
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            def __init__(self, lst):
                self.lst = lst
        def g(lst):
            # here, 'lst' is statically annotated as a "modified" list,
            # so the following doesn't generate a getarrayitem_gc_pure...
            return lst[1]
        def f(a, x):
            lst1 = [0, 0]
            g(lst1)
            lst1[1] = a
            foo = Foo(lst1)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += g(foo.lst)
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7])
        assert res == 700
        self.check_resops(guard_not_invalidated=2, getfield_gc=0,
                          getarrayitem_gc=0, getarrayitem_gc_pure=0)
        #
        from rpython.jit.metainterp.warmspot import get_stats
        loops = get_stats().loops
        for loop in loops:
            assert len(loop.quasi_immutable_deps) == 1
            assert isinstance(loop.quasi_immutable_deps.keys()[0], QuasiImmut)

    def test_list_change_during_running(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['lst?[*]']
            def __init__(self, lst):
                self.lst = lst
        @dont_look_inside
        def residual_call(foo, x):
            if x == 10:
                lst2 = [0, 0]
                lst2[1] = foo.lst[1] + 1
                foo.lst = lst2
        def f(a, x):
            lst1 = [0, 0]
            lst1[1] = a
            foo = Foo(lst1)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.lst[1]
                residual_call(foo, x)
                total += foo.lst[1]
                x -= 1
            return total
        #
        assert f(100, 30) == 6019
        res = self.meta_interp(f, [100, 30])
        assert res == 6019
        self.check_resops(call_may_force=0, getfield_gc=0,
                          getarrayitem_gc_pure=0, guard_not_forced=0,
                          getarrayitem_gc=0, guard_not_invalidated=8)

    def test_invalidated_loop_is_not_used_any_more_as_target(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x'])
        class Foo:
            _immutable_fields_ = ['step?']
        @dont_look_inside
        def residual(x, foo):
            if x == 20:
                foo.step = 1
        def f(x):
            foo = Foo()
            foo.step = 2
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x)
                residual(x, foo)
                x -= foo.step
            return foo.step
        res = self.meta_interp(f, [60])
        assert res == 1
        self.check_jitcell_token_count(2)

    def test_for_loop_array(self):
        myjitdriver = JitDriver(greens=[], reds=["n", "i"])
        class Foo(object):
            _immutable_fields_ = ["x?[*]"]
            def __init__(self, x):
                self.x = x
        f = Foo([1, 3, 5, 6])
        @unroll_safe
        def g(v):
            for x in f.x:
                if x & 1 == 0:
                    v += 1
            return v
        def main(n):
            i = 0
            while i < n:
                myjitdriver.jit_merge_point(n=n, i=i)
                i = g(i)
            return i
        res = self.meta_interp(main, [10])
        assert res == 10
        self.check_resops({
            "int_add": 2, "int_lt": 2, "jump": 1, "guard_true": 2,
            "guard_not_invalidated": 2
        })

    def test_issue1080(self):
        myjitdriver = JitDriver(greens=[], reds=["n", "sa", "a"])
        class Foo(object):
            _immutable_fields_ = ["x?"]
            def __init__(self, x):
                self.x = x
        one, two = Foo(1), Foo(2)
        def main(n):
            sa = 0
            a = one
            while n:
                myjitdriver.jit_merge_point(n=n, sa=sa, a=a)
                sa += a.x
                if a.x == 1:
                    a = two
                elif a.x == 2:
                    a = one
                n -= 1
            return sa
        res = self.meta_interp(main, [10])
        assert res == main(10)

    def test_dont_emit_too_many_guard_not_invalidated(self):
        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'])
        class Foo:
            _immutable_fields_ = ['a?', 'b?', 'c?']
            def __init__(self, a):
                self.a = a
                self.b = a - 1
                self.c = a - 3
        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a few quasi-immutable fields out of a Constant
                total += foo.a + foo.b + foo.c
                x -= 1
            return total
        #
        res = self.meta_interp(f, [100, 7], enable_opts="")
        assert res == f(100, 7)
        # there should be no getfields, even though optimizations are turned off
        self.check_resops(guard_not_invalidated=1)


class TestLLtypeGreenFieldsTests(QuasiImmutTests, LLJitMixin):
    pass
