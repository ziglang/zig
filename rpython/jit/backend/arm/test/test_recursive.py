
from rpython.jit.metainterp.test.test_recursive import RecursiveTests
from rpython.jit.backend.arm.test.support import JitARMMixin

class TestRecursive(JitARMMixin, RecursiveTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_recursive.py
    pass
