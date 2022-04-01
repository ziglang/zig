from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test.test_llop import TestLLOp as _TestLLOp


class TestLLOp(Jit386Mixin, _TestLLOp):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_llop.py

    # do NOT test the blackhole implementation of gc_store_indexed. It cannot
    # work inside tests because llmodel.py:bh_gc_store_indexed_* receive a
    # symbolic as the offset. It is not a problem because it is tested anyway
    # by the same test in test_metainterp.py
    TEST_BLACKHOLE = False

