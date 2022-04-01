
import py
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test.test_float import FloatTests

class TestFloat(Jit386Mixin, FloatTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_float.py
    pass
