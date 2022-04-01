
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test.test_del import DelTests

class TestDel(Jit386Mixin, DelTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_del.py
    pass
