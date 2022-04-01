
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test.test_del import DelTests

class TestDel(JitAarch64Mixin, DelTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_del.py
    pass
