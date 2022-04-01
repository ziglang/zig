from rpython.jit.backend.x86.arch import WIN64
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.backend.test.jitlog_test import LoggerTest

if WIN64:
    import py; py.test.skip("test_jitlog not tested so far (can't make sense of the failure)")

class TestJitlog(Jit386Mixin, LoggerTest):
    # for the individual tests see
    # ====> ../../../test/jitlog_test.py
    pass
