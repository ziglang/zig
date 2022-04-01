from rpython.jit.metainterp.test.test_virtual import VirtualTests, VirtualMiscTests
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class MyClass:
    pass

class TestsVirtual(JitAarch64Mixin, VirtualTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    _new_op = 'new_with_vtable'
    _field_prefix = 'inst_'
    
    @staticmethod
    def _new():
        return MyClass()

class TestsVirtualMisc(JitAarch64Mixin, VirtualMiscTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_virtual.py
    pass
