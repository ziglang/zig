
import py
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test import test_quasiimmut

class TestLoopSpec(Jit386Mixin, test_quasiimmut.QuasiImmutTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
