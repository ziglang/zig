
import py
from rpython.jit.metainterp.test.test_tl import ToyLanguageTests
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin

class TestTL(Jit386Mixin, ToyLanguageTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_tl.py
    pass

