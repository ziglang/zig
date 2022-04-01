class AppTestReduce:

    def test_None(self):
        from _functools import reduce
        raises(TypeError, reduce, lambda x, y: x+y, [1,2,3], None)

    def test_sum(self):
        from _functools import reduce
        assert reduce(lambda x, y: x+y, [1,2,3,4], 0) == 10
        assert reduce(lambda x, y: x+y, [1,2,3,4]) == 10

    def test_minus(self):
        from _functools import reduce
        assert reduce(lambda x, y: x-y, [10, 2, 8]) == 0
        assert reduce(lambda x, y: x-y, [2, 8], 10) == 0

    def test_from_cpython(self):
        from _functools import reduce
        class SequenceClass(object):
            def __init__(self, n):
                self.n = n
            def __getitem__(self, i):
                if 0 <= i < self.n:
                    return i
                else:
                    raise IndexError

        from operator import add
        assert reduce(add, SequenceClass(5)) == 10
        assert reduce(add, SequenceClass(5), 42) == 52
        raises(TypeError, reduce, add, SequenceClass(0))
        assert reduce(add, SequenceClass(0), 42) == 42
        assert reduce(add, SequenceClass(1)) == 0
        assert reduce(add, SequenceClass(1), 42) == 42

        d = {"one": 1, "two": 2, "three": 3}
        assert reduce(add, d) == "".join(d.keys())
