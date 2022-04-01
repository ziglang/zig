from rpython.jit.backend.test.test_random import check_random_function, Random
from rpython.jit.backend.test.test_ll_random import LLtypeOperationBuilder
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.resoperation import rop
import platform

CPU = getcpuclass()

total_iterations = 1000
if platform.machine().startswith('arm'):
    total_iterations = 100

pieces = 4
per_piece = total_iterations / pieces


def do_test_stress(piece):
    cpu = CPU(None, None)
    cpu.setup_once()
    r = Random()
    r.jumpahead(piece*99999999)
    OPERATIONS = LLtypeOperationBuilder.OPERATIONS[:]
    for i in range(piece*per_piece, (piece+1)*per_piece):
        print "        i = %d; r.setstate(%s)" % (i, r.getstate())
        check_random_function(cpu, LLtypeOperationBuilder, r, i, total_iterations)
    # restore the old list
    LLtypeOperationBuilder.OPERATIONS = OPERATIONS
