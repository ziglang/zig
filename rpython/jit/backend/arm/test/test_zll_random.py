from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.test import test_ll_random
from rpython.jit.backend.test import test_random
from rpython.jit.backend.test.test_ll_random import LLtypeOperationBuilder
from rpython.jit.backend.test.test_random import check_random_function, Random
from rpython.jit.metainterp.resoperation import rop

CPU = getcpuclass()

def test_stress():
    cpu = CPU(None, None)
    cpu.setup_once()
    for i in range(100):
        r = Random()
        check_random_function(cpu, LLtypeOperationBuilder, r, i, 1000)
