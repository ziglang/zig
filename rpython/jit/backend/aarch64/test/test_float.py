
import py
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test.test_float import FloatTests

class TestFloat(JitAarch64Mixin, FloatTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_float.py
    pass
