
from rpython.jit.metainterp.test.test_virtualref import VRefTests
from rpython.jit.backend.zarch.test.support import JitZARCHMixin

class TestVRef(JitZARCHMixin, VRefTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtualref.py
    pass
