
import py
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test import test_quasiimmut

class TestLoopSpec(JitPPCMixin, test_quasiimmut.QuasiImmutTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
