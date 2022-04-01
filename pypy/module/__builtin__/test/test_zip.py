class AppTestZip:

    def test_zip_no_arguments(self):
        import sys
        if sys.version_info < (2,4):
            # Test 2.3 behaviour
            raises(TypeError, zip)
        else:
            # Test 2.4 behaviour
            assert list(zip()) ==  []
            assert list(zip(*[])) == []

    def test_one_list(self):
        assert list(zip([1, 2, 3])) == [(1,), (2,), (3,)]

    def test_two_lists(self):
        # uses a different code path
        assert list(zip([1, 2, 3], [3, 4, 5])) == [(1, 3), (2, 4), (3, 5)]
        assert list(zip([1, 2, 3], [3, 4])) == [(1, 3), (2, 4)]
        assert list(zip([1, 2], [3, 4, 5])) == [(1, 3), (2, 4)]

    def test_three_lists_same_size(self):
        assert list(zip([1, 2, 3], [3, 4, 5], [6, 7, 8])) == (
                          [(1, 3, 6), (2, 4, 7), (3, 5, 8)])

    def test_three_lists_different_sizes(self):
        assert list(zip([1, 2], [3, 4, 5, 6], [6, 7, 8])) == (
                          [(1, 3, 6), (2, 4, 7)])

    def test_tuples(self):
        assert list(zip((1, 2, 3))) == [(1,), (2,), (3,)]

    def test_string(self):
        assert list(zip('hello')) == [('h',), ('e',), ('l',), ('l',), ('o',)]

    def test_strings(self):
        assert list(zip('hello', 'bye')) == (
                         [('h', 'b'), ('e', 'y'), ('l', 'e')])

    def test_mixed_types(self):
        assert list(zip('hello', [1,2,3,4], (7,8,9,10))) == (
                         [('h', 1, 7), ('e', 2, 8), ('l', 3, 9), ('l', 4, 10)])

class AppTestZip2:
    def test_zip(self):
        it = zip()
        raises(StopIteration, next, it)

        obj_list = [object(), object(), object()]
        it = zip(obj_list)
        for x in obj_list:
            assert next(it) == (x, )
        raises(StopIteration, next, it)

        it = zip([1, 2, 3], [4], [5, 6])
        assert next(it) == (1, 4, 5)
        raises(StopIteration, next, it)

        it = zip([], [], [1], [])
        raises(StopIteration, next, it)

        # Up to one additional item may be consumed per iterable, as per python docs
        it1 = iter([1, 2, 3, 4, 5, 6])
        it2 = iter([5, 6])
        it = zip(it1, it2)
        for x in [(1, 5), (2, 6)]:
            assert next(it) == x
        raises(StopIteration, next, it)
        assert next(it1) in [3, 4]
        #---does not work in CPython 2.5
        #raises(StopIteration, it.next)
        #assert it1.next() in [4, 5]

    def test_zip_wrongargs(self):
        # Duplicate python 2.4 behaviour for invalid arguments
        raises(TypeError, zip, None, 0)

        # The error message should indicate which argument was dodgy
        for x in range(10):
            args = [()] * x + [None] + [()] * (9 - x)
            try:
                zip(*args)
            except TypeError as e:
                assert str(e).find("#" + str(x + 1) + " ") >= 0
            else:
                fail("TypeError expected")
