import sys, py

from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib import jit
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rlib.rstring import StringBuilder


class TestLLtype(LLJitMixin):
    def test_dont_record_repeated_guard_class(self):
        class A:
            pass
        class B(A):
            pass
        @jit.dont_look_inside
        def extern(n):
            if n == -7:
                return None
            elif n:
                return A()
            else:
                return B()
        def fn(n):
            obj = extern(n)
            return isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B)
        res = self.interp_operations(fn, [0])
        assert res == 4
        self.check_operations_history(guard_class=1, guard_nonnull=1)
        res = self.interp_operations(fn, [1])
        assert not res

    def test_dont_record_guard_class_after_new(self):
        class A:
            pass
        class B(A):
            pass
        def fn(n):
            if n == -7:
                obj = None
            elif n:
                obj = A()
            else:
                obj = B()
            return isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B)
        res = self.interp_operations(fn, [0])
        assert res == 4
        self.check_operations_history(guard_class=0, guard_nonnull=0)
        res = self.interp_operations(fn, [1])
        assert not res

    def test_guard_isnull_nullifies(self):
        class A:
            pass
        a = A()
        a.x = None
        def fn(n):
            if n == -7:
                a.x = ""
            obj = a.x
            res = 0
            if not obj:
                res += 1
            if obj:
                res += 1
            if obj is None:
                res += 1
            if obj is not None:
                res += 1
            return res
        res = self.interp_operations(fn, [0])
        assert res == 2
        self.check_operations_history(guard_isnull=1)

    def test_heap_caching_while_tracing(self):
        class A:
            pass

        @jit.dont_look_inside
        def get():
            return A()

        def fn(n):
            a1 = get()
            a2 = get()
            if n > 0:
                a = a1
            else:
                a = a2
            a.x = n
            return a.x
        res = self.interp_operations(fn, [7])
        assert res == 7
        self.check_operations_history(getfield_gc_i=0)
        res = self.interp_operations(fn, [-7])
        assert res == -7
        self.check_operations_history(getfield_gc_i=0)

        def fn(n, ca, cb):
            a1 = get()
            a2 = get()
            a1.x = n
            a2.x = n
            a = a1
            if ca:
                a = a2
            b = a1
            if cb:
                b = a
            return a.x + b.x
        res = self.interp_operations(fn, [7, 0, 1])
        assert res == 7 * 2
        self.check_operations_history(getfield_gc_i=1)
        res = self.interp_operations(fn, [-7, 1, 1])
        assert res == -7 * 2
        self.check_operations_history(getfield_gc_i=0)

    def test_heap_caching_nonnull(self):
        class A:
            def __init__(self, x=None):
                self.next = x
        a0 = A()
        a1 = A()
        a2 = A(a1)
        def fn(n):
            if n > 0:
                a = a1
            else:
                a = a2
            if a.next:
                a = A(a.next)
                result = a.next is not None
                a0.next = a
                return result
            return False
        res = self.interp_operations(fn, [-7])
        assert res == True
        self.check_operations_history(guard_nonnull=1)

    def test_heap_caching_while_tracing_invalidation(self):
        class A:
            pass
        @jit.dont_look_inside
        def f(a):
            a.x = 5
        @jit.dont_look_inside
        def get():
            return A()
        l = [1]
        def fn(n):
            if n > 0:
                a = get()
            else:
                a = get()
            a.x = n
            x1 = a.x
            f(a)
            x2 = a.x
            l[0] = x2
            return a.x + x1 + x2
        res = self.interp_operations(fn, [7])
        assert res == 5 * 2 + 7
        self.check_operations_history(getfield_gc_i=1)

    def test_heap_caching_dont_store_same(self):
        class A:
            pass
        @jit.dont_look_inside
        def get():
            return A()
        def fn(n):
            if n > 0:
                a = get()
            else:
                a = get()
            a.x = n
            a.x = n
            return a.x
        res = self.interp_operations(fn, [7])
        assert res == 7
        self.check_operations_history(getfield_gc_i=0, setfield_gc=1)
        res = self.interp_operations(fn, [-7])
        assert res == -7
        self.check_operations_history(getfield_gc_i=0)

    def test_array_caching(self):
        a1 = [0, 0]
        a2 = [0, 0]
        def fn(n):
            if n > 0:
                a = a1
            else:
                a = a2
            a[0] = n
            x1 = a[0]
            a[n - n] = n + 1
            return a[0] + x1
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1
        self.check_operations_history(getarrayitem_gc_i=1)
        res = self.interp_operations(fn, [-7])
        assert res == -7 - 7 + 1
        self.check_operations_history(getarrayitem_gc_i=1)

        def fn(n, ca, cb):
            a1[0] = n
            a2[0] = n
            a = a1
            if ca:
                a = a2
            b = a1
            if cb:
                b = a
            return a[0] + b[0]
        res = self.interp_operations(fn, [7, 0, 1])
        assert res == 7 * 2
        self.check_operations_history(getarrayitem_gc_i=1)
        res = self.interp_operations(fn, [-7, 1, 1])
        assert res == -7 * 2
        self.check_operations_history(getarrayitem_gc_i=1)

    def test_array_caching_float(self):
        a1 = [0.0, 0.0]
        a2 = [0.0, 0.0]
        def fn(n):
            if n > 0:
                a = a1
            else:
                a = a2
            a[0] = n + 0.01
            x1 = a[0]
            a[n - n] = n + 0.1
            return a[0] + x1
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 0.01 + 0.1
        self.check_operations_history(getarrayitem_gc_f=1)
        res = self.interp_operations(fn, [-7])
        assert res == -7 - 7 + 0.01 + 0.1
        self.check_operations_history(getarrayitem_gc_f=1)

        def fn(n, ca, cb):
            a1[0] = n + 0.01
            a2[0] = n + 0.01
            a = a1
            if ca:
                a = a2
            b = a1
            if cb:
                b = a
            return a[0] + b[0]
        res = self.interp_operations(fn, [7, 0, 1])
        assert res == (7 + 0.01) * 2
        self.check_operations_history(getarrayitem_gc_f=1)
        res = self.interp_operations(fn, [-7, 1, 1])
        assert res == (-7 + 0.01) * 2
        self.check_operations_history(getarrayitem_gc_f=1)

    def test_array_caching_while_tracing_invalidation(self):
        a1 = [0, 0]
        a2 = [0, 0]
        @jit.dont_look_inside
        def f(a):
            a[0] = 5
        class A: pass
        l = A()
        def fn(n):
            if n > 0:
                a = a1
            else:
                a = a2
            a[0] = n
            x1 = a[0]
            f(a)
            x2 = a[0]
            l.x = x2
            return a[0] + x1 + x2
        res = self.interp_operations(fn, [7])
        assert res == 5 * 2 + 7
        self.check_operations_history(getarrayitem_gc_i=1)

    def test_array_and_getfield_interaction(self):
        class A: pass
        @jit.dont_look_inside
        def get():
            a = A()
            a.l = [0, 0]
            return a
        def fn(n):
            if n > 0:
                a = get()
            else:
                a = get()
                a.l = [0, 0]
            a.x = 0
            a.l[a.x] = n
            a.x += 1
            a.l[a.x] = n + 1
            x1 = a.l[a.x]
            a.x -= 1
            x2 = a.l[a.x]
            return x1 + x2
        res = self.interp_operations(fn, [7])
        assert res == 7 * 2 + 1
        self.check_operations_history(setarrayitem_gc=2, setfield_gc=3,
                                      getarrayitem_gc_i=0, getfield_gc_r=1)

    def test_promote_changes_heap_cache(self):
        class A: pass
        @jit.dont_look_inside
        def get():
            a = A()
            a.l = [0, 0]
            a.x = 0
            return a
        def fn(n):
            if n > 0:
                a = get()
            else:
                a = get()
                a.l = [0, 0]
            jit.promote(a.x)
            a.l[a.x] = n
            a.x += 1
            a.l[a.x] = n + 1
            x1 = a.l[a.x]
            a.x -= 1
            x2 = a.l[a.x]
            return x1 + x2
        res = self.interp_operations(fn, [7])
        assert res == 7 * 2 + 1
        self.check_operations_history(setarrayitem_gc=2, setfield_gc=2,
                                      getarrayitem_gc_i=0, getfield_gc_i=1,
            getfield_gc_r=1)

    def test_promote_changes_array_cache(self):
        @jit.dont_look_inside
        def get():
            return [0, 0]
        def fn(n):
            a = get()
            a[0] = n
            jit.hint(n, promote=True)
            x1 = a[0]
            jit.hint(x1, promote=True)
            a[n - n] = n + 1
            return a[0] + x1
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1
        self.check_operations_history(getarrayitem_gc_i=0, guard_value=1)
        res = self.interp_operations(fn, [-7])
        assert res == -7 - 7 + 1
        self.check_operations_history(getarrayitem_gc_i=0, guard_value=1)


    def test_list_caching(self):
        @jit.dont_look_inside
        def get():
            return [0, 0]
        def fn(n):
            a = get()
            if not n > 0:
                if n < -1000:
                    a.append(5)
            a[0] = n
            x1 = a[0]
            a[n - n] = n + 1
            return a[0] + x1
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1
        self.check_operations_history(getarrayitem_gc_i=1,
                getfield_gc_r=1)
        res = self.interp_operations(fn, [-7])
        assert res == -7 - 7 + 1
        self.check_operations_history(getarrayitem_gc_i=1,
                getfield_gc_r=1)

        def fn(n, ca, cb):
            a1 = get()
            a2 = get()
            a1[0] = n
            a2[0] = n
            a = a1
            if ca:
                a = a2
                if n < -100:
                    a.append(5)
            b = a1
            if cb:
                b = a
            return a[0] + b[0]
        res = self.interp_operations(fn, [7, 0, 1])
        assert res == 7 * 2
        self.check_operations_history(getarrayitem_gc_i=1,
                getfield_gc_r=2)
        res = self.interp_operations(fn, [-7, 1, 1])
        assert res == -7 * 2
        self.check_operations_history(getarrayitem_gc_i=0,
                getfield_gc_r=2)

    def test_list_caching_negative(self):
        def fn(n):
            a = [0] * n
            if n > 1000:
                a.append(0)
            a[-1] = n
            x1 = a[-1]
            a[n - n - 1] = n + 1
            return a[-1] + x1 + 1000 * a[2]
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1
        self.check_operations_history(setarrayitem_gc=2,
                setfield_gc=2, call_n=0, call_i=0, call_r=0)

    def test_list_caching_negative_nonzero_init(self):
        def fn(n):
            a = [42] * n
            if n > 1000:
                a.append(0)
            a[-1] = n
            x1 = a[-1]
            a[n - n - 1] = n + 1
            return a[-1] + x1 + 1000 * a[2]
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1 + 42000
        self.check_operations_history(setarrayitem_gc=2,
                setfield_gc=0, call_r=1)

    def test_virtualizable_with_array_heap_cache(self):
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'x', 'i', 'frame'],
                                    virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['l[*]', 's']

            def __init__(self, a, s):
                self = jit.hint(self, access_directly=True, fresh_virtualizable=True)
                self.l = [0] * (4 + a)
                self.s = s

        def f(n, a, i):
            frame = Frame(a, 0)
            frame.l[0] = a
            frame.l[1] = a + 1
            frame.l[2] = a + 2
            frame.l[3] = a + 3
            if not i:
                return frame.l[0] + len(frame.l)
            x = 0
            while n > 0:
                myjitdriver.can_enter_jit(frame=frame, n=n, x=x, i=i)
                myjitdriver.jit_merge_point(frame=frame, n=n, x=x, i=i)
                frame.s = jit.promote(frame.s)
                n -= 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                frame.s += 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                x += len(frame.l)
                x += f(n, n, 0)
                frame.s -= 1
            return x

        res = self.meta_interp(f, [10, 1, 1], listops=True)
        assert res == f(10, 1, 1)
        self.check_history(getarrayitem_gc_i=0, getfield_gc_i=0,
                           getfield_gc_r=0)


    def test_nonstandard_virtualizable(self):
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'x', 'i', 'frame'],
                                    virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['s']

            def __init__(self, s):
                self.s = s
                self.next = None

        def f(n, a, i):
            frame = Frame(5)
            x = 0
            while n > 0:
                myjitdriver.can_enter_jit(frame=frame, n=n, x=x, i=i)
                myjitdriver.jit_merge_point(frame=frame, n=n, x=x, i=i)
                n -= 1
                s = frame.s
                assert s >= 0
                frame.s += 1
                # make a new frame
                f = Frame(7)
                frame.next = f
                x += f.s
                frame.s -= 1
                frame.next = None
            return x

        res = self.meta_interp(f, [10, 1, 1], listops=True)
        assert res == f(10, 1, 1)
        # we now that f is not the standard virtualizable, since we've seen its
        # allocation
        self.check_history(ptr_eq=0)


    def test_heap_caching_array_pure(self):
        class A(object):
            pass
        p1 = A()
        p2 = A()
        def fn(n):
            if n >= 0:
                a = (n, n + 1)
                p = p1
            else:
                a = (n + 1, n)
                p = p2
            p.x = a

            return p.x[0] + p.x[1]
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7 + 1
        self.check_operations_history(getfield_gc_r=0)
        res = self.interp_operations(fn, [-7])
        assert res == -7 - 7 + 1
        self.check_operations_history(getfield_gc_r=0)

    def test_heap_caching_and_elidable_function(self):
        class A:
            pass
        @jit.dont_look_inside
        def get():
            return A()
        @jit.elidable
        def f(b):
            return b + 1
        def fn(n):
            if n > 0:
                a = get()
            else:
                a = A()
            a.x = n
            z = f(6)
            return z + a.x
        res = self.interp_operations(fn, [7])
        assert res == 7 + 7
        self.check_operations_history(getfield_gc_i=0)
        res = self.interp_operations(fn, [-7])
        assert res == -7 + 7
        self.check_operations_history(getfield_gc_i=0)

    def test_heap_caching_multiple_objects(self):
        class Gbl(object):
            pass
        g = Gbl()
        class A(object):
            pass
        a1 = A()
        g.a1 = a1
        a1.x = 7
        a2 = A()
        g.a2 = a2
        a2.x = 7
        def gn(a1, a2):
            return a1.x + a2.x
        def fn(n):
            if n < 0:
                a1 = A()
                g.a1 = a1
                a1.x = n
                a2 = A()
                g.a2 = a2
                a2.x = n - 1
            else:
                a1 = g.a1
                a2 = g.a2
            return a1.x + a2.x + gn(a1, a2)
        res = self.interp_operations(fn, [-7])
        assert res == 2 * -7 + 2 * -8
        self.check_operations_history(setfield_gc=4, getfield_gc_i=0,
                                      getfield_gc_r=0)
        res = self.interp_operations(fn, [7])
        assert res == 4 * 7
        self.check_operations_history(getfield_gc_i=2, getfield_gc_r=2)

    def test_heap_caching_quasi_immutable(self):
        class A:
            _immutable_fields_ = ['x?']
        a1 = A()
        a1.x = 5
        a2 = A()
        a2.x = 7

        @jit.elidable
        def get(n):
            if n > 0:
                return a1
            return a2

        def g(a):
            return a.x

        def fn(n):
            jit.promote(n)
            a = get(n)
            return g(a) + a.x
        res = self.interp_operations(fn, [7])
        assert res == 10
        self.check_operations_history(quasiimmut_field=1)

    def test_heap_caching_quasi_immutable_2(self):
        class A:
            _immutable_fields_ = ['x?']
        a1 = A()
        a1.x = 5
        a2 = A()
        a2.x = 7

        @jit.elidable
        def get(n):
            if n > 0:
                return a1
            return a2

        def g(a):
            return a.x

        def fn(n):
            jit.promote(n)
            return get(n).x + get(n).x
        res = self.interp_operations(fn, [7])
        assert res == 10
        self.check_operations_history(quasiimmut_field=1)



    def test_heap_caching_multiple_tuples(self):
        class Gbl(object):
            pass
        g = Gbl()
        def gn(a1, a2):
            return a1[0] + a2[0]
        def fn(n):
            a1 = (n, )
            g.a = a1
            a2 = (n - 1, )
            g.a = a2
            jit.promote(n)
            return a1[0] + a2[0] + gn(a1, a2)
        res = self.interp_operations(fn, [7])
        assert res == 2 * 7 + 2 * 6
        self.check_operations_history(getfield_gc_i=0,
                                      getfield_gc_r=0)
        res = self.interp_operations(fn, [-7])
        assert res == 2 * -7 + 2 * -8
        self.check_operations_history(getfield_gc_i=0,
                                      getfield_gc_r=0)

    def test_heap_caching_multiple_arrays(self):
        class Gbl(object):
            pass
        g = Gbl()
        def fn(n):
            a1 = [n, n, n]
            g.a = a1
            a1[0] = n
            a2 = [n, n, n]
            g.a = a2
            a2[0] = n - 1
            return a1[0] + a2[0] + a1[0] + a2[0]
        res = self.interp_operations(fn, [7])
        assert res == 2 * 7 + 2 * 6
        self.check_operations_history(getarrayitem_gc_i=0)
        res = self.interp_operations(fn, [-7])
        assert res == 2 * -7 + 2 * -8
        self.check_operations_history(getarrayitem_gc_i=0)

    def test_heap_caching_multiple_arrays_getarrayitem(self):
        class Gbl(object):
            pass
        g = Gbl()
        g.a1 = [7, 8, 9]
        g.a2 = [8, 9, 10, 11]

        def fn(i):
            if i < 0:
                g.a1 = [7, 8, 9]
                g.a2 = [7, 8, 9, 10]
            jit.promote(i)
            a1 = g.a1
            a1[i + 1] = 15 # make lists mutable
            a2 = g.a2
            a2[i + 1] = 19
            return a1[i] + a2[i] + a1[i] + a2[i]
        res = self.interp_operations(fn, [0])
        assert res == 2 * 7 + 2 * 8
        self.check_operations_history(getarrayitem_gc_i=2)


    def test_heap_caching_multiple_lists(self):
        class Gbl(object):
            pass
        g = Gbl()
        g.l = []
        def fn(n):
            if n < -100:
                g.l.append(1)
            a1 = [n, n, n]
            g.l = a1
            a1[0] = n
            a2 = [n, n, n]
            g.l = a2
            a2[0] = n - 1
            return a1[0] + a2[0] + a1[0] + a2[0]
        res = self.interp_operations(fn, [7])
        assert res == 2 * 7 + 2 * 6
        self.check_operations_history(getarrayitem_gc_i=0, getfield_gc_i=0,
                                      getfield_gc_r=0)
        res = self.interp_operations(fn, [-7])
        assert res == 2 * -7 + 2 * -8
        self.check_operations_history(getarrayitem_gc_i=0, getfield_gc_i=0,
                                      getfield_gc_r=0)

    def test_length_caching(self):
        class Gbl(object):
            pass
        g = Gbl()
        g.a = [0] * 7
        def fn(n):
            a = g.a
            res = len(a) + len(a)
            a1 = [0] * n
            g.a = a1
            return len(a1) + res
        res = self.interp_operations(fn, [7], backendopt=True)
        assert res == 7 * 3
        self.check_operations_history(arraylen_gc=1)

    def test_arraycopy(self):
        class Gbl(object):
            pass
        g = Gbl()
        g.a = [0] * 7
        def fn(n):
            assert n >= 0
            a = g.a
            x = [0] * n
            x[2] = 21
            return len(a[:n]) + x[2]
        res = self.interp_operations(fn, [3], backendopt=True)
        assert res == 24
        self.check_operations_history(getarrayitem_gc_i=0)

    def test_fold_int_add_ovf(self):
        def fn(n):
            jit.promote(n)
            try:
                n = ovfcheck(n + 1)
            except OverflowError:
                return 12
            else:
                return n
        res = self.interp_operations(fn, [3])
        assert res == 4
        self.check_operations_history(int_add_ovf=0)
        res = self.interp_operations(fn, [sys.maxint])
        assert res == 12

    def test_opaque_list(self):
        from rpython.rlib.rerased import new_erasing_pair
        erase, unerase = new_erasing_pair("test_opaque_list")
        def fn(n, ca, cb):
            l1 = [n]
            l2 = [n]
            a1 = erase(l1)
            a2 = erase(l1)
            a = a1
            if ca:
                a = a2
                if n < -100:
                    unerase(a).append(5)
            b = a1
            if cb:
                b = a
            return unerase(a)[0] + unerase(b)[0]
        res = self.interp_operations(fn, [7, 0, 1])
        assert res == 7 * 2
        self.check_operations_history(getarrayitem_gc_i=0,
                getfield_gc_i=0, getfield_gc_r=0)
        res = self.interp_operations(fn, [-7, 1, 1])
        assert res == -7 * 2
        self.check_operations_history(getarrayitem_gc_i=0,
                getfield_gc_i=0, getfield_gc_r=0)

    def test_copy_str_content(self):
        def fn(n):
            a = StringBuilder()
            x = [1]
            a.append("hello world")
            return x[0]
        res = self.interp_operations(fn, [0])
        assert res == 1
        self.check_operations_history(getarrayitem_gc_i=0,
                                      getarrayitem_gc_pure_i=0)

    def test_raise_known_class_no_guard_class(self):
        def raise_exc(cls):
            raise cls

        def fn(n):
            if n:
                cls = ValueError
            else:
                cls = TypeError
            try:
                raise_exc(cls)
            except ValueError:
                return -1
            return n

        res = self.interp_operations(fn, [1])
        assert res == -1
        self.check_operations_history(guard_class=0)

    def test_dont_record_setfield_gc_zeros(self):
        py.test.skip("see test_unescaped_write_zero in test_ajit")
        class A(object):
            pass

        def make_a():
            return A()
        make_a._dont_inline_ = True

        def fn(n):
            a = make_a()
            a.x = jit.promote(n)
            return a.x

        res = self.interp_operations(fn, [0])
        assert res == 0
        self.check_operations_history(setfield_gc=0)

    def test_record_known_class_does_not_invalidate(self):
        class A:
            pass
        class B(A):
            pass
        class C(object):
            _immutable_fields_ = ['x?']
        c = C()
        c.x = 5
        c.b = A()
        c.b.x = 14
        def fn(n):
            if n == 99:
                c.x = 12
                c.b = B()
                c.b.x = 12
                return 15
            b = c.b
            x = b.x
            jit.record_exact_class(c.b, A)
            y = b.x
            return x + y
        res = self.interp_operations(fn, [1])
        assert res == 2 * 14
        self.check_operations_history(getfield_gc_i=1)

    def test_loop_invariant1(self):
        class A(object):
            pass
        a = A()
        a.current_a = A()
        a.current_a.x = 1
        @jit.loop_invariant
        def f():
            return a.current_a

        @jit.loop_invariant
        def f1():
            return a.current_a

        def g(x):
            res = 0
            res += f().x
            res += f().x
            res += f().x
            res += f1().x # not reused!
            res += f1().x
            if x > 1000:
                a.current_a = A()
                a.current_a.x = 2
            return res
        res = self.interp_operations(g, [21])
        assert res == g(21)
        self.check_operations_history(call_loopinvariant_r=2)

    def test_heapcache_interiorfields(self):
        def fn(n):
            d = {1: n, 2: n}
            d[4] = n + 1
            return d[4]
        res = self.interp_operations(fn, [0])
        assert res == 1
        self.check_operations_history(getinteriorfield_gc_i=0)

