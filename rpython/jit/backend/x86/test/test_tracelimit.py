
from rpython.jit.metainterp.test.test_tracelimit import TraceLimitTests
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin

class TestTraceLimit(Jit386Mixin, TraceLimitTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_tracelimit.py
    pass
