
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test.test_rawmem import RawMemTests


class TestRawMem(JitARMMixin, RawMemTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_rawmem.py
    pass
