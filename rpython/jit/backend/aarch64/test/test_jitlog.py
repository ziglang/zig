
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.backend.test.jitlog_test import LoggerTest

class TestJitlog(JitAarch64Mixin, LoggerTest):
    # for the individual tests see
    # ====> ../../../test/jitlog_test.py
    pass
