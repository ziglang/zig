
from rpython.jit.metainterp.test.test_virtualref import VRefTests
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin

class TestVRef(Jit386Mixin, VRefTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtualref.py
    pass
