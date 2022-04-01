import py
from rpython.jit.backend.zarch.test.support import JitZARCHMixin
from rpython.jit.metainterp.test import test_loop_unroll

class TestLoopSpec(JitZARCHMixin, test_loop_unroll.LoopUnrollTest):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
