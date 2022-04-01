from rpython.memory.test import test_semispace_gc

class TestGenerationalGC(test_semispace_gc.TestSemiSpaceGC):
    from rpython.memory.gc.generation import GenerationGC as GCClass
