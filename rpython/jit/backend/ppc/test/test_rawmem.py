
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test.test_rawmem import RawMemTests


class TestRawMem(JitPPCMixin, RawMemTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_rawmem.py
    pass
