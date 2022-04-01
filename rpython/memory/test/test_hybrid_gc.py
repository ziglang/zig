import py

from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop

from rpython.memory.test import test_generational_gc


class TestHybridGC(test_generational_gc.TestGenerationalGC):
    from rpython.memory.gc.hybrid import HybridGC as GCClass
    GC_CAN_SHRINK_BIG_ARRAY = False

    def test_ref_from_rawmalloced_to_regular(self):
        import gc
        def concat(j):
            lst = []
            for i in range(j):
                lst.append(str(i))
            gc.collect()
            return len("".join(lst))
        res = self.interpret(concat, [100])
        assert res == concat(100)

    def test_longliving_weakref(self):
        # test for the case where a weakref points to a very old object
        # that was made non-movable after several collections
        import gc, weakref
        class A:
            pass
        def step1(x):
            a = A()
            a.x = 42
            ref = weakref.ref(a)
            i = 0
            while i < x:
                gc.collect()
                i += 1
            assert ref() is a
            assert ref().x == 42
            return ref
        def step2(ref):
            gc.collect()       # 'a' is freed here
            assert ref() is None
        def f(x):
            ref = step1(x)
            step2(ref)
        self.interpret(f, [10])

    def test_longliving_object_with_finalizer(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
            def __del__(self):
                b.num_deleted += 1
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
                llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted
        res = self.interpret(f, [15])
        assert res == 16
