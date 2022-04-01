
from rpython.jit.metainterp.test.test_list import ListTests
from rpython.jit.backend.ppc.test.support import JitPPCMixin

class TestList(JitPPCMixin, ListTests):
    # for individual tests see
    # ====> ../../../metainterp/test/test_list.py
    pass
