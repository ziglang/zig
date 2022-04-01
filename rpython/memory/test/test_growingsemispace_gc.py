from rpython.rlib.rarithmetic import LONG_BIT

from rpython.memory.test import test_semispace_gc

WORD = LONG_BIT // 8

class TestGrowingSemiSpaceGC(test_semispace_gc.TestSemiSpaceGC):
    GC_PARAMS = {'space_size': 16*WORD}
