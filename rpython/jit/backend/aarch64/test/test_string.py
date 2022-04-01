import py
from rpython.jit.metainterp.test import test_string
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class TestString(JitAarch64Mixin, test_string.TestLLtype):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass

class TestUnicode(JitAarch64Mixin, test_string.TestLLtypeUnicode):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_string.py
    pass
