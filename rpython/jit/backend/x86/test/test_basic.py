import py
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.warmspot import ll_meta_interp
from rpython.jit.metainterp.test import support, test_ajit
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.rlib.jit import JitDriver

class Jit386Mixin(support.LLJitMixin):
    CPUClass = getcpuclass()
    # we have to disable unroll
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap"
    basic = False

    def check_jumps(self, maxcount):
        pass

class TestBasic(Jit386Mixin, test_ajit.BaseLLtypeTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_ajit.py
    def test_bug(self):
        jitdriver = JitDriver(greens = [], reds = ['n'])
        class X(object):
            pass
        def f(n):
            while n > -100:
                jitdriver.can_enter_jit(n=n)
                jitdriver.jit_merge_point(n=n)
                x = X()
                x.arg = 5
                if n <= 0: break
                n -= x.arg
                x.arg = 6   # prevents 'x.arg' from being annotated as constant
            return n
        res = self.meta_interp(f, [31], enable_opts='')
        assert res == -4

    def test_free_object(self):
        py.test.skip("issue of freeing, probably with ll2ctypes")
