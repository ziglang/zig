from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test import test_call

class TestCall(Jit386Mixin, test_call.CallTest):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_call.py
    pass
