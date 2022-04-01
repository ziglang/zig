
import py
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin
from rpython.jit.metainterp.test import test_quasiimmut

class TestLoopSpec(JitAarch64Mixin, test_quasiimmut.QuasiImmutTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_loop.py
    pass
