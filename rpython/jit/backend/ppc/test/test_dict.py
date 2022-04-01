
from rpython.jit.backend.ppc.test.support import JitPPCMixin
from rpython.jit.metainterp.test.test_dict import DictTests


class TestDict(JitPPCMixin, DictTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_dict.py
    pass
