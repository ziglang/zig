import py
import sys

from rpython.memory import gcwrapper
from rpython.memory.test import snippet
from rpython.rtyper import llinterp
from rpython.rtyper.test.test_llinterp import get_interpreter
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.objectmodel import we_are_translated, keepalive_until_here
from rpython.rlib.objectmodel import compute_unique_id
from rpython.rlib import rgc
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rarithmetic import LONG_BIT

WORD = LONG_BIT // 8


## def stdout_ignore_ll_functions(msg):
##     strmsg = str(msg)
##     if "evaluating" in strmsg and "ll_" in strmsg:
##         return
##     print >>sys.stdout, strmsg


class GCTest(object):
    GC_PARAMS = {}
    GC_CAN_MOVE = False
    GC_CAN_SHRINK_ARRAY = False
    GC_CAN_SHRINK_BIG_ARRAY = False
    BUT_HOW_BIG_IS_A_BIG_STRING = 3*WORD
    WREF_IS_INVALID_BEFORE_DEL_IS_CALLED = False

    def setup_class(cls):
        # switch on logging of interp to show more info on failing tests
        llinterp.log.output_disabled = False

    def teardown_class(cls):
        llinterp.log.output_disabled = True

    def interpret(self, func, values, **kwds):
        interp, graph = get_interpreter(func, values, **kwds)
        gcwrapper.prepare_graphs_and_create_gc(interp, self.GCClass,
                                               self.GC_PARAMS)
        return interp.eval_graph(graph, values)

    def test_llinterp_lists(self):
        #curr = simulator.current_size
        def malloc_a_lot():
            i = 0
            while i < 10:
                i += 1
                a = [1] * 10
                j = 0
                while j < 20:
                    j += 1
                    a.append(j)
        self.interpret(malloc_a_lot, [])
        #assert simulator.current_size - curr < 16000 * INT_SIZE / 4
        #print "size before: %s, size after %s" % (curr, simulator.current_size)

    def test_llinterp_tuples(self):
        #curr = simulator.current_size
        def malloc_a_lot():
            i = 0
            while i < 10:
                i += 1
                a = (1, 2, i)
                b = [a] * 10
                j = 0
                while j < 20:
                    j += 1
                    b.append((1, j, i))
        self.interpret(malloc_a_lot, [])
        #assert simulator.current_size - curr < 16000 * INT_SIZE / 4
        #print "size before: %s, size after %s" % (curr, simulator.current_size)

    def test_global_list(self):
        lst = []
        def append_to_list(i, j):
            lst.append([i] * 50)
            return lst[j][0]
        res = self.interpret(append_to_list, [0, 0])
        assert res == 0
        for i in range(1, 15):
            res = self.interpret(append_to_list, [i, i - 1])
            assert res == i - 1 # crashes if constants are not considered roots
            
    def test_string_concatenation(self):
        #curr = simulator.current_size
        def concat(j):
            lst = []
            for i in range(j):
                lst.append(str(i))
            return len("".join(lst))
        res = self.interpret(concat, [100])
        assert res == concat(100)
        #assert simulator.current_size - curr < 16000 * INT_SIZE / 4


    def test_collect(self):
        #curr = simulator.current_size
        def concat(j):
            lst = []
            for i in range(j):
                lst.append(str(i))
            result = len("".join(lst))
            if we_are_translated():
                # can't call llop.gc__collect directly
                llop.gc__collect(lltype.Void)
            return result
        res = self.interpret(concat, [100])
        assert res == concat(100)
        #assert simulator.current_size - curr < 16000 * INT_SIZE / 4

    def test_collect_0(self):
        #curr = simulator.current_size
        def concat(j):
            lst = []
            for i in range(j):
                lst.append(str(i))
            result = len("".join(lst))
            if we_are_translated():
                # can't call llop.gc__collect directly
                llop.gc__collect(lltype.Void, 0)
            return result
        res = self.interpret(concat, [100])
        assert res == concat(100)
        #assert simulator.current_size - curr < 16000 * INT_SIZE / 4

    def test_destructor(self):
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
            return b.num_deleted
        res = self.interpret(f, [5])
        assert res == 6

    def test_old_style_finalizer(self):
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
                llop.gc__collect(lltype.Void)
                b.num_deleted += 1
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted
        res = self.interpret(f, [5])
        assert res == 6

    def test_finalizer(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while self.next_dead() is not None:
                    b.num_deleted += 1
        fq = FQ()
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            a = None
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted
        res = self.interpret(f, [5])
        assert res == 6

    def test_finalizer_delaying_next_dead(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                b.triggered += 1
        fq = FQ()
        def g():     # indirection to avoid leaking the result for too long
            A()
        def f(x):
            b.triggered = 0
            g()
            i = 0
            while i < x:
                i += 1
                g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            assert b.triggered > 0
            g(); g()     # two more
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            num_deleted = 0
            while fq.next_dead() is not None:
                num_deleted += 1
            return num_deleted + 1000 * b.triggered
        res = self.interpret(f, [5])
        assert res in (3008, 4008, 5008), "res == %d" % (res,)

    def test_finalizer_two_queues_in_sequence(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted_1 = 0
        b.num_deleted_2 = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq1.register_finalizer(self)
        class FQ1(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    b.num_deleted_1 += 1
                    fq2.register_finalizer(a)
        class FQ2(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while self.next_dead() is not None:
                    b.num_deleted_2 += 1
        fq1 = FQ1()
        fq2 = FQ2()
        def f(x):
            A()
            i = 0
            while i < x:
                i += 1
                A()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted_1 + b.num_deleted_2 * 1000
        res = self.interpret(f, [5])
        assert res == 6006

    def test_finalizer_calls_malloc(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class C(A):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    b.num_deleted += 1
                    if not isinstance(a, C):
                        C()
        fq = FQ()
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            a = None
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted
        res = self.interpret(f, [5])
        assert res == 12

    def test_finalizer_calls_collect(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while self.next_dead() is not None:
                    b.num_deleted += 1
                    llop.gc__collect(lltype.Void)
        fq = FQ()
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            a = None
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted
        res = self.interpret(f, [5])
        assert res == 6

    def test_finalizer_resurrects(self):
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    b.num_deleted += 1
                    b.a = a
        fq = FQ()
        def f(x):
            a = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            a = None
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            aid = b.a.id
            b.a = None
            # check that finalizer_trigger() is not called again
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return b.num_deleted * 10 + aid + 100 * (b.a is None)
        res = self.interpret(f, [5])
        assert 160 <= res <= 165

    def test_custom_trace(self):
        from rpython.rtyper.lltypesystem import llmemory
        from rpython.rtyper.lltypesystem.llarena import ArenaError
        #
        S = lltype.GcStruct('S', ('x', llmemory.Address),
                                 ('y', llmemory.Address))
        T = lltype.GcStruct('T', ('z', lltype.Signed))
        offset_of_x = llmemory.offsetof(S, 'x')
        def customtrace(gc, obj, callback, arg):
            gc._trace_callback(callback, arg, obj + offset_of_x)
        lambda_customtrace = lambda: customtrace
        #
        for attrname in ['x', 'y']:
            def setup():
                rgc.register_custom_trace_hook(S, lambda_customtrace)
                s1 = lltype.malloc(S)
                tx = lltype.malloc(T)
                tx.z = 42
                ty = lltype.malloc(T)
                s1.x = llmemory.cast_ptr_to_adr(tx)
                s1.y = llmemory.cast_ptr_to_adr(ty)
                return s1
            def f():
                s1 = setup()
                llop.gc__collect(lltype.Void)
                return llmemory.cast_adr_to_ptr(getattr(s1, attrname),
                                                lltype.Ptr(T))
            if attrname == 'x':
                res = self.interpret(f, [])
                assert res.z == 42
            else:
                py.test.raises((RuntimeError, ArenaError),
                               self.interpret, f, [])

    def test_weakref(self):
        import weakref
        class A(object):
            pass
        def g():
            a = A()
            return weakref.ref(a)
        def f():
            a = A()
            ref = weakref.ref(a)
            result = ref() is a
            ref = g()
            llop.gc__collect(lltype.Void)
            result = result and (ref() is None)
            # check that a further collection is fine
            llop.gc__collect(lltype.Void)
            result = result and (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res

    def test_weakref_to_object_with_destructor(self):
        import weakref
        class A(object):
            count = 0
        a = A()
        class B(object):
            def __del__(self):
                a.count += 1
        def g():
            b = B()
            return weakref.ref(b)
        def f():
            ref = g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            result = a.count == 1 and (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res

    def test_weakref_to_object_with_finalizer(self):
        import weakref
        class A(object):
            count = 0
        a = A()
        class B(object):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = B
            def finalizer_trigger(self):
                while self.next_dead() is not None:
                    a.count += 1
        fq = FQ()
        def g():
            b = B()
            fq.register_finalizer(b)
            return weakref.ref(b)
        def f():
            ref = g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            result = a.count == 1 and (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res

    def test_bug_1(self):
        import weakref
        class B(object):
            pass
        def g():
            b = B()
            llop.gc__collect(lltype.Void)    # force 'b' to be old
            ref = weakref.ref(B())
            b.ref = ref
            return ref
        def f():
            ref = g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            result = (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res

    def test_cycle_with_weakref_and_finalizer(self):
        import weakref
        class A(object):
            count = 0
        a = A()
        class B(object):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = B
            def finalizer_trigger(self):
                while True:
                    b = self.next_dead()
                    if b is None:
                        break
                    # when we are here, the weakref to c should be dead
                    if b.ref() is None:
                        a.count += 10  # ok
                    else:
                        a.count = 666  # not ok
        fq = FQ()
        class C(object):
            pass
        def g():
            c = C()
            c.b = B()
            fq.register_finalizer(c.b)
            ref = weakref.ref(c)
            c.b.ref = ref
            return ref
        def f():
            ref = g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            result = a.count + (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res == 11

    def test_weakref_to_object_with_finalizer_ordering(self):
        import weakref
        class A(object):
            count = 0
        a = A()
        expected_invalid = self.WREF_IS_INVALID_BEFORE_DEL_IS_CALLED
        class B(object):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = B
            def finalizer_trigger(self):
                # when we are here, the weakref to myself is still valid
                # in RPython with most GCs.  However, this can lead to strange
                # bugs with incminimark.  https://bugs.pypy.org/issue1687
                # So with incminimark, we expect the opposite.
                while True:
                    b = self.next_dead()
                    if b is None:
                        break
                    if expected_invalid:
                        if b.ref() is None:
                            a.count += 10  # ok
                        else:
                            a.count = 666  # not ok
                    else:
                        if b.ref() is b:
                            a.count += 10  # ok
                        else:
                            a.count = 666  # not ok
        fq = FQ()
        def g():
            b = B()
            fq.register_finalizer(b)
            ref = weakref.ref(b)
            b.ref = ref
            return ref
        def f():
            ref = g()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            result = a.count + (ref() is None)
            return result
        res = self.interpret(f, [])
        assert res == 11

    def test_weakref_bug_1(self):
        import weakref
        class A(object):
            pass
        class B(object):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = B
            def finalizer_trigger(self):
                while True:
                    b = self.next_dead()
                    if b is None:
                        break
                    b.wref().x += 1
        fq = FQ()
        def g(a):
            b = B()
            fq.register_finalizer(b)
            b.wref = weakref.ref(a)
            # the only way to reach this weakref is via B, which is an
            # object with finalizer (but the weakref itself points to
            # a, which does not go away but will move during the next
            # gc.collect)
        def f():
            a = A()
            a.x = 10
            g(a)
            llop.gc__collect(lltype.Void)
            return a.x
        res = self.interpret(f, [])
        assert res == 11

    def test_id(self):
        class A(object):
            pass
        a1 = A()
        def f():
            a2 = A()
            a3 = A()
            id1 = compute_unique_id(a1)
            id2 = compute_unique_id(a2)
            id3 = compute_unique_id(a3)
            llop.gc__collect(lltype.Void)
            error = 0
            if id1 != compute_unique_id(a1): error += 1
            if id2 != compute_unique_id(a2): error += 2
            if id3 != compute_unique_id(a3): error += 4
            return error
        res = self.interpret(f, [])
        assert res == 0

    def test_finalizer_calls_malloc_during_minor_collect(self):
        # originally a GenerationGC test, this has also found bugs in other GCs
        class B(object):
            pass
        b = B()
        b.nextid = 0
        b.num_deleted = 0
        b.all = []
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while self.next_dead() is not None:
                    b.num_deleted += 1
                    b.all.append(D(b.num_deleted))
        fq = FQ()
        class D(object):
            # make a big object that does not use malloc_varsize
            def __init__(self, x):
                self.x00 = self.x01 = self.x02 = self.x03 = self.x04 = x
                self.x10 = self.x11 = self.x12 = self.x13 = self.x14 = x
                self.x20 = self.x21 = self.x22 = self.x23 = self.x24 = x
        def f(x):
            i = 0
            all = [None] * x
            a = A()
            del a
            while i < x:
                d = D(i)
                all[i] = d
                i += 1
            return b.num_deleted + len(all)
        res = self.interpret(f, [500])
        assert res == 1 + 500


    def test_collect_during_collect(self):
        class B(object):
            pass
        b = B()
        b.nextid = 1
        b.num_deleted = 0
        b.num_deleted_c = 0
        class A(object):
            def __init__(self):
                self.id = b.nextid
                b.nextid += 1
                fq.register_finalizer(self)
        class C(A):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = A
            def finalizer_trigger(self):
                while True:
                    a = self.next_dead()
                    if a is None:
                        break
                    llop.gc__collect(lltype.Void)
                    b.num_deleted += 1
                    if isinstance(a, C):
                        b.num_deleted_c += 1
                    else:
                        C()
                        C()
        fq = FQ()
        def f(x, y):
            persistent_a1 = A()
            persistent_a2 = A()
            i = 0
            while i < x:
                i += 1
                a = A()
            persistent_a3 = A()
            persistent_a4 = A()
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            b.bla = persistent_a1.id + persistent_a2.id + persistent_a3.id + persistent_a4.id
            print b.num_deleted_c
            return b.num_deleted
        res = self.interpret(f, [4, 42])
        assert res == 12

    def test_print_leak(self):
        def f(n):
            for i in range(n):
                print i
            return 42
        res = self.interpret(f, [10])
        assert res == 42

    def test_weakref_across_minor_collection(self):
        import weakref
        class A:
            pass
        def f(x):
            a = A()
            a.foo = x
            ref = weakref.ref(a)
            all = [None] * x
            i = 0
            while i < x:
                all[i] = [i] * i
                i += 1
            assert ref() is a
            llop.gc__collect(lltype.Void)
            assert ref() is a
            return a.foo + len(all)
        res = self.interpret(f, [20])  # for GenerationGC, enough for a minor collection
        assert res == 20 + 20

    def test_young_weakref_to_old_object(self):
        import weakref
        class A:
            pass
        def f(x):
            a = A()
            llop.gc__collect(lltype.Void)
            # 'a' is old, 'ref' is young
            ref = weakref.ref(a)
            # now trigger a minor collection
            all = [None] * x
            i = 0
            while i < x:
                all[i] = [i] * i
                i += 1
            # now 'a' is old, but 'ref' did not move
            assert ref() is a
            llop.gc__collect(lltype.Void)
            # now both 'a' and 'ref' have moved
            return ref() is a
        res = self.interpret(f, [20])  # for GenerationGC, enough for a minor collection
        assert res == True

    def test_weakref_to_prebuilt(self):
        import weakref
        class A:
            pass
        a = A()
        def f(x):
            ref = weakref.ref(a)
            assert ref() is a
            llop.gc__collect(lltype.Void)
            return ref() is a
        res = self.interpret(f, [20])  # for GenerationGC, enough for a minor collection
        assert res == True

    def test_many_weakrefs(self):
        # test for the case where allocating the weakref itself triggers
        # a collection
        import weakref
        class A:
            pass
        def f(x):
            a = A()
            i = 0
            while i < x:
                ref = weakref.ref(a)
                assert ref() is a
                i += 1
        self.interpret(f, [1100])

    def test_nongc_static_root(self):
        from rpython.rtyper.lltypesystem import lltype
        T1 = lltype.GcStruct("C", ('x', lltype.Signed))
        T2 = lltype.Struct("C", ('p', lltype.Ptr(T1)))
        static = lltype.malloc(T2, immortal=True)
        def f():
            t1 = lltype.malloc(T1)
            t1.x = 42
            static.p = t1
            llop.gc__collect(lltype.Void)
            return static.p.x
        res = self.interpret(f, [])
        assert res == 42

    def test_can_move(self):
        TP = lltype.GcArray(lltype.Float)
        def func():
            return rgc.can_move(lltype.malloc(TP, 1))
        assert self.interpret(func, []) == self.GC_CAN_MOVE

    def test_trace_array_of_structs(self):
        R = lltype.GcStruct('R', ('i', lltype.Signed))
        S1 = lltype.GcArray(('p1', lltype.Ptr(R)))
        S2 = lltype.GcArray(('p1', lltype.Ptr(R)),
                            ('p2', lltype.Ptr(R)))
        S3 = lltype.GcArray(('p1', lltype.Ptr(R)),
                            ('p2', lltype.Ptr(R)),
                            ('p3', lltype.Ptr(R)))
        def func():
            s1 = lltype.malloc(S1, 2)
            s1[0].p1 = lltype.malloc(R)
            s1[1].p1 = lltype.malloc(R)
            s2 = lltype.malloc(S2, 2)
            s2[0].p1 = lltype.malloc(R)
            s2[0].p2 = lltype.malloc(R)
            s2[1].p1 = lltype.malloc(R)
            s2[1].p2 = lltype.malloc(R)
            s3 = lltype.malloc(S3, 2)
            s3[0].p1 = lltype.malloc(R)
            s3[0].p2 = lltype.malloc(R)
            s3[0].p3 = lltype.malloc(R)
            s3[1].p1 = lltype.malloc(R)
            s3[1].p2 = lltype.malloc(R)
            s3[1].p3 = lltype.malloc(R)
            s1[0].p1.i = 100
            s1[1].p1.i = 101
            s2[0].p1.i = 102
            s2[0].p2.i = 103
            s2[1].p1.i = 104
            s2[1].p2.i = 105
            s3[0].p1.i = 106
            s3[0].p2.i = 107
            s3[0].p3.i = 108
            s3[1].p1.i = 109
            s3[1].p2.i = 110
            s3[1].p3.i = 111
            rgc.collect()
            return ((s1[0].p1.i == 100) +
                    (s1[1].p1.i == 101) +
                    (s2[0].p1.i == 102) +
                    (s2[0].p2.i == 103) +
                    (s2[1].p1.i == 104) +
                    (s2[1].p2.i == 105) +
                    (s3[0].p1.i == 106) +
                    (s3[0].p2.i == 107) +
                    (s3[0].p3.i == 108) +
                    (s3[1].p1.i == 109) +
                    (s3[1].p2.i == 110) +
                    (s3[1].p3.i == 111))
        res = self.interpret(func, [])
        assert res == 12

    def test_shrink_array(self):
        from rpython.rtyper.lltypesystem.rstr import STR

        def f(n, m, gc_can_shrink_array):
            ptr = lltype.malloc(STR, n)
            ptr.hash = 0x62
            ptr.chars[0] = 'A'
            ptr.chars[1] = 'B'
            ptr.chars[2] = 'C'
            ptr2 = rgc.ll_shrink_array(ptr, 2)
            assert (ptr == ptr2) == gc_can_shrink_array
            rgc.collect()
            return ( ord(ptr2.chars[0])       +
                    (ord(ptr2.chars[1]) << 8) +
                    (len(ptr2.chars)   << 16) +
                    (ptr2.hash         << 24))

        flag = self.GC_CAN_SHRINK_ARRAY
        assert self.interpret(f, [3, 0, flag]) == 0x62024241
        # with larger numbers, it gets allocated outside the semispace
        # with some GCs.
        flag = self.GC_CAN_SHRINK_BIG_ARRAY
        bigsize = self.BUT_HOW_BIG_IS_A_BIG_STRING
        assert self.interpret(f, [bigsize, 0, flag]) == 0x62024241

    def test_tagged_simple(self):
        class Unrelated(object):
            pass

        u = Unrelated()
        u.x = UnboxedObject(47)
        def fn(n):
            rgc.collect() # check that a prebuilt tagged pointer doesn't explode
            if n > 0:
                x = BoxedObject(n)
            else:
                x = UnboxedObject(n)
            u.x = x # invoke write barrier
            rgc.collect()
            return x.meth(100)
        res = self.interpret(fn, [1000], taggedpointers=True)
        assert res == 1102
        res = self.interpret(fn, [-1000], taggedpointers=True)
        assert res == -897

    def test_tagged_prebuilt(self):

        class F:
            pass

        f = F()
        f.l = [UnboxedObject(10)]
        def fn(n):
            if n > 0:
                x = BoxedObject(n)
            else:
                x = UnboxedObject(n)
            f.l.append(x)
            rgc.collect()
            return f.l[-1].meth(100)
        res = self.interpret(fn, [1000], taggedpointers=True)
        assert res == 1102
        res = self.interpret(fn, [-1000], taggedpointers=True)
        assert res == -897

    def test_tagged_id(self):
        class Unrelated(object):
            pass

        u = Unrelated()
        u.x = UnboxedObject(0)
        def fn(n):
            id_prebuilt1 = compute_unique_id(u.x)
            if n > 0:
                x = BoxedObject(n)
            else:
                x = UnboxedObject(n)
            id_x1 = compute_unique_id(x)
            rgc.collect() # check that a prebuilt tagged pointer doesn't explode
            id_prebuilt2 = compute_unique_id(u.x)
            id_x2 = compute_unique_id(x)
            print u.x, id_prebuilt1, id_prebuilt2
            print x, id_x1, id_x2
            return ((id_x1 == id_x2) * 1 +
                    (id_prebuilt1 == id_prebuilt2) * 10 +
                    (id_x1 != id_prebuilt1) * 100)
        res = self.interpret(fn, [1000], taggedpointers=True)
        assert res == 111
        res = self.interpret(fn, [-1000], taggedpointers=True)
        assert res == 111

    def test_writebarrier_before_copy(self):
        S = lltype.GcStruct('S', ('x', lltype.Char))
        TP = lltype.GcArray(lltype.Ptr(S))
        def fn():
            l = lltype.malloc(TP, 100)
            l2 = lltype.malloc(TP, 100)
            for i in range(100):
                l[i] = lltype.malloc(S)
            rgc.ll_arraycopy(l, l2, 50, 0, 50)
            x = []
            # force minor collect
            t = (1, lltype.malloc(S))
            for i in range(20):
                x.append(t)
            for i in range(50):
                assert l2[i] == l[50 + i]
            return 0

        self.interpret(fn, [])

    def test_writebarrier_before_copy_manually_copy_card_bits(self):
        S = lltype.GcStruct('S', ('x', lltype.Char))
        TP = lltype.GcArray(lltype.Ptr(S))
        def fn():
            l1 = lltype.malloc(TP, 65)
            l2 = lltype.malloc(TP, 33)
            for i in range(65):
                l1[i] = lltype.malloc(S)
            l = lltype.malloc(TP, 100)
            i = 0
            while i < 65:
                l[i] = l1[i]
                i += 1
            rgc.ll_arraycopy(l, l2, 0, 0, 33)
            x = []
            # force minor collect
            t = (1, lltype.malloc(S))
            for i in range(20):
                x.append(t)
            for i in range(33):
                assert l2[i] == l[i]
            return 0

        self.interpret(fn, [])

    def test_stringbuilder(self):
        def fn():
            s = StringBuilder(4)
            s.append("abcd")
            s.append("defg")
            s.append("rty")
            s.append_multiple_char('y', 1000)
            rgc.collect()
            s.append_multiple_char('y', 1000)
            res = s.build()[1000]
            rgc.collect()
            return ord(res)
        res = self.interpret(fn, [])
        assert res == ord('y')

    def test_gcflag_extra(self):
        class A:
            pass
        a1 = A()
        def fn():
            a2 = A()
            if not rgc.has_gcflag_extra():
                return     # cannot test it then
            assert rgc.get_gcflag_extra(a1) == False
            assert rgc.get_gcflag_extra(a2) == False
            rgc.toggle_gcflag_extra(a1)
            assert rgc.get_gcflag_extra(a1) == True
            assert rgc.get_gcflag_extra(a2) == False
            rgc.toggle_gcflag_extra(a2)
            assert rgc.get_gcflag_extra(a1) == True
            assert rgc.get_gcflag_extra(a2) == True
            rgc.toggle_gcflag_extra(a1)
            assert rgc.get_gcflag_extra(a1) == False
            assert rgc.get_gcflag_extra(a2) == True
            rgc.toggle_gcflag_extra(a2)
            assert rgc.get_gcflag_extra(a1) == False
            assert rgc.get_gcflag_extra(a2) == False
        self.interpret(fn, [])
    
    def test_register_custom_trace_hook(self):
        S = lltype.GcStruct('S', ('x', lltype.Signed))
        called = []

        def trace_hook(gc, obj, callback, arg):
            called.append("called")
        lambda_trace_hook = lambda: trace_hook

        def f():
            rgc.register_custom_trace_hook(S, lambda_trace_hook)
            s = lltype.malloc(S)
            rgc.collect()
            keepalive_until_here(s)

        self.interpret(f, [])
        assert called # not empty, can contain more than one item

    def test_pinning(self):
        def fn(n):
            s = str(n)
            if not rgc.can_move(s):
                return 13
            res = int(rgc.pin(s))
            if res:
                rgc.unpin(s)
            return res

        res = self.interpret(fn, [10])
        if not self.GCClass.moving_gc:
            assert res == 13
        elif self.GCClass.can_usually_pin_objects:
            assert res == 1
        else:
            assert res == 0 or res == 13

    def test__is_pinned(self):
        def fn(n):
            from rpython.rlib.debug import debug_print
            s = str(n)
            if not rgc.can_move(s):
                return 13
            res = int(rgc.pin(s))
            if res:
                res += int(rgc._is_pinned(s))
                rgc.unpin(s)
            return res

        res = self.interpret(fn, [10])
        if not self.GCClass.moving_gc:
            assert res == 13
        elif self.GCClass.can_usually_pin_objects:
            assert res == 2
        else:
            assert res == 0 or res == 13

    def test_gettypeid(self):
        class A(object):
            pass
        
        def fn():
            a = A()
            return rgc.get_typeid(a)

        self.interpret(fn, [])


from rpython.rlib.objectmodel import UnboxedValue

class TaggedBase(object):
    __slots__ = ()
    def meth(self, x):
        raise NotImplementedError

class BoxedObject(TaggedBase):
    attrvalue = 66
    def __init__(self, normalint):
        self.normalint = normalint
    def meth(self, x):
        return self.normalint + x + 2

class UnboxedObject(TaggedBase, UnboxedValue):
    __slots__ = 'smallint'
    def meth(self, x):
        return self.smallint + x + 3
