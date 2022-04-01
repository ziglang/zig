import sys
from pypy.objspace.std.sliceobject import normalize_simple_slice


class TestW_SliceObject:

    def test_indices(self):
        space = self.space
        w = space.wrap
        w_None = space.w_None
        w_slice = space.newslice(w_None, w_None, w_None)
        assert w_slice.indices3(space, 6) == (0, 6, 1)
        w_slice = space.newslice(w(0), w(6), w(1))
        assert w_slice.indices3(space, 6) == (0, 6, 1)
        w_slice = space.newslice(w_None, w_None, w(-1))
        assert w_slice.indices3(space, 6) == (5, -1, -1)

    def test_indices_fail(self):
        space = self.space
        w = space.wrap
        w_None = space.w_None
        w_slice = space.newslice(w_None, w_None, w(0))
        self.space.raises_w(space.w_ValueError, w_slice.indices3, space, 10)

    def test_normalize_simple_slice(self):
        space = self.space
        w = space.wrap

        def getslice(length, start, stop):
            # returns range(length)[start:stop] but without special
            # support for negative start or stop
            return [i for i in range(length) if start <= i < stop]

        assert getslice(10, 2, 5) == [2, 3, 4]

        for length in range(5):
            for start in range(-2*length-2, 2*length+3):
                for stop in range(-2*length-2, 2*length+3):
                    mystart, mystop = normalize_simple_slice(space, length,
                                                             w(start), w(stop))
                    assert 0 <= mystart <= mystop <= length
                    assert (getslice(length, start, stop) ==
                            getslice(length, mystart, mystop))


    def test_indexes4(self):
        space = self.space
        w = space.wrap

        def getslice(length, start, stop, step):
            return [i for i in range(0, length, step) if start <= i < stop]

        for step in [-5, -4, -3, -2, -1, 1, 2, 3, 4, 5, None]:
            for length in range(5):
                for start in range(-2*length-2, 2*length+3) + [None]:
                    for stop in range(-2*length-2, 2*length+3) + [None]:
                        sl = space.newslice(w(start), w(stop), w(step))
                        mystart, mystop, mystep, slicelength = sl.indices4(space, length)
                        assert len(range(length)[start:stop:step]) == slicelength
                        if sys.version_info >= (2, 6):   # doesn't work in 2.5
                            assert slice(start, stop, step).indices(length) == (
                                    mystart, mystop, mystep)

class AppTest_SliceObject:
    def test_new(self):
        def cmp_slice(sl1, sl2):
            for attr in "start", "stop", "step":
                if getattr(sl1, attr) != getattr(sl2, attr):
                    return False
            return True
        raises(TypeError, slice)
        raises(TypeError, slice, 1, 2, 3, 4)
        assert cmp_slice(slice(23), slice(None, 23, None))
        assert cmp_slice(slice(23, 45), slice(23, 45, None))

    def test_indices(self):
        assert slice(4,11,2).indices(28) == (4, 11, 2)
        assert slice(4,11,2).indices(8) == (4, 8, 2)
        assert slice(4,11,2).indices(2) == (2, 2, 2)
        assert slice(11,4,-2).indices(28) == (11, 4, -2)
        assert slice(11,4,-2).indices(8) == (7, 4, -2)
        assert slice(11,4,-2).indices(2) == (1, 1, -2)
        assert slice(None, -9).indices(10) == (0, 1, 1)
        assert slice(None, -10, -1).indices(10) == (9, 0, -1)
        assert slice(None, 10, -1).indices(10) == (9, 9, -1)


    def test_repr(self):
        assert repr(slice(1, 2, 3)) == 'slice(1, 2, 3)'
        assert repr(slice(1, 2)) == 'slice(1, 2, None)'
        assert repr(slice('a', 'b')) == "slice('a', 'b', None)"
        
    def test_eq(self):
        slice1 = slice(1, 2, 3)
        slice2 = slice(1, 2, 3)
        assert slice1 == slice2
        assert not slice1 != slice2
        slice2 = slice(1, 2)
        assert slice1 != slice2

    def test_lt(self):
        assert slice(0, 2, 3) < slice(1, 0, 0)
        assert slice(0, 1, 3) < slice(0, 2, 0)
        assert slice(0, 1, 2) < slice(0, 1, 3)
        assert not (slice(1, 2, 3) < slice(0, 0, 0))
        assert not (slice(1, 2, 3) < slice(1, 0, 0))
        assert not (slice(1, 2, 3) < slice(1, 2, 0))
        assert not (slice(1, 2, 3) < slice(1, 2, 3))

    def test_long_indices(self):
        assert slice(-2 ** 100, 10, 1).indices(1000) == (0, 10, 1)
        assert slice(-2 ** 200, -2 ** 100, 1).indices(1000) == (0, 0, 1)
        assert slice(2 ** 100, 0, -1).indices(1000) == (999, 0, -1)
        assert slice(2 ** 100, -2 ** 100, -1).indices(1000) == (999, -1, -1)
        assert slice(0, 1000, 2 ** 200).indices(1000) == (0, 1000, 2 ** 200)
        assert slice(0, 1000, 1).indices(2 ** 100) == (0, 1000, 1)

    def test_reduce(self):
        assert slice(1, 2, 3).__reduce__() == (slice, (1, 2, 3))

    def test_indices_negative_length(self):
        raises(ValueError, "slice(0, 1000, 1).indices(-1)")
