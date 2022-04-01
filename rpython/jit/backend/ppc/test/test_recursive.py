
from rpython.jit.metainterp.test.test_recursive import RecursiveTests
from rpython.jit.backend.ppc.test.support import JitPPCMixin

class TestRecursive(JitPPCMixin, RecursiveTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_recursive.py
    pass
