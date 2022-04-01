
from rpython.jit.metainterp.test.test_virtualref import VRefTests
from rpython.jit.backend.arm.test.support import JitARMMixin

class TestVRef(JitARMMixin, VRefTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtualref.py
    pass
