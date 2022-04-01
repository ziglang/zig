import weakref

import py

from rpython.rlib import rgc, debug
from rpython.rlib.objectmodel import (keepalive_until_here, compute_unique_id,
    compute_hash, current_object_addr_as_int)
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.rstr import STR
from rpython.translator.c.test.test_genc import compile


def setup_module(mod):
    from rpython.rtyper.tool.rffi_platform import configure_boehm
    from rpython.translator.platform import CompilationError
    try:
        configure_boehm()
    except CompilationError:
        py.test.skip("Boehm GC not present")


class AbstractGCTestClass(object):
    gcpolicy = "boehm"
    use_threads = False
    extra_options = {}

    # deal with cleanups
    def setup_method(self, meth):
        self._cleanups = []

    def teardown_method(self, meth):
        while self._cleanups:
            #print "CLEANUP"
            self._cleanups.pop()()

    def getcompiled(self, func, argstypelist=[], annotatorpolicy=None,
                    extra_options={}):
        return compile(func, argstypelist, gcpolicy=self.gcpolicy,
                       thread=self.use_threads, **extra_options)


class TestUsingBoehm(AbstractGCTestClass):
    gcpolicy = "boehm"

    def test_malloc_a_lot(self):
        def malloc_a_lot():
            i = 0
            while i < 10:
                i += 1
                a = [1] * 10
                j = 0
                while j < 20:
                    j += 1
                    a.append(j)
        fn = self.getcompiled(malloc_a_lot)
        fn()

    def test__del__(self):
        class State:
            pass
        s = State()
        class A(object):
            def __del__(self):
                s.a_dels += 1
        class B(A):
            def __del__(self):
                s.b_dels += 1
        class C(A):
            pass
        def f():
            s.a_dels = 0
            s.b_dels = 0
            A()
            B()
            C()
            A()
            B()
            C()
            llop.gc__collect(lltype.Void)
            return s.a_dels * 10 + s.b_dels
        fn = self.getcompiled(f)
        # we can't demand that boehm has collected all of the objects,
        # even with the gc__collect call.  calling the compiled
        # function twice seems to help, though.
        res = 0
        res += fn()
        res += fn()
        # if res is still 0, then we haven't tested anything so fail.
        # it might be the test's fault though.
        assert 0 < res <= 84

    def test_id_is_weak(self):
        # test that compute_unique_id(obj) does not keep obj alive
        class State:
            pass
        s = State()
        class A(object):
            def __del__(self):
                s.a_dels += 1
        class B(A):
            def __del__(self):
                s.b_dels += 1
        class C(A):
            pass
        def run_once():
            a = A()
            ida = compute_unique_id(a)
            b = B()
            idb = compute_unique_id(b)
            c = C()
            idc = compute_unique_id(c)
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            llop.gc__collect(lltype.Void)
            return ida, idb, idc
        def f(n):
            s.a_dels = 0
            s.b_dels = 0
            a1, b1, c1 = run_once()
            a2, b2, c2 = run_once()
            a3, b3, c3 = run_once()
            a4, b4, c4 = run_once()
            a5, b5, c5 = run_once()
            return str((s.a_dels, s.b_dels,
                        a1, b1, c1,
                        a2, b2, c2,
                        a3, b3, c3,
                        a4, b4, c4,
                        a5, b5, c5))
        fn = self.getcompiled(f, [int])
        # we can't demand that boehm has collected all of the objects,
        # even with the gc__collect call.
        res = fn(50)
        res1, res2 = eval(res)[:2]
        # if res1 or res2 is still 0, then we haven't tested anything so fail.
        # it might be the test's fault though.
        print res1, res2
        assert 0 < res1 <= 10
        assert 0 < res2 <= 5

    def test_del_raises(self):
        class A(object):
            def __del__(self):
                s.dels += 1
                raise Exception
        class State:
            pass
        s = State()
        s.dels = 0
        def g():
            a = A()
        def f():
            s.dels = 0
            for i in range(10):
                g()
            llop.gc__collect(lltype.Void)
            return s.dels
        fn = self.getcompiled(f)
        # we can't demand that boehm has collected all of the objects,
        # even with the gc__collect call.  calling the compiled
        # function twice seems to help, though.
        res = 0
        res += fn()
        res += fn()
        # if res is still 0, then we haven't tested anything so fail.
        # it might be the test's fault though.
        assert res > 0

    def test_memory_error_varsize(self):
        N = int(2**31-1)
        A = lltype.GcArray(lltype.Char)
        def alloc(n):
            return lltype.malloc(A, n)
        def f():
            try:
                x = alloc(N)
            except MemoryError:
                y = alloc(10)
                return len(y)
            y = alloc(10)
            return len(y) # allocation may work on 64 bits machines
        fn = self.getcompiled(f)
        res = fn()
        assert res == 10

    def test_zero_malloc(self):
        T = lltype.GcStruct("C", ('x', lltype.Signed))
        def fixed_size():
            t = lltype.malloc(T, zero=True)
            return t.x
        c_fixed_size = self.getcompiled(fixed_size, [])
        res = c_fixed_size()
        assert res == 0
        A = lltype.GcArray(lltype.Signed)
        def var_size():
            a = lltype.malloc(A, 1, zero=True)
            return a[0]
        c_var_size = self.getcompiled(var_size, [])
        res = c_var_size()
        assert res == 0

    def test_gc_set_max_heap_size(self):
        def g(n):
            return 'x' * n
        def fn():
            from rpython.rlib import rgc
            rgc.set_max_heap_size(500000)
            s1 = s2 = s3 = None
            try:
                s1 = g(10000)
                s2 = g(100000)
                s3 = g(1000000)
            except MemoryError:
                pass
            return (s1 is not None) + (s2 is not None) + (s3 is not None)
        c_fn = self.getcompiled(fn, [])
        res = c_fn()
        assert res == 2

    def test_weakref(self):
        class A:
            pass

        def fn(n):
            keepalive = []
            weakrefs = []
            a = None
            for i in range(n):
                if i & 1 == 0:
                    a = A()
                    a.index = i
                assert a is not None
                weakrefs.append(weakref.ref(a))
                if i % 7 == 6:
                    keepalive.append(a)
            rgc.collect()
            count_free = 0
            for i in range(n):
                a = weakrefs[i]()
                if i % 7 == 6:
                    assert a is not None
                if a is not None:
                    assert a.index == i & ~1
                else:
                    count_free += 1
            keepalive_until_here(keepalive)
            return count_free
        c_fn = self.getcompiled(fn, [int])
        res = c_fn(7000)
        # more than half of them should have been freed, ideally up to 6000
        assert 3500 <= res <= 6000

    def test_prebuilt_weakref(self):
        class A:
            pass
        a = A()
        a.hello = 42
        r1 = weakref.ref(a)
        r2 = weakref.ref(A())
        rgc.collect()
        assert r2() is None
        def fn(n):
            if n:
                r = r1
            else:
                r = r2
            a = r()
            rgc.collect()
            if a is None:
                return -5
            else:
                return a.hello
        c_fn = self.getcompiled(fn, [int])
        res = c_fn(1)
        assert res == 42
        res = c_fn(0)
        assert res == -5

    def test_weakref_to_prebuilt(self):
        class A:
            pass
        a = A()
        a.hello = 42
        def fn(n):
            lst = [weakref.ref(a) for i in range(n)]
            rgc.collect()
            for r in lst:
                assert r() is a
        c_fn = self.getcompiled(fn, [int])
        c_fn(100)

    def test_nested_finalizers(self):
        class State:
            pass
        state = State()
        def g():
            n = state.counter
            if n > 0:
                for i in range(5):
                    state.a = A(n)
                state.a = None
            rgc.collect()
            return n

        fun = g
        for i in range(200):
            def fun(next=fun):
                return next() + 1     # prevents tail-call optimization

        class A:
            def __init__(self, level):
                self.level = level
            def __del__(self):
                if state.counter == self.level:
                    state.counter -= 1
                    fun()
        def fn(n):
            state.counter = n
            fun()
            return state.counter
        c_fn = self.getcompiled(fn, [int])
        res = c_fn(10000)
        assert res == 0

    def test_can_move(self):
        class A:
            pass
        def fn():
            return rgc.can_move(A())

        c_fn = self.getcompiled(fn, [])
        assert c_fn() == False

    def test_heap_stats(self):
        def fn():
            return bool(rgc._heap_stats())

        c_fn = self.getcompiled(fn, [])
        assert not c_fn()

    def test_shrink_array(self):
        def f():
            ptr = lltype.malloc(STR, 3)
            ptr.hash = 0x62
            ptr.chars[0] = '0'
            ptr.chars[1] = 'B'
            ptr.chars[2] = 'C'
            ptr2 = rgc.ll_shrink_array(ptr, 2)
            return ((ptr == ptr2)             +
                     ord(ptr2.chars[0])       +
                    (ord(ptr2.chars[1]) << 8) +
                    (len(ptr2.chars)   << 16) +
                    (ptr2.hash         << 24))

        run = self.getcompiled(f)
        assert run() == 0x62024230

    def test_write_barrier_nop(self):
        S = lltype.GcStruct('S', ('x', lltype.Signed))
        s = lltype.malloc(S)
        s.x = 0
        def f():
            llop.gc_writebarrier(lltype.Void, llmemory.cast_ptr_to_adr(s))
            return True
        run = self.getcompiled(f)
        assert run() == True

    def test_hash_preservation(self):
        class C:
            pass
        class D(C):
            pass
        c = C()
        d = D()
        compute_hash(d)     # force to be cached on 'd', but not on 'c'
        #
        def fn():
            d2 = D()
            return str((compute_hash(d2),
                        current_object_addr_as_int(d2),
                        compute_hash(c),
                        compute_hash(d),
                        compute_hash(("Hi", None, (7.5, 2)))))

        f = self.getcompiled(fn)
        res = f()
        res = eval(res)

        # xxx the next line is too precise, checking the exact implementation
        assert res[0] == ~res[1]
        assert res[2] != compute_hash(c)     # likely
        assert res[3] != compute_hash(d)     # likely *not* preserved
        assert res[4] == compute_hash(("Hi", None, (7.5, 2)))
        # ^^ true as long as we're using the default 'fnv' hash for strings
        #    and not e.g. siphash24

    def test_finalizer_queue(self):
        class A(object):
            def __init__(self, i):
                self.i = i
        class Glob:
            triggered = 0
        glob = Glob()
        class FQ(rgc.FinalizerQueue):
            Class = A
            triggered = 0
            def finalizer_trigger(self):
                glob.triggered += 1
        fq = FQ()
        #
        def fn():
            for i in range(1000):
                x = A(i)
                fq.register_finalizer(x)
                rgc.may_ignore_finalizer(x)   # this is ignored with Boehm
            rgc.collect()
            rgc.collect()
            if glob.triggered == 0:
                print "not triggered!"
                return 50
            seen = {}
            while True:
                a = fq.next_dead()
                if a is None:
                    break
                assert a.i not in seen
                seen[a.i] = True
            if len(seen) < 500:
                print "seen only %d!" % len(seen)
                return 51
            return 42

        f = self.getcompiled(fn)
        res = f()
        assert res == 42
