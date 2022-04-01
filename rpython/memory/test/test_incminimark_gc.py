import py
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib import rgc

from rpython.memory.test import test_minimark_gc

class TestIncrementalMiniMarkGC(test_minimark_gc.TestMiniMarkGC):
    from rpython.memory.gc.incminimark import IncrementalMiniMarkGC as GCClass
    WREF_IS_INVALID_BEFORE_DEL_IS_CALLED = True

    def test_weakref_not_in_stack(self):
        import weakref
        class A(object):
            pass
        class B(object):
            def __init__(self, next):
                self.next = next
        def g():
            a = A()
            a.x = 5
            wr = weakref.ref(a)
            llop.gc__collect(lltype.Void)   # make everything old
            assert wr() is not None
            assert a.x == 5
            return wr
        def f():
            ref = g()
            llop.gc__collect(lltype.Void, 1)    # start a major cycle
            # at this point the stack is scanned, and the weakref points
            # to an object not found, but still reachable:
            b = ref()
            llop.debug_print(lltype.Void, b)
            assert b is not None
            llop.gc__collect(lltype.Void)   # finish the major cycle
            # assert does not crash, because 'b' is still kept alive
            b.x = 42
            return ref() is b
        res = self.interpret(f, [])
        assert res == True

    def test_pin_weakref_not_implemented(self):
        import weakref
        class A:
            pass
        def f():
            a = A()
            ref = weakref.ref(a)
            assert not rgc.pin(ref)
        self.interpret(f, [])

    def test_pin_finalizer_not_implemented(self):
        import weakref
        class A:
            def __del__(self):
                pass
        class B:
            def __del__(self):
                foo.bar += 1
        class Foo:
            bar = 0
        foo = Foo()
        def f():
            a = A()
            b = B()
            assert not rgc.pin(a)
            assert not rgc.pin(b)
        self.interpret(f, [])

    def test_weakref_to_pinned(self):
        py.test.skip("weakref to pinned object: not supported")
        import weakref
        from rpython.rlib import rgc
        class A(object):
            pass
        def g():
            a = A()
            assert rgc.pin(a)
            a.x = 100
            wr = weakref.ref(a)
            llop.gc__collect(lltype.Void)
            assert wr() is not None
            assert a.x == 100
            return wr
        def f():
            ref = g()
            llop.gc__collect(lltype.Void, 1)
            b = ref()
            assert b is not None
            b.x = 101
            return ref() is b
        res = self.interpret(f, [])
        assert res == True
