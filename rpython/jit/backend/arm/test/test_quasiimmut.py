
import py
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test import test_quasiimmut

class TestLoopSpec(JitARMMixin, test_quasiimmut.QuasiImmutTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
