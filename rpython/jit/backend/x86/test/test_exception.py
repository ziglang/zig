
import py
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test.test_exception import ExceptionTests

class TestExceptions(Jit386Mixin, ExceptionTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_exception.py

    def test_bridge_from_interpreter_exc(self):
        py.test.skip("Widening to trash")
