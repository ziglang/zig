import py
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test import test_loop_unroll

class TestLoopSpec(JitARMMixin, test_loop_unroll.LoopUnrollTest):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
