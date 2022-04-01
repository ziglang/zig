from rpython.jit.metainterp.test.test_virtual import VirtualTests, VirtualMiscTests
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin

class MyClass:
    pass

class TestsVirtual(Jit386Mixin, VirtualTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    _new_op = 'new_with_vtable'
    _field_prefix = 'inst_'
    
    @staticmethod
    def _new():
        return MyClass()

class TestsVirtualMisc(Jit386Mixin, VirtualMiscTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    pass
