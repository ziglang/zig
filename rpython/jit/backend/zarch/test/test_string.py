import py
from rpython.jit.metainterp.test import test_string
from rpython.jit.backend.zarch.test.support import JitZARCHMixin

class TestString(JitZARCHMixin, test_string.TestLLtype):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass

class TestUnicode(JitZARCHMixin, test_string.TestLLtypeUnicode):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass
