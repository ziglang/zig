from rpython.memory.test import snippet
from rpython.memory.test.gc_test_base import GCTest

class TestSemiSpaceGC(GCTest, snippet.SemiSpaceGCTests):
    from rpython.memory.gc.semispace import SemiSpaceGC as GCClass
    GC_CAN_MOVE = True
    GC_CAN_MALLOC_NONMOVABLE = False
    GC_CAN_SHRINK_ARRAY = True
    GC_CAN_SHRINK_BIG_ARRAY = True
