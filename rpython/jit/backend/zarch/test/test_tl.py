import py
from rpython.jit.metainterp.test.test_tl import ToyLanguageTests
from rpython.jit.backend.zarch.test.support import JitZARCHMixin

class TestTL(JitZARCHMixin, ToyLanguageTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_tl.py
    pass

