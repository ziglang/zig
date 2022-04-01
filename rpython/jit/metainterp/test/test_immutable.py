from rpython.rlib import jit
from rpython.jit.metainterp.test.support import LLJitMixin

@jit.dont_look_inside
def escape(x):
    return x

class ImmutableFieldsTests:

    def test_fields(self):
        class X(object):
            _immutable_fields_ = ["x"]

            def __init__(self, x):
                self.x = x

        def f(x):
            y = escape(X(x))
            return y.x + 5
        res = self.interp_operations(f, [23])
        assert res == 28
        self.check_operations_history(getfield_gc_i=1, int_add=1)

    def test_fields_subclass(self):
        class X(object):
            _immutable_fields_ = ["x"]

            def __init__(self, x):
                self.x = x

        class Y(X):
            _immutable_fields_ = ["y"]

            def __init__(self, x, y):
                X.__init__(self, x)
                self.y = y

        def f(x, y):
            X(x)     # force the field 'x' to be on class 'X'
            z = escape(Y(x, y))
            return z.x + z.y + 5
        res = self.interp_operations(f, [23, 11])
        assert res == 39
        self.check_operations_history(getfield_gc_i=2, int_add=2)

        def f(x, y):
            # this time, the field 'x' only shows up on subclass 'Y'
            z = escape(Y(x, y))
            return z.x + z.y + 5
        res = self.interp_operations(f, [23, 11])
        assert res == 39
        self.check_operations_history(getfield_gc_i=2, int_add=2)

    def test_array(self):
        class X(object):
            _immutable_fields_ = ["y[*]"]

            def __init__(self, x):
                self.y = x
        def f(index):
            l = [1, 2, 3, 4]
            l[2] = 30
            a = escape(X(l))
            return a.y[index]
        res = self.interp_operations(f, [2], listops=True)
        assert res == 30
        self.check_operations_history(getfield_gc_r=1, getarrayitem_gc_i=0, getarrayitem_gc_pure_i=1)

    def test_array_index_error(self):
        class X(object):
            _immutable_fields_ = ["y[*]"]

            def __init__(self, x):
                self.y = x

            def get(self, index):
                try:
                    return self.y[index]
                except IndexError:
                    return -41

        def f(index):
            l = [1, 2, 3, 4]
            l[2] = 30
            a = escape(X(l))
            return a.get(index)
        res = self.interp_operations(f, [2], listops=True)
        assert res == 30
        self.check_operations_history(getfield_gc_r=1, getarrayitem_gc_i=0, getarrayitem_gc_pure_i=1)

    def test_array_in_immutable(self):
        class X(object):
            _immutable_ = True
            _immutable_fields_ = ["lst[*]"]

            def __init__(self, lst, y):
                self.lst = lst
                self.y = y

        def f(x, index):
            y = escape(X([x], x+1))
            return y.lst[index] + y.y + 5
        res = self.interp_operations(f, [23, 0], listops=True)
        assert res == 23 + 24 + 5
        self.check_operations_history(getfield_gc_r=1, getfield_gc_i=1,
                            getarrayitem_gc_i=0, getarrayitem_gc_pure_i=1,
                            int_add=3)


    def test_raw_field_and_array(self):
        from rpython.rtyper.lltypesystem import lltype
        X = lltype.Struct('X',
            ('a', lltype.Signed),
            ('b', lltype.Array(lltype.Signed,
                               hints={'nolength': True, 'immutable': True})),
            hints={'immutable': True})

        x = lltype.malloc(X, 4, flavor='raw', immortal=True)
        x.a = 6
        x.b[2] = 7
        xlist = [x, lltype.nullptr(X)]
        def g(num):
            if num < 0:
                num = 0
            return num
        g._dont_inline_ = True
        def f(num):
            num = g(num)
            x = xlist[num]
            return x.a * x.b[2]
        #
        res = self.interp_operations(f, [0], disable_optimizations=True)
        assert res == 42
        self.check_operations_history(getfield_raw_i=1,
                                      getarrayitem_raw_i=1,
                                      int_mul=1)
        #
        # second try, in which we get num=0 constant-folded through f()
        res = self.interp_operations(f, [-1], disable_optimizations=True)
        assert res == 42
        self.check_operations_history(getfield_raw_i=0,
                                      getarrayitem_raw_i=0,
                                      int_mul=0)

    def test_read_on_promoted(self):
        # this test used to fail because the n = f.n was staying alive
        # in a box (not a const, as it was read before promote), and
        # thus the second f.n was returning the same box, although it
        # could now return a const.
        class Foo(object):
            _immutable_fields_ = ['n']
            def __init__(self, n):
                self.n = n
        f1 = Foo(42); f2 = Foo(43)
        @jit.dont_look_inside
        def some(m):
            return [f1, f2][m]
        @jit.dont_look_inside
        def do_stuff_with(n):
            print n
        def main(m):
            f = some(m)
            n = f.n
            f = jit.hint(f, promote=True)
            res = f.n * 6
            do_stuff_with(n)
            return res
        res = self.interp_operations(main, [1])
        assert res == 43 * 6
        self.check_operations_history(int_mul=0)   # constant-folded

    def test_read_on_promoted_array(self):
        class Foo(object):
            _immutable_fields_ = ['lst[*]']
            def __init__(self, lst):
                self.lst = lst
        f1 = Foo([42]); f2 = Foo([43])
        @jit.dont_look_inside
        def some(m):
            return [f1, f2][m]
        @jit.dont_look_inside
        def do_stuff_with(n):
            print n
        def main(m):
            f = some(m)
            n = f.lst[0]
            f = jit.hint(f, promote=True)
            res = f.lst[0] * 6
            do_stuff_with(n)
            return res
        res = self.interp_operations(main, [1])
        assert res == 43 * 6
        self.check_operations_history(int_mul=0)   # constant-folded


class TestLLtypeImmutableFieldsTests(ImmutableFieldsTests, LLJitMixin):
    pass
