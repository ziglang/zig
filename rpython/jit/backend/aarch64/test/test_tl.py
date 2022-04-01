
import py
from rpython.jit.metainterp.test.test_tl import ToyLanguageTests
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class TestTL(JitAarch64Mixin, ToyLanguageTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_tl.py
    pass

