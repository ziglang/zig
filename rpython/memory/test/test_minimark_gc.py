from rpython.rlib import rgc
from rpython.rlib.rarithmetic import LONG_BIT

from rpython.memory.test import test_semispace_gc

WORD = LONG_BIT // 8

class TestMiniMarkGC(test_semispace_gc.TestSemiSpaceGC):
    from rpython.memory.gc.minimark import MiniMarkGC as GCClass
    GC_CAN_SHRINK_BIG_ARRAY = False
    GC_CAN_MALLOC_NONMOVABLE = True
    BUT_HOW_BIG_IS_A_BIG_STRING = 11*WORD

    def test_bounded_memory_when_allocating_with_finalizers(self):
        # Issue #2590: when allocating a lot of objects with a finalizer
        # and little else, the bounds in the (inc)minimark GC are not
        # set up reasonably and the total memory usage grows without
        # limit.
        class B(object):
            pass
        b = B()
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    b.num_deleted += 1
        fq = FQ()
        def f(x, y):
            i = 0
            alive_max = 0
            while i < x:
                i += 1
                a = A()
                a.x = a.y = a.z = i
                #print i - b.num_deleted, b.num_deleted
                alive = i - b.num_deleted
                assert alive >= 0
                alive_max = max(alive_max, alive)
            return alive_max
        res = self.interpret(f, [1000, 0])
        assert res < 100
