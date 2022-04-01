
import py
from rpython.jit.metainterp.test.test_tl import ToyLanguageTests
from rpython.jit.backend.arm.test.support import JitARMMixin

class TestTL(JitARMMixin, ToyLanguageTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_tl.py
    pass

