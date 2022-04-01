import py
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test import test_loop_unroll

class TestLoopSpec(JitPPCMixin, test_loop_unroll.LoopUnrollTest):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
