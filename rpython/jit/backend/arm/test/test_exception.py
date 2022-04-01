
import py
from rpython.jit.backend.arm.test.support import JitARMMixin
from rpython.jit.metainterp.test.test_exception import ExceptionTests

class TestExceptions(JitARMMixin, ExceptionTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_exception.py

    def test_bridge_from_interpreter_exc(self):
        py.test.skip("Widening to trash")
