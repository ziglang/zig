
import py
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test.test_float import FloatTests
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()
class TestFloat(JitPPCMixin, FloatTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_float.py
    if not CPU.supports_singlefloats:
        def test_singlefloat(self):
            py.test.skip('requires singlefloats')
