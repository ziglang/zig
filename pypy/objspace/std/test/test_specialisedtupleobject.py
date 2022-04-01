from pypy.objspace.std.specialisedtupleobject import _specialisations
from pypy.objspace.std.test import test_tupleobject
from pypy.objspace.std.tupleobject import W_TupleObject
from pypy.objspace.std.longobject import W_LongObject
from rpython.rlib.rbigint import rbigint
from pypy.tool.pytest.objspace import gettestobjspace


for cls in _specialisations:
    globals()[cls.__name__] = cls


class TestW_SpecialisedTupleObject():
    spaceconfig = {"objspace.std.withspecialisedtuple": True}

    def test_isspecialisedtupleobjectintint(self):
        w_tuple = self.space.newtuple([self.space.wrap(1), self.space.wrap(2)])
        assert isinstance(w_tuple, W_SpecialisedTupleObject_ii)

    def test_isnotspecialisedtupleobject(self):
        w_tuple = self.space.newtuple([self.space.wrap({})])
        assert not 'W_SpecialisedTupleObject' in type(w_tuple).__name__

    def test_specialisedtupleclassname(self):
        w_tuple = self.space.newtuple([self.space.wrap(1), self.space.wrap(2)])
        assert w_tuple.__class__.__name__ == 'W_SpecialisedTupleObject_ii'

    def test_integer_strategy_with_w_long(self):
        w = W_LongObject(rbigint.fromlong(42))
        w_tuple = self.space.newtuple([w, w])
        assert w_tuple.__class__.__name__ == 'W_SpecialisedTupleObject_ii'

    def hash_test(self, values, must_be_specialized):
        N_values_w = [self.space.wrap(value) for value in values]
        S_values_w = [self.space.wrap(value) for value in values]
        N_w_tuple = W_TupleObject(N_values_w)
        S_w_tuple = self.space.newtuple(S_values_w)

        if must_be_specialized:
            assert 'W_SpecialisedTupleObject' in type(S_w_tuple).__name__
        assert self.space.is_true(self.space.eq(N_w_tuple, S_w_tuple))
        assert self.space.is_true(
                self.space.eq(self.space.hash(N_w_tuple),
                              self.space.hash(S_w_tuple)))

    def test_hash_against_normal_tuple(self):
        def hash_test(values, must_be_specialized=True):
            self.hash_test(values, must_be_specialized=must_be_specialized)
        hash_test([-1, -1])
        hash_test([-1.0, -1.0])
        hash_test([1, 2])
        hash_test([1.5, 2.8])
        hash_test([1.0, 2.0])
        hash_test(['arbitrary', 'strings'])
        hash_test([1, (1, 2, 3, 4)])
        hash_test([1, (1, 2)])
        hash_test([1, ('a', 2)])
        hash_test([1, ()])
        hash_test([1, 2, 3], must_be_specialized=False)
        hash_test([1 << 62, 0])

    try:
        from hypothesis import given, strategies
    except ImportError:
        pass
    else:
        _int_float_text = strategies.one_of(
                            strategies.integers(),
                            strategies.floats(),
                            strategies.text())
        @given(_int_float_text, _int_float_text)
        def test_hash_with_hypothesis(self, x, y):
            self.hash_test([x, y], must_be_specialized=False)


class AppTestW_SpecialisedTupleObject:
    spaceconfig = {"objspace.std.withspecialisedtuple": True}

    def w_isspecialised(self, obj, expected=''):
        import __pypy__
        r = __pypy__.internal_repr(obj)
        print(obj, '==>', r, '   (expected: %r)' % expected)
        return ("SpecialisedTupleObject" + expected) in r

    def test_createspecialisedtuple(self):
        have = ['ii', 'ff', 'oo']
        #
        spec = {int: 'i',
                float: 'f',
                str: 's',
                list: 'o'}
        #
        for x in [42, 4.2, "foo", []]:
            for y in [43, 4.3, "bar", []]:
                expected1 = spec[type(x)]
                expected2 = spec[type(y)]
                if expected1 + expected2 not in have:
                    expected1 = expected2 = 'o'
                obj = (x, y)
                assert self.isspecialised(obj, '_' + expected1 + expected2)
        #
        if 'ooo' in have:
            obj = (1, 2, 3)
            assert self.isspecialised(obj, '_ooo')

    def test_len(self):
        t = (42, 43)
        assert len(t) == 2

    def test_notspecialisedtuple(self):
        assert not self.isspecialised((42, 43, 44, 45))
        assert not self.isspecialised((1.5,))

    def test_slicing_to_specialised(self):
        t = (1, 2, 3)
        assert self.isspecialised(t[0:2])
        t = (1, '2', 3)
        assert self.isspecialised(t[0:5:2])

    def test_adding_to_specialised(self):
        t = (1,)
        assert self.isspecialised(t + (2,))

    def test_multiply_to_specialised(self):
        t = (1,)
        assert self.isspecialised(t * 2)

    def test_slicing_from_specialised(self):
        t = (1, 2, 3)
        assert t[0:2:1] == (1, 2)

    def test_eq_no_delegation(self):
        t = (1,)
        a = t + (2,)
        b = (1, 2)
        assert a == b

        c = (2, 1)
        assert not a == c

    def test_eq_can_delegate(self):
        a = (1, 2)
        b = (1, 3, 2)
        assert not a == b

        values = [2, 2.0, 1, 1.0]
        for x in values:
            for y in values:
                assert ((1, 2) == (x, y)) == (1 == x and 2 == y)

    def test_neq(self):
        a = (1, 2)
        b = (1,)
        b = b + (2,)
        assert not a != b

        c = (1, 3)
        assert a != c

    def test_ordering(self):
        a = (1, 2)
        assert a < (2, 2)
        assert a < (1, 3)
        assert not a < (1, 2)

        assert a <= (2, 2)
        assert a <= (1, 2)
        assert not a <= (1, 1)

        assert a >= (0, 2)
        assert a >= (1, 2)
        assert not a >= (1, 3)

        assert a > (0, 2)
        assert a > (1, 1)
        assert not a > (1, 3)

        assert (2, 2) > a
        assert (1, 3) > a
        assert not (1, 2) > a

        assert (2, 2) >= a
        assert (1, 2) >= a
        assert not (1, 1) >= a

        assert (0, 2) <= a
        assert (1, 2) <= a
        assert not (1, 3) <= a

        assert (0, 2) < a
        assert (1, 1) < a
        assert not (1, 3) < a

    def test_hash(self):
        a = (1, 2)
        b = (1,)
        b += (2,)  # else a and b refer to same constant
        assert hash(a) == hash(b)

        c = (2, 4)
        assert hash(a) != hash(c)

        assert hash(a) == hash((1, 2)) == hash((1.0, 2.0)) == hash((1.0, 2))

        d = tuple([-1, 1])
        e = (-1, 1)
        assert d == e
        assert hash(d) == hash(e)

        x = (-1, -1)
        y = tuple([-1, -1])
        assert hash(x) == hash(y)

    def test_getitem(self):
        t = (5, 3)
        assert (t)[0] == 5
        assert (t)[1] == 3
        assert (t)[-1] == 3
        assert (t)[-2] == 5
        raises(IndexError, "t[2]")
        raises(IndexError, "t[-3]")

    def test_three_tuples(self):
        if not self.isspecialised((1, 2, 3)):
            skip("don't have specialization for 3-tuples")
        b = (1, 2, 3)
        c = (1,)
        d = c + (2, 3)
        assert self.isspecialised(d)
        assert b == d

    def test_mongrel(self):
        a = (2.2, '333')
        assert self.isspecialised(a)
        assert len(a) == 2
        assert a[0] == 2.2 and a[1] == '333'
        b = ('333',)
        assert a == (2.2,) + b
        assert not a != (2.2,) + b
        #
        if not self.isspecialised((1, 2, 3)):
            skip("don't have specialization for 3-tuples")
        a = (1, 2.2, '333')
        assert self.isspecialised(a)
        assert len(a) == 3
        assert a[0] == 1 and a[1] == 2.2 and a[2] == '333'
        b = ('333',)
        assert a == (1, 2.2,) + b
        assert not a != (1, 2.2) + b

    def test_subclasses(self):
        class I(int): pass
        class F(float): pass
        t = (I(42), I(43))
        assert type(t[0]) is I
        t = (F(42), F(43))
        assert type(t[0]) is F

    def test_ovfl_bug(self):
        # previously failed
        a = (0xffffffffffffffff, 0)

    def test_bug_tuples_of_nans(self):
        N = float('nan')
        T = (N, N)
        assert N in T
        assert T == (N, N)
        assert (0.0, 0.0) == (-0.0, -0.0)

    def test_issue3301_exactly_two_bases(self):
        # used to fail because the 2-tuple of bases gets specialized;
        # the test would always pass with any number of bases != 2...
        class BaseA: pass
        class BaseB: pass
        class Foo(BaseA, BaseB): pass
        assert not hasattr(Foo, '__orig_bases__')


class AppTestAll(test_tupleobject.AppTestW_TupleObject):
    spaceconfig = {"objspace.std.withspecialisedtuple": True}
