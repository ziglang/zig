from rpython.jit.metainterp.test.test_virtual import VirtualTests, VirtualMiscTests
from rpython.jit.backend.arm.test.support import JitARMMixin

class MyClass:
    pass

class TestsVirtual(JitARMMixin, VirtualTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    _new_op = 'new_with_vtable'
    _field_prefix = 'inst_'
    
    @staticmethod
    def _new():
        return MyClass()

class TestsVirtualMisc(JitARMMixin, VirtualMiscTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    pass
