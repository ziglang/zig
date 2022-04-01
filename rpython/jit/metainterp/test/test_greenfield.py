import pytest
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.jit import JitDriver, assert_green

pytest.skip("this feature is disabled at the moment!")

# note why it is disabled: before d721da4573ad
# there was a failing assert when inlining python -> sre -> python:
# https://foss.heptapod.net/pypy/pypy/-/issues/2775
# this shows, that the interaction of greenfields and virtualizables is broken,
# because greenfields use MetaInterp.virtualizable_boxes, which confuses
# MetaInterp._nonstandard_virtualizable somehow (and makes no sense
# conceptually anyway). to fix greenfields, the two mechanisms would have to be
# disentangled.

class GreenFieldsTests:

    def test_green_field_1(self):
        myjitdriver = JitDriver(greens=['ctx.x'], reds=['ctx'])
        class Ctx(object):
            _immutable_fields_ = ['x']
            def __init__(self, x, y):
                self.x = x
                self.y = y
        def f(x, y):
            ctx = Ctx(x, y)
            while 1:
                myjitdriver.can_enter_jit(ctx=ctx)
                myjitdriver.jit_merge_point(ctx=ctx)
                ctx.y -= 1
                if ctx.y < 0:
                    return ctx.y
        def g(y):
            return f(5, y) + f(6, y)
        #
        res = self.meta_interp(g, [7])
        assert res == -2
        self.check_trace_count(2)
        self.check_resops(guard_value=0)

    def test_green_field_2(self):
        myjitdriver = JitDriver(greens=['ctx.x'], reds=['ctx'])
        class Ctx(object):
            _immutable_fields_ = ['x']
            def __init__(self, x, y):
                self.x = x
                self.y = y
        def f(x, y):
            ctx = Ctx(x, y)
            while 1:
                myjitdriver.can_enter_jit(ctx=ctx)
                myjitdriver.jit_merge_point(ctx=ctx)
                ctx.y -= 1
                if ctx.y < 0:
                    pass     # to just make two paths
                if ctx.y < -10:
                    return ctx.y
        def g(y):
            return f(5, y) + f(6, y)
        #
        res = self.meta_interp(g, [7])
        assert res == -22
        self.check_trace_count(4)
        self.check_resops(guard_value=0)

    def test_green_field_3(self):
        myjitdriver = JitDriver(greens=['ctx.x'], reds=['ctx'])
        class Ctx(object):
            _immutable_fields_ = ['x']
            def __init__(self, x, y):
                self.x = x
                self.y = y
        def f(x, y):
            ctx = Ctx(x, y)
            while ctx.y > 0:
                myjitdriver.can_enter_jit(ctx=ctx)
                myjitdriver.jit_merge_point(ctx=ctx)
                assert_green(ctx.x)
                ctx.y -= ctx.x
            return -2100
        def g():
            return f(5, 35) + f(6, 42)
        #
        res = self.meta_interp(g, [])
        assert res == -4200


class TestLLtypeGreenFieldsTests(GreenFieldsTests, LLJitMixin):
    pass
