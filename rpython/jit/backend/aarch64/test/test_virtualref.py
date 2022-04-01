
from rpython.jit.metainterp.test.test_virtualref import VRefTests
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class TestVRef(JitAarch64Mixin, VRefTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtualref.py
    pass
