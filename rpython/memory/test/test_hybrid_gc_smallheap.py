import py

from rpython.rlib.rarithmetic import LONG_BIT

from rpython.memory.test.gc_test_base import GCTest

WORD = LONG_BIT // 8

class TestHybridGCSmallHeap(GCTest):
    from rpython.memory.gc.hybrid import HybridGC as GCClass
    GC_CAN_MOVE = False # with this size of heap, stuff gets allocated
                        # in 3rd gen.
    GC_PARAMS = {'space_size': 48*WORD,
                 'min_nursery_size': 12*WORD,
                 'nursery_size': 12*WORD,
                 'large_object': 3*WORD,
                 'large_object_gcptrs': 3*WORD,
                 'generation3_collect_threshold': 5,
                 }

    def test_gen3_to_gen2_refs(self):
        class A(object):
            def __init__(self):
                self.x1 = -1
        def f(x):
            loop = A()
            loop.next = loop
            loop.prev = loop
            i = 0
            while i < x:
                i += 1
                a1 = A()
                a1.x1 = i
                a2 = A()
                a2.x1 = i + 1000
                a1.prev = loop.prev
                a1.prev.next = a1
                a1.next = loop
                loop.prev = a1
                a2.prev = loop
                a2.next = loop.next
                a2.next.prev = a2
                loop.next = a2
            i = 0
            a = loop
            while True:
                a = a.next
                i += 1
                if a is loop:
                    return i
        res = self.interpret(f, [200])
        assert res == 401
