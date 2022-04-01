import py, pytest

from rpython.conftest import option
from rpython.annotator.model import UnionError
from rpython.rlib.jit import (hint, we_are_jitted, JitDriver, elidable_promote,
    JitHintError, oopspec, isconstant, conditional_call,
    elidable, unroll_safe, dont_look_inside, conditional_call_elidable,
    enter_portal_frame, leave_portal_frame)
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem import lltype
from rpython.translator.translator import TranslationContext
from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
from rpython.annotator import model as annmodel


def test_oopspec():
    @oopspec('foobar')
    def fn():
        pass
    assert fn.oopspec == 'foobar'

def test_jitdriver_autoreds():
    driver = JitDriver(greens=['foo'], reds='auto')
    assert driver.autoreds
    assert driver.reds == []
    assert driver.numreds is None
    py.test.raises(TypeError, "driver.can_enter_jit(foo='something')")
    py.test.raises(AssertionError, "JitDriver(greens=['foo'], reds='auto', confirm_enter_jit='something')")

def test_jitdriver_numreds():
    driver = JitDriver(greens=['foo'], reds=['a', 'b'])
    assert driver.reds == ['a', 'b']
    assert driver.numreds == 2
    #
    class MyJitDriver(JitDriver):
        greens = ['foo']
        reds = ['a', 'b']
    driver = MyJitDriver()
    assert driver.reds == ['a', 'b']
    assert driver.numreds == 2

def test_jitdriver_inline():
    py.test.skip("@inline off: see skipped failures in test_warmspot.")
    driver = JitDriver(greens=[], reds='auto')
    calls = []
    def foo(a, b):
        calls.append(('foo', a, b))

    @driver.inline(foo)
    def bar(a, b):
        calls.append(('bar', a, b))
        return a+b

    assert bar._inline_jit_merge_point_ is foo
    assert driver.inline_jit_merge_point
    assert bar(40, 2) == 42
    assert calls == [
        ('foo', 40, 2),
        ('bar', 40, 2),
        ]

def test_jitdriver_clone():
    py.test.skip("@inline off: see skipped failures in test_warmspot.")
    def bar(): pass
    def foo(): pass
    driver = JitDriver(greens=[], reds=[])
    py.test.raises(AssertionError, "driver.inline(bar)(foo)")
    #
    driver = JitDriver(greens=[], reds='auto')
    py.test.raises(AssertionError, "driver.clone()")
    foo = driver.inline(bar)(foo)
    assert foo._inline_jit_merge_point_ == bar
    #
    driver.foo = 'bar'
    driver2 = driver.clone()
    assert driver is not driver2
    assert driver2.foo == 'bar'
    driver.foo = 'xxx'
    assert driver2.foo == 'bar'


def test_merge_enter_different():
    myjitdriver = JitDriver(greens=[], reds=['n'])
    def fn(n):
        while n > 0:
            myjitdriver.jit_merge_point(n=n)
            myjitdriver.can_enter_jit(n=n)
            n -= 1
        return n
    py.test.raises(JitHintError, fn, 100)

    myjitdriver = JitDriver(greens=['n'], reds=[])
    py.test.raises(JitHintError, fn, 100)

def test_invalid_hint_combinations_error():
    with pytest.raises(TypeError):
        @unroll_safe
        @elidable
        def f():
            pass
    with pytest.raises(TypeError):
        @unroll_safe
        @elidable
        def f():
            pass
    with pytest.raises(TypeError):
        @unroll_safe
        @dont_look_inside
        def f():
            pass
    with pytest.raises(TypeError):
        @unroll_safe
        @dont_look_inside
        def f():
            pass

class TestJIT(BaseRtypingTest):
    def test_hint(self):
        def f():
            x = hint(5, hello="world")
            return x
        res = self.interpret(f, [])
        assert res == 5

    def test_we_are_jitted(self):
        def f(x):
            try:
                if we_are_jitted():
                    return x
                return x + 1
            except Exception:
                return 5
        res = self.interpret(f, [4])
        assert res == 5

    def test_elidable_promote(self):
        @elidable_promote()
        def g(func):
            return func + 1
        def f(x):
            return g(x * 2)
        res = self.interpret(f, [2])
        assert res == 5

    def test_elidable_promote_args(self):
        @elidable_promote(promote_args='0')
        def g(func, x):
            return func + 1
        def f(x):
            return g(x * 2, x)

        import dis
        from StringIO import StringIO
        import sys

        s = StringIO()
        prev = sys.stdout
        sys.stdout = s
        try:
            dis.dis(g)
        finally:
            sys.stdout = prev
        x = s.getvalue().find('CALL_FUNCTION')
        assert x != -1
        x = s.getvalue().find('CALL_FUNCTION', x)
        assert x != -1
        x = s.getvalue().find('CALL_FUNCTION', x)
        assert x != -1
        res = self.interpret(f, [2])
        assert res == 5

    def test_annotate_hooks(self):

        def get_printable_location(m): pass

        myjitdriver = JitDriver(greens=['m'], reds=['n'],
                                get_printable_location=get_printable_location)
        def fn(n):
            m = 42.5
            while n > 0:
                myjitdriver.can_enter_jit(m=m, n=n)
                myjitdriver.jit_merge_point(m=m, n=n)
                n -= 1
            return n

        t, rtyper, fngraph = self.gengraph(fn, [int])

        # added by compute_result_annotation()
        assert fn._dont_reach_me_in_del_ == True

        def getargs(func):
            for graph in t.graphs:
                if getattr(graph, 'func', None) is func:
                    return [v.concretetype for v in graph.getargs()]
            raise Exception('function %r has not been annotated' % func)

        get_printable_location_args = getargs(get_printable_location)
        assert get_printable_location_args == [lltype.Float]

    def test_annotate_argumenterror(self):
        myjitdriver = JitDriver(greens=['m'], reds=['n'])
        def fn(n):
            while n > 0:
                myjitdriver.can_enter_jit(m=42.5, n=n)
                myjitdriver.jit_merge_point(n=n)
                n -= 1
            return n
        py.test.raises(JitHintError, self.gengraph, fn, [int])

    def test_annotate_typeerror(self):
        myjitdriver = JitDriver(greens=['m'], reds=['n'])
        class A(object):
            pass
        class B(object):
            pass
        def fn(n):
            while n > 0:
                myjitdriver.can_enter_jit(m=A(), n=n)
                myjitdriver.jit_merge_point(m=B(), n=n)
                n -= 1
            return n
        py.test.raises(UnionError, self.gengraph, fn, [int])

    def test_green_field(self):
        def get_printable_location(xfoo):
            return str(ord(xfoo))   # xfoo must be annotated as a character
        # green fields are disabled!
        pytest.raises(ValueError, JitDriver, greens=['x.foo'], reds=['n', 'x'],
                                get_printable_location=get_printable_location)
        return
        class A(object):
            _immutable_fields_ = ['foo']
        def fn(n):
            x = A()
            x.foo = chr(n)
            while n > 0:
                myjitdriver.can_enter_jit(x=x, n=n)
                myjitdriver.jit_merge_point(x=x, n=n)
                n -= 1
            return n
        t = self.gengraph(fn, [int])[0]
        if option.view:
            t.view()
        # assert did not raise

    def test_isconstant(self):
        def f(n):
            assert isconstant(n) is False
            l = []
            l.append(n)
            return len(l)
        res = self.interpret(f, [-234])
        assert res == 1

    def test_argument_order_ok(self):
        myjitdriver = JitDriver(greens=['i1', 'r1', 'f1'], reds=[])
        class A(object):
            pass
        myjitdriver.jit_merge_point(i1=42, r1=A(), f1=3.5)
        # assert did not raise

    def test_argument_order_wrong(self):
        myjitdriver = JitDriver(greens=['r1', 'i1', 'f1'], reds=[])
        class A(object):
            pass
        e = py.test.raises(AssertionError,
                   myjitdriver.jit_merge_point, i1=42, r1=A(), f1=3.5)

    def test_argument_order_more_precision_later(self):
        myjitdriver = JitDriver(greens=['r1', 'i1', 'r2', 'f1'], reds=[])
        class A(object):
            pass
        myjitdriver.jit_merge_point(i1=42, r1=None, r2=None, f1=3.5)
        e = py.test.raises(AssertionError,
                   myjitdriver.jit_merge_point, i1=42, r1=A(), r2=None, f1=3.5)
        assert "got ['2:REF', '1:INT', '?', '3:FLOAT']" in repr(e.value)

    def test_argument_order_more_precision_later_2(self):
        myjitdriver = JitDriver(greens=['r1', 'i1', 'r2', 'f1'], reds=[])
        class A(object):
            pass
        myjitdriver.jit_merge_point(i1=42, r1=None, r2=A(), f1=3.5)
        e = py.test.raises(AssertionError,
                   myjitdriver.jit_merge_point, i1=42, r1=A(), r2=None, f1=3.5)
        assert "got ['2:REF', '1:INT', '2:REF', '3:FLOAT']" in repr(e.value)

    def test_argument_order_accept_r_uint(self):
        # this used to fail on 64-bit, because r_uint == r_ulonglong
        myjitdriver = JitDriver(greens=['i1'], reds=[])
        myjitdriver.jit_merge_point(i1=r_uint(42))

    def test_conditional_call(self):
        def g():
            pass
        def f(n):
            conditional_call(n >= 0, g)
        def later(m):
            conditional_call(m, g)
        t = TranslationContext()
        t.buildannotator().build_types(f, [int])
        t.buildrtyper().specialize()
        mix = MixLevelHelperAnnotator(t.rtyper)
        mix.getgraph(later, [annmodel.s_Bool], annmodel.s_None)
        mix.finish()

    def test_conditional_call_elidable(self):
        def g(x, y):
            return x - y + 5
        def f(n, x, y):
            return conditional_call_elidable(n, g, x, y)
        assert f(0, 1000, 100) == 905
        res = self.interpret(f, [0, 1000, 100])
        assert res == 905
        assert f(-42, 1000, 100) == -42
        res = self.interpret(f, [-42, 1000, 100])
        assert res == -42

    def test_conditional_call_elidable_annotates_nonnull(self):
        class X:
            pass
        def g(n):
            return X()   # non-null
        def f(x, n):
            y = conditional_call_elidable(x, g, n)
            return y     # now, y is known to be non-null, even if x can be
        def main(n):
            if n > 100:
                x = X()
            else:
                x = None
            return f(x, n)
        t = TranslationContext()
        s = t.buildannotator().build_types(main, [int])
        assert s.can_be_None is False

    def test_enter_leave_portal_frame(self):
        from rpython.translator.interactive import Translation
        def g():
            enter_portal_frame(1)
            leave_portal_frame()
        t = Translation(g, [])
        t.compile_c() # does not crash
