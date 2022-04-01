
import py
from rpython.jit.metainterp.test.test_virtualizable import ImplicitVirtualizableTests
from rpython.jit.backend.zarch.test.support import JitZARCHMixin

class TestVirtualizable(JitZARCHMixin, ImplicitVirtualizableTests):
    def test_blackhole_should_not_reenter(self):
        py.test.skip("Assertion error & llinterp mess")
