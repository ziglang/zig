
import py
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.test.test_tlc import TLCTests
from rpython.jit.tl import tlc

class TestTL(Jit386Mixin, TLCTests):
    # for the individual tests see
    # ====> ../../test/test_tlc.py
    
    def test_accumulator(self):
        py.test.skip("investigate, maybe")
        path = py.path.local(tlc.__file__).dirpath('accumulator.tlc.src')
        code = path.read()
        res = self.exec_code(code, 20)
        assert res == sum(range(20))
        res = self.exec_code(code, -10)
        assert res == 10

    def test_fib(self):
        py.test.skip("investigate, maybe")
        path = py.path.local(tlc.__file__).dirpath('fibo.tlc.src')
        code = path.read()
        res = self.exec_code(code, 7)
        assert res == 13
        res = self.exec_code(code, 20)
        assert res == 6765
