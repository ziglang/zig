
from rpython.jit.metainterp.test.test_list import ListTests
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class TestList(JitAarch64Mixin, ListTests):
    # for individual tests see
    # ====> ../../../metainterp/test/test_list.py
    pass
