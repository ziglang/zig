import py
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.rlib.jit import JitDriver
from rpython.jit.metainterp.test import test_ajit
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()

class TestBasic(JitPPCMixin, test_ajit.BaseLLtypeTests):
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

    def test_r_dict(self):
        # a Struct that belongs to the hash table is not seen as being
        # included in the larger Array
        py.test.skip("issue with ll2ctypes")

    def test_free_object(self):
        py.test.skip("issue of freeing, probably with ll2ctypes")

    if not CPU.supports_longlong:
        def test_read_timestamp(self):
            py.test.skip('requires longlong')
