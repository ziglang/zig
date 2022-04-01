
from rpython.jit.backend.zarch.test.support import JitZARCHMixin
from rpython.jit.metainterp.test.test_del import DelTests

class TestDel(JitZARCHMixin, DelTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_del.py
    pass
