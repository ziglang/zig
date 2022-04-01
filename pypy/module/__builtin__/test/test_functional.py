class AppTestMap:
    def test_trivial_map_one_seq(self):
        assert list(map(lambda x: x+2, [1, 2, 3, 4])) == [3, 4, 5, 6]

    def test_trivial_map_one_seq_2(self):
        assert list(map(str, [1, 2, 3, 4])) == ['1', '2', '3', '4']

    def test_trivial_map_two_seq(self):
        assert list(map(lambda x,y: x+y,
                             [1, 2, 3, 4],[1, 2, 3, 4])) == (
                         [2, 4, 6, 8])

    def test_trivial_map_sizes_dont_match(self):
        assert list(map(lambda x,y: x+y, [1, 2, 3, 4], [1, 2, 3])) == (
           [2, 4, 6])

    def test_trivial_map_no_arguments(self):
        raises(TypeError, map)

    def test_trivial_map_no_function_no_seq(self):
        raises(TypeError, map, None)

    def test_trivial_map_no_fuction(self):
        m = map(None, [1, 2, 3])    # Don't crash here...
        raises(TypeError, next, m)  # ...but only on first item.

    def test_map_identity1(self):
        a = ['1', 2, 3, 'b', None]
        b = a[:]
        assert list(map(lambda x: x, a)) == a
        assert a == b

    def test_map_badoperation(self):
        a = ['1', 2, 3, 'b', None]
        raises(TypeError, list, map, lambda x: x+1, a)

    def test_map_add(self):
        a = [1, 2, 3, 4]
        b = [0, 1, 1, 1]
        assert list(map(lambda x, y: x+y, a, b)) == [1, 3, 4, 5]

    def test_map_first_item(self):
        a = [1, 2, 3, 4, 5]
        b = [6, 7, 8, 9, 10]
        assert list(map(lambda x, y: x, a, b)) == a

    def test_map_second_item(self):
        a = []
        b = [1, 2, 3, 4, 5]
        assert list(map(lambda x, y: y, a, b)) == a

    def test_map_iterables(self):
        class A(object):
            def __init__(self, n):
                self.n = n
            def __iter__(self):
                return B(self.n)
        class B(object):
            def __init__(self, n):
                self.n = n
            def __next__(self):
                self.n -= 1
                if self.n == 0: raise StopIteration
                return self.n
        result = map(lambda *x:x, A(3), A(8))
        # this also checks that B.next() is not called any more after it
        # raised StopIteration once
        assert list(result) == [(2, 7), (1, 6)]

    def test_repr(self):
        assert repr(map(1, [2])).startswith('<map object ')

class AppTestMap2:

    def test_map(self):
        obj_list = [object(), object(), object()]
        it = map(lambda *x:x, obj_list)
        for x in obj_list:
            assert next(it) == (x, )
        raises(StopIteration, next, it)

        it = map(lambda *x:x, [1, 2, 3], [4], [5, 6])
        assert next(it) == (1, 4, 5)
        raises(StopIteration, next, it)

        it = map(lambda *x:x, [], [], [1], [])
        raises(StopIteration, next, it)

        it = map(str, [0, 1, 0, 1])
        for x in ['0', '1', '0', '1']:
            assert next(it) == x
        raises(StopIteration, next, it)

        import operator
        it = map(operator.add, [1, 2, 3], [4, 5, 6])
        for x in [5, 7, 9]:
            assert next(it) == x
        raises(StopIteration, next, it)

    def test_map_wrongargs(self):
        # Duplicate python 2.4 behaviour for invalid arguments
        it = map(0, [])
        raises(StopIteration, next, it)
        it = map(0, [0])
        raises(TypeError, next, it)
        raises(TypeError, map, None, 0)

        raises(TypeError, map, None)
        raises(TypeError, map, bool)
        raises(TypeError, map, 42)


class AppTestZip:
    def test_one_list(self):
        assert list(zip([1,2,3])) == [(1,), (2,), (3,)]

    def test_three_lists(self):
        assert list(zip([1,2,3], [1,2], [1,2,3])) == [(1,1,1), (2,2,2)]

    def test_bad_length_hint(self):
        class Foo(object):
            def __length_hint__(self):
                return NotImplemented
            def __iter__(self):
                if False:
                    yield None
        assert list(zip(Foo())) == []

    def test_repr(self):
        assert repr(zip([1,2,3], [1,2], [1,2,3])).startswith('<zip object ')


class AppTestFilter:
    def test_None(self):
        assert list(filter(None, ['a', 'b', 1, 0, None])) == ['a', 'b', 1]

    def test_return_type(self):
        txt = "This is a test text"
        assert list(filter(None, txt)) == list(txt)
        tup = ("a", None, 0, [], 1)
        assert list(filter(None, tup)) == ["a", 1]

    def test_function(self):
        assert list(filter(lambda x: x != "a", "a small text")) == list(" smll text")
        assert list(filter(lambda x: x < 20, [3, 33, 5, 55])) == [3, 5]

class AppTestFilter2:
    def test_filter(self):
        it = filter(None, [])
        raises(StopIteration, next, it)

        it = filter(None, [1, 0, 2, 3, 0])
        for x in [1, 2, 3]:
            assert next(it) == x
        raises(StopIteration, next, it)

        def is_odd(arg):
            return (arg % 2 == 1)

        it = filter(is_odd, [1, 2, 3, 4, 5, 6])
        for x in [1, 3, 5]:
            assert next(it) == x
        raises(StopIteration, next, it)

    def test_filter_wrongargs(self):
        it = filter(0, [1])
        raises(TypeError, next, it)

        raises(TypeError, filter, bool, None)


class AppTestRange:
    def test_range(self):
        x = range(2, 9, 3)
        assert x[1] == 5
        assert len(x) == 3
        assert list(x) == [2, 5, 8]
        # test again, to make sure that range() is not its own iterator
        assert list(x) == [2, 5, 8]

    def test_range_toofew(self):
        raises(TypeError, range)

    def test_range_toomany(self):
        raises(TypeError, range,  1, 2, 3, 4)

    def test_range_one(self):
        assert list(range(1)) == [0]

    def test_range_posstartisstop(self):
        assert list(range(1, 1)) == []

    def test_range_negstartisstop(self):
        assert list(range(-1, -1)) == []

    def test_range_zero(self):
        assert list(range(0)) == []

    def test_range_twoargs(self):
        assert list(range(1, 2)) == [1]

    def test_range_decreasingtwoargs(self):
        assert list(range(3, 1)) == []

    def test_range_negatives(self):
        assert list(range(-3)) == []

    def test_range_decreasing_negativestep(self):
        assert list(range(5, -2, -1)) == [5, 4, 3, 2, 1, 0 , -1]

    def test_range_posfencepost1(self):
        assert list(range(1, 10, 3)) == [1, 4, 7]

    def test_range_posfencepost2(self):
        assert list(range(1, 11, 3)) == [1, 4, 7, 10]

    def test_range_posfencepost3(self):
        assert list(range(1, 12, 3)) == [1, 4, 7, 10]

    def test_range_negfencepost1(self):
        assert list(range(-1, -10, -3)) == [-1, -4, -7]

    def test_range_negfencepost2(self):
        assert list(range(-1, -11, -3)) == [-1, -4, -7, -10]

    def test_range_negfencepost3(self):
        assert list(range(-1, -12, -3)) == [-1, -4, -7, -10]

    def test_range_decreasing_negativelargestep(self):
        assert list(range(5, -2, -3)) == [5, 2, -1]

    def test_range_increasing_positivelargestep(self):
        assert list(range(-5, 2, 3)) == [-5, -2, 1]

    def test_range_zerostep(self):
        raises(ValueError, range, 1, 5, 0)

    def test_range_wrong_type(self):
        raises(TypeError, range, "42")

    def test_range_iter(self):
        x = range(2, 9, 3)
        it = iter(x)
        assert iter(it) is it
        assert it.__next__() == 2
        assert it.__next__() == 5
        assert it.__next__() == 8
        raises(StopIteration, it.__next__)
        # test again, to make sure that range() is not its own iterator
        assert iter(x).__next__() == 2

    def test_range_object_with___index__(self):
        class A(object):
            def __index__(self):
                return 5

        assert list(range(A())) == [0, 1, 2, 3, 4]
        assert list(range(0, A())) == [0, 1, 2, 3, 4]
        assert list(range(0, 10, A())) == [0, 5]

        class A2(object):
            def __index__(self):
                return 'quux'
        raises(TypeError, range, A2())

    def test_range_float(self):
        raises(TypeError, range, 0.1)
        raises(TypeError, range, 0.1, 0)
        raises(TypeError, range, 0, 0.1)
        raises(TypeError, range, 0.1, 0, 0)
        raises(TypeError, range, 0, 0.1, 0)
        raises(TypeError, range, 0, 0, 0.1)
        raises(TypeError, range, 0.1, 2.0, 1.1)

    def test_range_long(self):
        import sys
        assert list(range(-2**100)) == []
        assert list(range(0, -2**100)) == []
        assert list(range(0, 2**100, -1)) == []
        assert list(range(0, 2**100, -1)) == []

        a = 10 * sys.maxsize
        assert range(a)[-1] == a-1
        assert range(0, a)[-1] == a-1
        assert range(0, 1, a)[-1] == 0
        assert list(range(a, a+2)) == [a, a+1]
        assert list(range(a+2, a, -1)) == [a+2, a+1]
        assert list(range(a+4, a, -2)) == [a+4, a+2]
        assert list(range(a, a*5, a)) == [a, 2*a, 3*a, 4*a]

    def test_range_cases(self):
        import sys
        for start in [10, 10 * sys.maxsize]:
            for stop in [start-4, start-1, start, start+1, start+4]:
                for step in [1, 2, 3, 4]:
                    lst = list(range(start, stop, step))
                    expected = []
                    a = start
                    while a < stop:
                        expected.append(a)
                        a += step
                    assert lst == expected
                for step in [-1, -2, -3, -4]:
                    lst = list(range(start, stop, step))
                    expected = []
                    a = start
                    while a > stop:
                        expected.append(a)
                        a += step
                    assert lst == expected

    def test_range_contains(self):
        assert 3 in range(5)
        assert 3 not in range(3)
        assert 3 not in range(4, 5)
        assert 3 in range(1, 5, 2)
        assert 3 not in range(0, 5, 2)
        assert '3' not in range(5)

    def test_range_count(self):
        assert range(5).count(3) == 1
        assert type(range(5).count(3)) is int
        assert range(0, 5, 2).count(3) == 0
        assert range(5).count(3.0) == 1
        assert range(5).count('3') == 0

    def test_range_getitem(self):
        assert range(6)[3] == 3
        assert range(6)[-1] == 5
        raises(IndexError, range(6).__getitem__, 6)

    def test_range_slice(self):
        # range objects don't implement equality in 3.2, use the repr
        assert repr(range(6)[2:5]) == 'range(2, 5)'
        assert repr(range(6)[-1:-3:-2]) == 'range(5, 3, -2)'

    def test_large_range(self):
        import sys
        def _range_len(x):
            try:
                length = len(x)
            except OverflowError:
                step = x[1] - x[0]
                length = 1 + ((x[-1] - x[0]) // step)
                return length
            a = -sys.maxsize
            b = sys.maxsize
            expected_len = b - a
            x = range(a, b)
            assert a in x
            assert b not in x
            raises(OverflowError, len, x)
            assert _range_len(x) == expected_len
            assert x[0] == a
            idx = sys.maxsize + 1
            assert x[idx] == a + idx
            assert a[idx:idx + 1][0] == a + idx
            try:
                x[-expected_len - 1]
            except IndexError:
                pass
            else:
                assert False, 'Expected IndexError'
            try:
                x[expected_len]
            except IndexError:
                pass
            else:
                assert False, 'Expected IndexError'

    def test_range_index(self):
        u = range(2)
        assert u.index(0) == 0
        assert u.index(1) == 1
        raises(ValueError, u.index, 2)
        raises(ValueError, u.index, object())
        raises(TypeError, u.index)

        assert range(1, 10, 3).index(4) == 1
        assert range(1, -10, -3).index(-5) == 2

        assert range(10**20).index(1) == 1
        assert range(10**20).index(10**20 - 1) == 10**20 - 1

        raises(ValueError, range(1, 2**100, 2).index, 2**87)
        assert range(1, 2**100, 2).index(2**87+1) == 2**86

        class AlwaysEqual(object):
            def __eq__(self, other):
                return True
        always_equal = AlwaysEqual()
        assert range(10).index(always_equal) == 0

    def test_range_types(self):
        assert 1.0 in range(3)
        assert True in range(3)
        assert 1+0j in range(3)

        class C1:
            def __eq__(self, other): return True
        assert C1() in range(3)

        # Objects are never coerced into other types for comparison.
        class C2:
            def __int__(self): return 1
            def __index__(self): return 1
        assert C2() not in range(3)
        # ..except if explicitly told so.
        assert int(C2()) in range(3)

        # Check that the range.__contains__ optimization is only
        # used for ints, not for instances of subclasses of int.
        class C3(int):
            def __eq__(self, other): return True
        assert C3(11) in range(10)
        assert C3(11) in list(range(10))

    def test_range_reduce(self):
        x = range(2, 9, 3)
        callable, args = x.__reduce__()
        y = callable(*args)
        assert list(y) == list(x)

    def test_range_iter_reduce(self):
        x = iter(range(2, 9, 3))
        next(x)
        callable, args, idx = x.__reduce__()
        y = callable(*args)
        y.__setstate__(idx)
        ylist = list(y)
        xlist = list(x)
        print(ylist)
        print(xlist)
        assert ylist == xlist

    def test_range_iter_reduce_one(self):
        x = iter(range(2, 9))
        next(x)
        callable, args, idx = x.__reduce__()
        y = callable(*args)
        y.__setstate__(idx)
        assert list(y) == list(x)

    def test_lib_python_range_optimization(self):
        x = range(1)
        assert type(reversed(x)) == type(iter(x))

    def test_cpython_issue16029(self):
        import sys
        M = sys.maxsize
        x = range(0, M, M - 1)
        assert x.__reduce__() == (range, (0, M, M - 1))
        x = range(0, -M, 1 - M)
        assert x.__reduce__() == (range, (0, -M, 1 - M))

    def test_cpython_issue16030(self):
        import sys
        M = sys.maxsize
        x = range(0, M, M - 1)
        assert repr(x) == 'range(0, %s, %s)' % (M, M - 1), repr(x)
        x = range(0, -M, 1 - M)
        assert repr(x) == 'range(0, %s, %s)' % (-M, 1 - M), repr(x)

    def test_range_attributes(self):
        rangeobj = range(3, 4, 5)
        assert rangeobj.start == 3
        assert rangeobj.stop == 4
        assert rangeobj.step == 5

        raises(AttributeError, "rangeobj.start = 0")
        raises(AttributeError, "rangeobj.stop = 10")
        raises(AttributeError, "rangeobj.step = 1")
        raises(AttributeError, "del rangeobj.start")
        raises(AttributeError, "del rangeobj.stop")
        raises(AttributeError, "del rangeobj.step")

    def test_comparison(self):
        test_ranges = [range(0), range(0, -1), range(1, 1, 3),
                       range(1), range(5, 6), range(5, 6, 2),
                       range(5, 7, 2), range(2), range(0, 4, 2),
                       range(0, 5, 2), range(0, 6, 2)]
        test_tuples = list(map(tuple, test_ranges))

        # Check that equality of ranges matches equality of the corresponding
        # tuples for each pair from the test lists above.
        ranges_eq = [a == b for a in test_ranges for b in test_ranges]
        tuples_eq = [a == b for a in test_tuples for b in test_tuples]
        assert ranges_eq == tuples_eq

        # Check that != correctly gives the logical negation of ==
        ranges_ne = [a != b for a in test_ranges for b in test_ranges]
        assert ranges_ne == [not x for x in ranges_eq]

        # Equal ranges should have equal hashes.
        for a in test_ranges:
            for b in test_ranges:
                if a == b:
                    assert hash(a) == hash(b)

        # Ranges are unequal to other types (even sequence types)
        assert (range(0) == ()) is False
        assert (() == range(0)) is False
        assert (range(2) == [0, 1]) is False

        # Huge integers aren't a problem.
        assert range(0, 2**100 - 1, 2) == range(0, 2**100, 2)
        assert hash(range(0, 2**100 - 1, 2)) == hash(range(0, 2**100, 2))
        assert range(0, 2**100, 2) != range(0, 2**100 + 1, 2)
        assert (range(2**200, 2**201 - 2**99, 2**100) ==
                range(2**200, 2**201, 2**100))
        assert (hash(range(2**200, 2**201 - 2**99, 2**100)) ==
                hash(range(2**200, 2**201, 2**100)))
        assert (range(2**200, 2**201, 2**100) !=
                range(2**200, 2**201 + 1, 2**100))

        # Order comparisons are not implemented for ranges.
        raises(TypeError, "range(0) < range(0)")
        raises(TypeError, "range(0) > range(0)")
        raises(TypeError, "range(0) <= range(0)")
        raises(TypeError, "range(0) >= range(0)")

class AppTestReversed:
    def test_reversed(self):
        assert isinstance(reversed, type)
        r = reversed("hello")
        assert iter(r) is r
        assert r.__next__() == "o"
        assert r.__next__() == "l"
        assert r.__next__() == "l"
        assert r.__next__() == "e"
        assert r.__next__() == "h"
        raises(StopIteration, r.__next__)
        assert list(reversed(list(reversed("hello")))) == ['h','e','l','l','o']
        raises(TypeError, reversed, reversed("hello"))

    def test_reversed_user_type(self):
        class X(object):
            def __getitem__(self, index):
                return str(index)
            def __len__(self):
                return 5
        assert list(reversed(X())) == ["4", "3", "2", "1", "0"]

    def test_reversed_type_with_no_len(self):
        class X(object):
            def __getitem__(self, key):
                raise ValueError
        raises(TypeError, reversed, X())

    def test_reversed_length_hint(self):
        lst = [1, 2, 3]
        r = reversed(lst)
        assert r.__length_hint__() == 3
        assert next(r) == 3
        assert r.__length_hint__() == 2
        lst.pop()
        assert r.__length_hint__() == 2
        lst.pop()
        assert r.__length_hint__() == 0
        raises(StopIteration, next, r)
        #
        r = reversed(lst)
        assert r.__length_hint__() == 1
        assert next(r) == 1
        assert r.__length_hint__() == 0
        raises(StopIteration, next, r)
        assert r.__length_hint__() == 0


class AppTestAllAny:
    """
    These are copied directly and replicated from the Python 2.5 source code.
    """

    def test_all(self):

        class TestFailingBool(object):
            def __bool__(self):
                raise RuntimeError
        class TestFailingIter(object):
            def __iter__(self):
                raise RuntimeError

        assert all([2, 4, 6]) == True
        assert all([2, None, 6]) == False
        raises(RuntimeError, all, [2, TestFailingBool(), 6])
        raises(RuntimeError, all, TestFailingIter())
        raises(TypeError, all, 10)               # Non-iterable
        raises(TypeError, all)                   # No args
        raises(TypeError, all, [2, 4, 6], [])    # Too many args
        assert all([]) == True                   # Empty iterator
        S = [50, 60]
        assert all([x > 42 for x in S]) == True
        S = [50, 40, 60]
        assert all([x > 42 for x in S]) == False

    def test_any(self):

        class TestFailingBool(object):
            def __bool__(self):
                raise RuntimeError
        class TestFailingIter(object):
            def __iter__(self):
                raise RuntimeError

        assert any([None, None, None]) == False
        assert any([None, 4, None]) == True
        raises(RuntimeError, any, [None, TestFailingBool(), 6])
        raises(RuntimeError, all, TestFailingIter())
        raises(TypeError, any, 10)               # Non-iterable
        raises(TypeError, any)                   # No args
        raises(TypeError, any, [2, 4, 6], [])    # Too many args
        assert any([]) == False                  # Empty iterator
        S = [40, 60, 30]
        assert any([x > 42 for x in S]) == True
        S = [10, 20, 30]
        assert any([x > 42 for x in S]) == False


class AppTestMinMax:
    def test_min(self):
        assert min(1, 2) == 1
        assert min(1, 2, key=lambda x: -x) == 2
        assert min([1, 2, 3]) == 1
        raises(TypeError, min, 1, 2, bar=2)
        raises(TypeError, min, 1, 2, key=lambda x: x, bar=2)
        assert type(min(1, 1.0)) is int
        assert type(min(1.0, 1)) is float
        assert type(min(1, 1.0, 1)) is int
        assert type(min(1.0, 1, 1)) is float
        assert type(min(1, 1, 1.0)) is int
        assert min([], default=-1) == -1
        assert min([1, 2], default=-1) == 1
        raises(TypeError, min, 0, 1, default=-1)
        assert min([], default=None) == None
        raises(TypeError, min, 1, default=0)
        raises(TypeError, min, default=1)
        raises(ValueError, min, [])

    def test_max(self):
        assert max(1, 2) == 2
        assert max(1, 2, key=lambda x: -x) == 1
        assert max([1, 2, 3]) == 3
        raises(TypeError, max, 1, 2, bar=2)
        raises(TypeError, max, 1, 2, key=lambda x: x, bar=2)
        assert type(max(1, 1.0)) is int
        assert type(max(1.0, 1)) is float
        assert type(max(1, 1.0, 1)) is int
        assert type(max(1.0, 1, 1)) is float
        assert type(max(1, 1, 1.0)) is int
        assert max([], default=-1) == -1
        assert max([1, 2], default=3) == 2
        raises(TypeError, min, 0, 1, default=-1)
        assert max([], default=None) == None
        raises(TypeError, max, 1, default=0)
        raises(TypeError, max, default=1)
        raises(ValueError, max, [])

    def test_max_list_and_key(self):
        assert max(["100", "50", "30", "-200"], key=int) == "100"
        assert max("100", "50", "30", "-200", key=int) == "100"

    def test_max_key_is_None_works(self):
        assert max(1, 2, key=None) == 2


try:
    from hypothesis import given, strategies, example
except ImportError:
    pass
else:
    @given(lst=strategies.lists(strategies.integers()))
    def test_map_hypothesis(space, lst):
        print lst
        w_lst = space.appexec([space.wrap(lst[:])], """(lst):
            def change(n):
                if n & 3 == 1:
                    lst.pop(0)
                elif n & 3 == 2:
                    lst.append(100)
                return n * 2
            return list(map(change, lst))
        """)
        expected = []
        i = 0
        while i < len(lst):
            n = lst[i]
            if n & 3 == 1:
                lst.pop(0)
            elif n & 3 == 2:
                lst.append(100)
            expected.append(n * 2)
            i += 1
        assert space.unwrap(w_lst) == expected
