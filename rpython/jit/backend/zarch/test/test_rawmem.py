
from rpython.jit.backend.zarch.test.support import JitZARCHMixin
from rpython.jit.metainterp.test.test_rawmem import RawMemTests


class TestRawMem(JitZARCHMixin, RawMemTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_rawmem.py
    pass
