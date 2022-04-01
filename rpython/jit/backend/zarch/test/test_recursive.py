from rpython.jit.metainterp.test.test_recursive import RecursiveTests
from rpython.jit.backend.zarch.test.support import JitZARCHMixin

class TestRecursive(JitZARCHMixin, RecursiveTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_recursive.py
    pass
