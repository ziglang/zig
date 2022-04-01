import py
from rpython.jit.metainterp.test import test_slist
from rpython.jit.backend.arm.test.support import JitARMMixin

class TestSList(JitARMMixin, test_slist.ListTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_slist.py
    def test_list_of_voids(self):
        py.test.skip("list of voids unsupported by ll2ctypes")
