
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test.test_rawmem import RawMemTests


class TestRawMem(JitAarch64Mixin, RawMemTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_rawmem.py
    pass
