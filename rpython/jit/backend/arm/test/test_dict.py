
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test.test_dict import DictTests


class TestDict(JitARMMixin, DictTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_dict.py
    pass
