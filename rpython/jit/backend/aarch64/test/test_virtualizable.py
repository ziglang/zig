
import py
from rpython.jit.metainterp.test.test_virtualizable import ImplicitVirtualizableTests
from rpython.jit.backend.aarch64.test.test_basic import JitAarch64Mixin

class TestVirtualizable(JitAarch64Mixin, ImplicitVirtualizableTests):
    def test_blackhole_should_not_reenter(self):
        py.test.skip("Assertion error & llinterp mess")
