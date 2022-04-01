import py
from rpython.jit.backend.zarch.test.support import JitZARCHMixin
from rpython.jit.metainterp.test.test_float import FloatTests
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()
class TestFloat(JitZARCHMixin, FloatTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_float.py
    if not CPU.supports_singlefloats:
        def test_singlefloat(self):
            py.test.skip('requires singlefloats')
