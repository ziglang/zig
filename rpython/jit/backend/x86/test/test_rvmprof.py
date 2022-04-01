from rpython.jit.backend.x86.arch import WIN64
from rpython.jit.backend.test.test_rvmprof import BaseRVMProfTest
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin

if WIN64:
    import py; py.test.skip("no rvmprof support on Win64 so far")

class TestRVMProfCall(Jit386Mixin, BaseRVMProfTest):
    pass
