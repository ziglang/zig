
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test.test_del import DelTests

class TestDel(JitARMMixin, DelTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_del.py
    pass
