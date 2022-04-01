import pytest
from pypy.interpreter.error import OperationError
from pypy.objspace.std.tupleobject import W_TupleObject


class TestW_TupleObject:
    def test_is_true(self):
        w = self.space.wrap
        w_tuple = W_TupleObject([])
        assert self.space.is_true(w_tuple) is False
        w_tuple = W_TupleObject([w(5)])
        assert self.space.is_true(w_tuple) is True
        w_tuple = W_TupleObject([w(5), w(3)])
        assert self.space.is_true(w_tuple) is True

    def test_len(self):
        w = self.space.wrap
        w_tuple = W_TupleObject([])
        assert self.space.eq_w(self.space.len(w_tuple), w(0))
        w_tuple = W_TupleObject([w(5)])
        assert self.space.eq_w(self.space.len(w_tuple), w(1))
        w_tuple = W_TupleObject([w(5), w(3), w(99)] * 111)
        assert self.space.eq_w(self.space.len(w_tuple), w(333))

    def test_getitem(self):
        w = self.space.wrap
        w_tuple = W_TupleObject([w(5), w(3)])
        assert self.space.eq_w(self.space.getitem(w_tuple, w(0)), w(5))
        assert self.space.eq_w(self.space.getitem(w_tuple, w(1)), w(3))
        assert self.space.eq_w(self.space.getitem(w_tuple, w(-2)), w(5))
        assert self.space.eq_w(self.space.getitem(w_tuple, w(-1)), w(3))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_tuple, w(2))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_tuple, w(42))
        self.space.raises_w(self.space.w_IndexError,
                            self.space.getitem, w_tuple, w(-3))

    def test_iter(self):
        w = self.space.wrap
        w_tuple = W_TupleObject([w(5), w(3), w(99)])
        w_iter = self.space.iter(w_tuple)
        assert self.space.eq_w(self.space.next(w_iter), w(5))
        assert self.space.eq_w(self.space.next(w_iter), w(3))
        assert self.space.eq_w(self.space.next(w_iter), w(99))
        pytest.raises(OperationError, self.space.next, w_iter)
        pytest.raises(OperationError, self.space.next, w_iter)

    def test_contains(self):
        w = self.space.wrap
        w_tuple = W_TupleObject([w(5), w(3), w(99)])
        assert self.space.eq_w(self.space.contains(w_tuple, w(5)),
                           self.space.w_True)
        assert self.space.eq_w(self.space.contains(w_tuple, w(99)),
                           self.space.w_True)
        assert self.space.eq_w(self.space.contains(w_tuple, w(11)),
                           self.space.w_False)
        assert self.space.eq_w(self.space.contains(w_tuple, w_tuple),
                           self.space.w_False)

    def test_add(self):
        w = self.space.wrap
        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(-7)] * 111)
        assert self.space.eq_w(self.space.add(w_tuple1, w_tuple1),
                           W_TupleObject([w(5), w(3), w(99),
                                          w(5), w(3), w(99)]))
        assert self.space.eq_w(self.space.add(w_tuple1, w_tuple2),
                           W_TupleObject([w(5), w(3), w(99)] + [w(-7)] * 111))
        assert self.space.eq_w(self.space.add(w_tuple1, w_tuple0), w_tuple1)
        assert self.space.eq_w(self.space.add(w_tuple0, w_tuple2), w_tuple2)

    def test_mul(self):
        # only testing right mul at the moment
        w = self.space.wrap
        arg = w(2)
        n = 3
        w_tup = W_TupleObject([arg])
        w_tup3 = W_TupleObject([arg] * n)
        w_res = self.space.mul(w_tup, w(n))
        assert self.space.eq_w(w_tup3, w_res)
        # commute
        w_res = self.space.mul(w(n), w_tup)
        assert self.space.eq_w(w_tup3, w_res)
        # check tuple*1 is identity (optimisation tested by CPython tests)
        w_res = self.space.mul(w_tup, w(1))
        assert w_res is w_tup

    def test_getslice(self):
        w = self.space.wrap

        def test1(testtuple, start, stop, step, expected):
            w_slice = self.space.newslice(w(start), w(stop), w(step))
            w_tuple = W_TupleObject([w(i) for i in testtuple])
            w_result = self.space.getitem(w_tuple, w_slice)
            assert self.space.unwrap(w_result) == expected

        for testtuple in [(), (5, 3, 99), tuple(range(5, 555, 10))]:
            for start in [-2, -1, 0, 1, 10]:
                for end in [-1, 0, 2, 999]:
                    test1(testtuple, start, end, 1, testtuple[start:end])

        test1((5, 7, 1, 4), 3, 1, -2,  (4,))
        test1((5, 7, 1, 4), 3, 0, -2,  (4, 7))
        test1((5, 7, 1, 4), 3, -1, -2, ())
        test1((5, 7, 1, 4), -2, 11, 2, (1,))
        test1((5, 7, 1, 4), -3, 11, 2, (7, 4))
        test1((5, 7, 1, 4), -5, 11, 2, (5, 1))

    def test_eq(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])

        assert self.space.eq_w(self.space.eq(w_tuple0, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.eq(w_tuple1, w_tuple0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.eq(w_tuple1, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.eq(w_tuple1, w_tuple2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.eq(w_tuple2, w_tuple3),
                           self.space.w_False)

    def test_ne(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])

        assert self.space.eq_w(self.space.ne(w_tuple0, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ne(w_tuple1, w_tuple0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ne(w_tuple1, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ne(w_tuple1, w_tuple2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ne(w_tuple2, w_tuple3),
                           self.space.w_True)

    def test_lt(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])
        w_tuple4 = W_TupleObject([w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.lt(w_tuple0, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.lt(w_tuple1, w_tuple0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_tuple1, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_tuple1, w_tuple2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.lt(w_tuple2, w_tuple3),
                           self.space.w_True)
        assert self.space.eq_w(self.space.lt(w_tuple4, w_tuple3),
                           self.space.w_True)

    def test_ge(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])
        w_tuple4 = W_TupleObject([w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.ge(w_tuple0, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ge(w_tuple1, w_tuple0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_tuple1, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_tuple1, w_tuple2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.ge(w_tuple2, w_tuple3),
                           self.space.w_False)
        assert self.space.eq_w(self.space.ge(w_tuple4, w_tuple3),
                           self.space.w_False)

    def test_gt(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])
        w_tuple4 = W_TupleObject([w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.gt(w_tuple0, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_tuple1, w_tuple0),
                           self.space.w_True)
        assert self.space.eq_w(self.space.gt(w_tuple1, w_tuple1),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_tuple1, w_tuple2),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_tuple2, w_tuple3),
                           self.space.w_False)
        assert self.space.eq_w(self.space.gt(w_tuple4, w_tuple3),
                           self.space.w_False)

    def test_le(self):
        w = self.space.wrap

        w_tuple0 = W_TupleObject([])
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])
        w_tuple4 = W_TupleObject([w(5), w(3), w(9), w(-1)])

        assert self.space.eq_w(self.space.le(w_tuple0, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_tuple1, w_tuple0),
                           self.space.w_False)
        assert self.space.eq_w(self.space.le(w_tuple1, w_tuple1),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_tuple1, w_tuple2),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_tuple2, w_tuple3),
                           self.space.w_True)
        assert self.space.eq_w(self.space.le(w_tuple4, w_tuple3),
                           self.space.w_True)

    def test_hash_consistency(self):
        # make sure that the two copies of the hash implementation are the same
        w = self.space.wrap
        w_tuple1 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple2 = W_TupleObject([w(5), w(3), w(99)])
        w_tuple3 = W_TupleObject([w(5), w(3), w(99), w(-1)])
        w_tuple4 = W_TupleObject([w(5), w(3), w(9), w(-1)])
        for w_tup in w_tuple1, w_tuple2, w_tuple3, w_tuple4:
            assert w_tup._descr_hash_unroll(self.space) == w_tup._descr_hash_jitdriver(self.space)


class AppTestW_TupleObject:
    def test_is_true(self):
        assert not ()
        assert bool((5,))
        assert bool((5, 3))

    def test_len(self):
        assert len(()) == 0
        assert len((5,)) == 1
        assert len((5, 3, 99, 1, 2, 3, 4, 5, 6)) == 9

    def test_getitem(self):
        assert (5, 3)[0] == 5
        assert (5, 3)[1] == 3
        assert (5, 3)[-1] == 3
        assert (5, 3)[-2] == 5
        raises(IndexError, "(5, 3)[2]")
        raises(IndexError, "(5,)[1]")
        raises(IndexError, "()[0]")

    def test_iter(self):
        t = (5, 3, 99)
        i = iter(t)
        assert next(i) == 5
        assert next(i) == 3
        assert next(i) == 99
        raises(StopIteration, next, i)

    def test_contains(self):
        t = (5, 3, 99)
        assert 5 in t
        assert 99 in t
        assert not 11 in t
        assert not t in t

        logger = []

        class Foo(object):

            def __init__(self, value, name=None):
                self.value = value
                self.name = name or value

            def __repr__(self):
                return '<Foo %s>' % self.name

            def __eq__(self, other):
                logger.append((self, other))
                return self.value == other.value

        foo1, foo2, foo3 = Foo(1), Foo(2), Foo(3)
        foo42 = Foo(42)
        foo_tuple = (foo1, foo2, foo3)
        foo42 in foo_tuple
        logger_copy = logger[:]  # prevent re-evaluation during pytest error print
        assert logger_copy == [(foo42, foo1), (foo42, foo2), (foo42, foo3)]

        del logger[:]
        foo2_bis = Foo(2, '2 bis')
        foo2_bis in foo_tuple
        logger_copy = logger[:]  # prevent re-evaluation during pytest error print
        assert logger_copy == [(foo2_bis, foo1), (foo2_bis, foo2)]

    def test_add(self):
        t0 = ()
        t1 = (5, 3, 99)
        assert t0 + t0 == t0
        assert t1 + t0 == t1
        assert t1 + t1 == (5, 3, 99, 5, 3, 99)

    def test_mul(self):
        assert () * 10 == ()
        assert (5,) * 3 == (5, 5, 5)
        assert (5, 2) * 2 == (5, 2, 5, 2)

    def test_mul_identity(self):
        t = (1, 2, 3)
        assert (t * 1) is t

    def test_mul_subtype(self):
        class T(tuple): pass
        t = T([1, 2, 3])
        assert (t * 1) is not t
        assert (t * 1) == t

    def test_getslice_2(self):
        assert (5, 2, 3)[1:2] == (2,)

    def test_eq(self):
        t0 = ()
        t1 = (5, 3, 99)
        t2 = (5, 3, 99)
        t3 = (5, 3, 99, -1)
        t4 = (5, 3, 9, 1)
        assert not t0 == t1
        assert t0 != t1
        assert t1 == t2
        assert t2 == t1
        assert t3 != t2
        assert not t3 == t2
        assert not t2 == t3
        assert t3 > t4
        assert t2 > t4
        assert t3 > t2
        assert t1 > t0
        assert t0 <= t0
        assert not t0 < t0
        assert t4 >= t0
        assert t3 >= t2
        assert t2 <= t3

    def test_hash(self):
        # check that hash behaves as in 3.8
        import sys
        is_32 = sys.maxsize == 2 ** 31 - 1
        def check_one_exact(t, h32, h64):
            h = hash(t)
            if is_32:
                assert h == h32
            else:
                assert h == h64

        check_one_exact((), 750394483, 5740354900026072187)
        check_one_exact((0,), 1214856301, -8753497827991233192)
        check_one_exact((0, 0), -168982784, -8458139203682520985)
        check_one_exact((0.5,), 2077348973, -408149959306781352)
        check_one_exact((0.5, (), (-2, 3, (4, 6))), 714642271,
                        -1845940830829704396)

    def test_getnewargs(self):
        assert () .__getnewargs__() == ((),)

    def test_repr(self):
        assert repr((1,)) == '(1,)'
        assert repr(()) == '()'
        assert repr((1, 2, 3)) == '(1, 2, 3)'
        assert repr(('\xe9',)) == "('\xe9',)"
        assert repr(('\xe9', 1)) == "('\xe9', 1)"

    def test_getslice(self):
        assert ('a', 'b', 'c')[-17: 2] == ('a', 'b')

    def test_count(self):
        assert ().count(4) == 0
        assert (1, 2, 3, 4).count(3) == 1
        assert (1, 2, 3, 4).count(5) == 0
        assert (1, 1, 1).count(1) == 3

    def test_index(self):
        raises(ValueError, ().index, 4)
        (1, 2).index(1) == 0
        (3, 4, 5).index(4) == 1
        raises(ValueError, (1, 2, 3, 4).index, 5)
        assert (4, 2, 3, 4).index(4, 1) == 3
        assert (4, 4, 4).index(4, 1, 2) == 1
        raises(ValueError, (1, 2, 3, 4).index, 4, 0, 2)

    def test_comparison(self):
        assert (() <  ()) is False
        assert (() <= ()) is True
        assert (() == ()) is True
        assert (() != ()) is False
        assert (() >  ()) is False
        assert (() >= ()) is True
        assert ((5,) <  ()) is False
        assert ((5,) <= ()) is False
        assert ((5,) == ()) is False
        assert ((5,) != ()) is True
        assert ((5,) >  ()) is True
        assert ((5,) >= ()) is True
        assert (() <  (5,)) is True
        assert (() <= (5,)) is True
        assert (() == (5,)) is False
        assert (() != (5,)) is True
        assert (() >  (5,)) is False
        assert (() >= (5,)) is False
        assert ((4,) <  (5,)) is True
        assert ((4,) <= (5,)) is True
        assert ((4,) == (5,)) is False
        assert ((4,) != (5,)) is True
        assert ((4,) >  (5,)) is False
        assert ((4,) >= (5,)) is False
        assert ((5,) <  (5,)) is False
        assert ((5,) <= (5,)) is True
        assert ((5,) == (5,)) is True
        assert ((5,) != (5,)) is False
        assert ((5,) >  (5,)) is False
        assert ((5,) >= (5,)) is True
        assert ((6,) <  (5,)) is False
        assert ((6,) <= (5,)) is False
        assert ((6,) == (5,)) is False
        assert ((6,) != (5,)) is True
        assert ((6,) >  (5,)) is True
        assert ((6,) >= (5,)) is True
        N = float('nan')
        assert ((N,) <  (5,)) is False
        assert ((N,) <= (5,)) is False
        assert ((N,) == (5,)) is False
        assert ((N,) != (5,)) is True
        assert ((N,) >  (5,)) is False
        assert ((N,) >= (5,)) is False
        assert ((5,) <  (N,)) is False
        assert ((5,) <= (N,)) is False
        assert ((5,) == (N,)) is False
        assert ((5,) != (N,)) is True
        assert ((5,) >  (N,)) is False
        assert ((5,) >= (N,)) is False

    def test_eq_other_type(self):
        assert (() == object()) is False
        assert ((1,) == object()) is False
        assert ((1, 2) == object()) is False
        assert (() != object()) is True
        assert ((1,) != object()) is True
        assert ((1, 2) != object()) is True


    def test_error_message_wrong_self(self):
        unboundmeth = tuple.__hash__
        e = raises(TypeError, unboundmeth, 42)
        assert "tuple" in str(e.value)
        if hasattr(unboundmeth, 'im_func'):
            e = raises(TypeError, unboundmeth.im_func, 42)
            assert "'tuple'" in str(e.value)

    def test_tuple_new_pos_only(self):
        with raises(TypeError):
            tuple(sequence=[])

    def test_error_not_iteratable(self):
        with raises(TypeError) as excinfo:
            tuple(1)
        assert str(excinfo.value) == "'int' object is not iterable"

