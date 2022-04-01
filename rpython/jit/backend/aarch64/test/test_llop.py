from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test.test_llop import TestLLOp as _TestLLOp


class TestLLOp(JitAarch64Mixin, _TestLLOp):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_llop.py

    # do NOT test the blackhole implementation of gc_store_indexed. It cannot
    # work inside tests because llmodel.py:bh_gc_store_indexed_* receive a
    # symbolic as the offset. It is not a problem because it is tested anyway
    # by the same test in test_metainterp.py
    TEST_BLACKHOLE = False

