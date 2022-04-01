
from rpython.jit.backend.llsupport.test.zrpy_vmprof_test import CompiledVmprofTest

class TestZVMprof(CompiledVmprofTest):
    
    gcrootfinder = "shadowstack"
    gc = "incminimark"