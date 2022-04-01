
from rpython.jit.backend.zarch.test.support import JitZARCHMixin
from rpython.jit.metainterp.test.test_dict import DictTests


class TestDict(JitZARCHMixin, DictTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_dict.py
    pass
