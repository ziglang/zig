from pypy.module.micronumpy import support
from pypy.module.micronumpy.iterators import ArrayIter
from pypy.module.micronumpy.strides import is_c_contiguous, is_f_contiguous
from pypy.module.micronumpy import constants as NPY


class MockArray(object):
    flags = 0

    class dtype:
        elsize = 1

    def __init__(self, shape, strides, start=0):
        self.shape = shape
        self.strides = strides
        self.start = start
        if is_c_contiguous(self):
            self.flags |= NPY.ARRAY_C_CONTIGUOUS
        if is_f_contiguous(self):
            self.flags |= NPY.ARRAY_F_CONTIGUOUS

    def get_shape(self):
        return self.shape

    def get_strides(self):
        return self.strides

class TestIterDirect(object):
    def test_iterator_basic(self):
        #Let's get started, simple iteration in C order with
        #contiguous layout => strides[-1] is 1
        shape = [3, 5]
        strides = [5, 1]
        backstrides = [x * (y - 1) for x,y in zip(strides, shape)]
        assert backstrides == [10, 4]
        i = ArrayIter(MockArray(shape, strides), support.product(shape), shape,
                      strides, backstrides)
        assert i.contiguous
        s = i.reset()
        s = i.next(s)
        s = i.next(s)
        s = i.next(s)
        assert s.offset == 3
        assert not i.done(s)
        assert s._indices == [0,0]
        assert i.indices(s) == [0,3]
        #cause a dimension overflow
        s = i.next(s)
        s = i.next(s)
        assert s.offset == 5
        assert s._indices == [0,3]
        assert i.indices(s) == [1,0]

        #Now what happens if the array is transposed? strides[-1] != 1
        # therefore layout is non-contiguous
        strides = [1, 3]
        backstrides = [x * (y - 1) for x,y in zip(strides, shape)]
        assert backstrides == [2, 12]
        i = ArrayIter(MockArray(shape, strides), support.product(shape), shape,
                      strides, backstrides)
        assert not i.contiguous
        s = i.reset()
        s = i.next(s)
        s = i.next(s)
        s = i.next(s)
        assert s.offset == 9
        assert not i.done(s)
        assert s._indices == [0,3]
        #cause a dimension overflow
        s = i.next(s)
        s = i.next(s)
        assert s.offset == 1
        assert s._indices == [1,0]

    def test_one_in_shape(self):
        strides = [16, 4, 8]
        shape   = [3,  4, 1]
        backstrides = [x * (y - 1) for x,y in zip(strides, shape)]
        assert backstrides == [32, 12, 0]
        i = ArrayIter(MockArray(shape, strides), support.product(shape), shape,
                      strides, backstrides)
        assert not i.contiguous
        s = i.reset()
        for j in range(3):
            s = i.next(s)
        assert s.offset == 12
        assert not i.done(s)
        assert s._indices == [0, 3, 0]
        while not i.done(s):
            old_indices = s._indices[:]
            old_offset = s.offset
            s = i.next(s)
        assert s.offset == 0
        assert s._indices == [0, 0, 0]
        assert old_indices == [2, 3, 0]
        assert old_offset == 44

    def test_iterator_goto(self):
        shape = [3, 5]
        strides = [1, 3]
        backstrides = [x * (y - 1) for x,y in zip(strides, shape)]
        assert backstrides == [2, 12]
        a = MockArray(shape, strides, 42)
        i = ArrayIter(a, support.product(shape), shape,
                      strides, backstrides)
        assert not i.contiguous
        s = i.reset()
        assert s.index == 0
        assert s._indices == [0, 0]
        assert s.offset == a.start
        s = i.goto(11)
        assert s.index == 11
        assert s._indices is None
        assert s.offset == a.start + 5
