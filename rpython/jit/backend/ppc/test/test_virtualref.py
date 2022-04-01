
from rpython.jit.metainterp.test.test_virtualref import VRefTests
from rpython.jit.backend.ppc.test.support import JitPPCMixin

class TestVRef(JitPPCMixin, VRefTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtualref.py
    pass
