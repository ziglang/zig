import py
from rpython.jit.metainterp.test import test_string
from rpython.jit.backend.ppc.test.support import JitPPCMixin

class TestString(JitPPCMixin, test_string.TestLLtype):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass

class TestUnicode(JitPPCMixin, test_string.TestLLtypeUnicode):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass
