import math
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.rfloat import INFINITY, NAN

class MathTests:

    def test_math_sqrt(self):
        def f(x):
            try:
                return math.sqrt(x)
            except ValueError:
                return -INFINITY

        res = self.interp_operations(f, [0.0])
        assert res == 0.0
        self.check_operations_history(call_pure_f=1)
        #
        res = self.interp_operations(f, [25.0])
        assert res == 5.0
        self.check_operations_history(call_pure_f=1)
        #
        res = self.interp_operations(f, [-0.0])
        assert str(res) == '-0.0'
        self.check_operations_history(call_pure_f=1)
        #
        res = self.interp_operations(f, [1000000.0])
        assert res == 1000.0
        self.check_operations_history(call_pure_f=1)
        #
        res = self.interp_operations(f, [-1.0])
        assert res == -INFINITY
        self.check_operations_history(call_pure_f=0)
        #
        res = self.interp_operations(f, [INFINITY])
        assert math.isinf(res) and not math.isnan(res) and res > 0.0
        self.check_operations_history(call_pure_f=0)
        #
        res = self.interp_operations(f, [NAN])
        assert math.isnan(res) and not math.isinf(res)
        self.check_operations_history(call_pure_f=0)


class TestLLtype(MathTests, LLJitMixin):
    pass
