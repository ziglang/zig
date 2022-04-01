from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test import test_call

class TestCall(JitAarch64Mixin, test_call.CallTest):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_call.py
    pass
