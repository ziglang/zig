
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test.test_del import DelTests

class TestDel(JitPPCMixin, DelTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_del.py
    pass
