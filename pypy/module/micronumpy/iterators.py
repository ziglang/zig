""" This is a mini-tutorial on iterators, strides, and
memory layout. It assumes you are familiar with the terms, see
http://docs.scipy.org/doc/numpy/reference/arrays.ndarray.html
for a more gentle introduction.

Given an array x: x.shape == [5,6], where each element occupies one byte

At which byte in x.data does the item x[3,4] begin?
if x.strides==[1,5]:
    pData = x.pData + (x.start + 3*1 + 4*5)*sizeof(x.pData[0])
    pData = x.pData + (x.start + 23) * sizeof(x.pData[0])
so the offset of the element is 23 elements after the first

What is the next element in x after coordinates [3,4]?
if x.order =='C':
   next == [3,5] => offset is 28
if x.order =='F':
   next == [4,4] => offset is 24
so for the strides [1,5] x is 'F' contiguous
likewise, for the strides [6,1] x would be 'C' contiguous.

Iterators have an internal representation of the current coordinates
(indices), the array, strides, and backstrides. A short digression to
explain backstrides: what is the coordinate and offset after [3,5] in
the example above?
if x.order == 'C':
   next == [4,0] => offset is 4
if x.order == 'F':
   next == [4,5] => offset is 25
Note that in 'C' order we stepped BACKWARDS 24 while 'overflowing' a
shape dimension
  which is back 25 and forward 1,
  which is x.strides[1] * (x.shape[1] - 1) + x.strides[0]
so if we precalculate the overflow backstride as
[x.strides[i] * (x.shape[i] - 1) for i in range(len(x.shape))]
we can do only addition while iterating
All the calculations happen in next()
"""
from rpython.rlib import jit
from pypy.module.micronumpy import support, constants as NPY
from pypy.module.micronumpy.base import W_NDimArray

class PureShapeIter(object):
    def __init__(self, shape, idx_w):
        self.shape = shape
        self.shapelen = len(shape)
        self.indexes = [0] * len(shape)
        self._done = False
        self.idx_w_i = [None] * len(idx_w)
        self.idx_w_s = [None] * len(idx_w)
        for i, w_idx in enumerate(idx_w):
            if isinstance(w_idx, W_NDimArray):
                self.idx_w_i[i], self.idx_w_s[i] = w_idx.create_iter(shape)

    def done(self):
        return self._done

    @jit.unroll_safe
    def next(self):
        for i, idx_w_i in enumerate(self.idx_w_i):
            if idx_w_i is not None:
                self.idx_w_s[i] = idx_w_i.next(self.idx_w_s[i])
        for i in range(self.shapelen - 1, -1, -1):
            if self.indexes[i] < self.shape[i] - 1:
                self.indexes[i] += 1
                break
            else:
                self.indexes[i] = 0
        else:
            self._done = True

    @jit.unroll_safe
    def get_index(self, space, shapelen):
        return [space.newint(self.indexes[i]) for i in range(shapelen)]


class IterState(object):
    _immutable_fields_ = ['iterator', '_indices']

    def __init__(self, iterator, index, indices, offset):
        self.iterator = iterator
        self.index = index
        self._indices = indices
        self.offset = offset

    def same(self, other):
        if self.offset == other.offset and \
           self.index == other.index and \
           self._indices == other._indices:
            return self.iterator.same_shape(other.iterator)
        return False

class ArrayIter(object):
    _immutable_fields_ = ['contiguous', 'array', 'size', 'ndim_m1', 'shape_m1[*]',
                          'strides[*]', 'backstrides[*]', 'factors[*]',
                          'track_index']

    track_index = True

    @jit.unroll_safe
    def __init__(self, array, size, shape, strides, backstrides):
        assert len(shape) == len(strides) == len(backstrides)
        self.contiguous = (array.flags & NPY.ARRAY_C_CONTIGUOUS and
                           array.shape == shape and array.strides == strides)

        self.array = array
        self.size = size
        self.ndim_m1 = len(shape) - 1
        #
        self.shape_m1 = [s - 1 for s in shape]
        self.strides = strides
        self.backstrides = backstrides

        ndim = len(shape)
        factors = [0] * ndim
        for i in xrange(ndim):
            if i == 0:
                factors[ndim-1] = 1
            else:
                factors[ndim-i-1] = factors[ndim-i] * shape[ndim-i]
        self.factors = factors

    def same_shape(self, other):
        """ Iterating over the same element """
        if not self.contiguous or not other.contiguous:
            return False
        return (self.contiguous == other.contiguous and
                self.array.dtype is self.array.dtype and
                self.shape_m1 == other.shape_m1 and
                self.strides == other.strides and
                self.backstrides == other.backstrides and
                self.factors == other.factors)

    @jit.unroll_safe
    def reset(self, state=None, mutate=False):
        index = 0
        if state is None:
            indices = [0] * len(self.shape_m1)
        else:
            assert state.iterator is self
            indices = state._indices
            for i in xrange(self.ndim_m1, -1, -1):
                indices[i] = 0
        offset = self.array.start
        if not mutate:
            return IterState(self, index, indices, offset)
        state.index = index
        state.offset = offset

    @jit.unroll_safe
    def next(self, state, mutate=False):
        assert state.iterator is self
        index = state.index
        if self.track_index:
            index += 1
        indices = state._indices
        offset = state.offset
        if self.contiguous:
            elsize = self.array.dtype.elsize
            jit.promote(elsize)
            offset += elsize
        elif self.ndim_m1 == 0:
            stride = self.strides[0]
            jit.promote(stride)
            offset += stride
        else:
            for i in xrange(self.ndim_m1, -1, -1):
                idx = indices[i]
                if idx < self.shape_m1[i]:
                    indices[i] = idx + 1
                    offset += self.strides[i]
                    break
                else:
                    indices[i] = 0
                    offset -= self.backstrides[i]
        if not mutate:
            return IterState(self, index, indices, offset)
        state.index = index
        state.offset = offset

    @jit.unroll_safe
    def goto(self, index):
        offset = self.array.start
        if self.contiguous:
            offset += index * self.array.dtype.elsize
        elif self.ndim_m1 == 0:
            offset += index * self.strides[0]
        else:
            current = index
            for i in xrange(len(self.shape_m1)):
                offset += (current / self.factors[i]) * self.strides[i]
                current %= self.factors[i]
        return IterState(self, index, None, offset)

    @jit.unroll_safe
    def indices(self, state):
        assert state.iterator is self
        assert self.track_index
        indices = state._indices
        if not (self.contiguous or self.ndim_m1 == 0):
            return indices
        current = state.index
        for i in xrange(len(self.shape_m1)):
            if self.factors[i] != 0:
                indices[i] = current / self.factors[i]
                current %= self.factors[i]
            else:
                indices[i] = 0
        return indices

    def done(self, state):
        assert state.iterator is self
        assert self.track_index
        return state.index >= self.size

    def getitem(self, state):
        # assert state.iterator is self
        return self.array.getitem(state.offset)

    def getitem_bool(self, state):
        assert state.iterator is self
        return self.array.getitem_bool(state.offset)

    def setitem(self, state, elem):
        assert state.iterator is self
        self.array.setitem(state.offset, elem)

def AxisIter(array, shape, axis):
    strides = array.get_strides()
    backstrides = array.get_backstrides()
    if len(shape) == len(strides):
        # keepdims = True
        strides = strides[:axis] + [0] + strides[axis + 1:]
        backstrides = backstrides[:axis] + [0] + backstrides[axis + 1:]
    else:
        strides = strides[:axis] + [0] + strides[axis:]
        backstrides = backstrides[:axis] + [0] + backstrides[axis:]
    return ArrayIter(array, support.product(shape), shape, strides, backstrides)


def AllButAxisIter(array, axis):
    size = array.get_size()
    shape = array.get_shape()[:]
    backstrides = array.backstrides[:]
    if size:
        size /= shape[axis]
    shape[axis] = backstrides[axis] = 0
    return ArrayIter(array, size, shape, array.strides, backstrides)
