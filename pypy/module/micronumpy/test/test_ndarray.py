# -*- encoding: utf-8 -*-
import py
import sys

from pypy.conftest import option
from pypy.module.micronumpy.appbridge import get_appbridge_cache
from pypy.module.micronumpy.strides import Chunk, new_view, EllipsisChunk
from pypy.module.micronumpy.ndarray import W_NDimArray
import pypy.module.micronumpy.constants as NPY
from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class MockDtype(object):
    class itemtype(object):
        @staticmethod
        def malloc(size, zero=True):
            return None

    def __init__(self):
        self.base = self
        self.elsize = 1
        self.num = 0


def create_slice(space, a, chunks):
    if not any(isinstance(c, EllipsisChunk) for c in chunks):
        chunks.append(EllipsisChunk())
    return new_view(space, W_NDimArray(a), chunks).implementation


def create_array(*args, **kwargs):
    return W_NDimArray.from_shape(*args, **kwargs).implementation


class TestNumArrayDirect(object):
    def newslice(self, *args):
        return self.space.newslice(*[self.space.wrap(arg) for arg in args])

    def newtuple(self, *args):
        args_w = []
        for arg in args:
            if isinstance(arg, int):
                args_w.append(self.space.wrap(arg))
            else:
                args_w.append(arg)
        return self.space.newtuple(args_w)

    def test_strides_f(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.FORTRANORDER)
        assert a.strides == [1, 10, 50]
        assert a.backstrides == [9, 40, 100]

    def test_strides_c(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.CORDER)
        assert a.strides == [15, 3, 1]
        assert a.backstrides == [135, 12, 2]
        a = create_array(self.space, [1, 0, 7], MockDtype(), order=NPY.CORDER)
        assert a.strides == [7, 7, 1]
        assert a.backstrides == [0, 0, 6]

    def test_create_slice_f(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.FORTRANORDER)
        s = create_slice(self.space, a, [Chunk(3, 0, 0, 1)])
        assert s.start == 3
        assert s.strides == [10, 50]
        assert s.backstrides == [40, 100]
        s = create_slice(self.space, a, [Chunk(1, 9, 2, 4)])
        assert s.start == 1
        assert s.strides == [2, 10, 50]
        assert s.backstrides == [6, 40, 100]
        s = create_slice(self.space, a, [Chunk(1, 5, 3, 2), Chunk(1, 2, 1, 1),
                                         Chunk(1, 0, 0, 1)])
        assert s.shape == [2, 1]
        assert s.strides == [3, 10]
        assert s.backstrides == [3, 0]
        s = create_slice(self.space, a, [Chunk(0, 10, 1, 10), Chunk(2, 0, 0, 1)])
        assert s.start == 20
        assert s.shape == [10, 3]

    def test_create_slice_c(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.CORDER)
        s = create_slice(self.space, a, [Chunk(3, 0, 0, 1)])
        assert s.start == 45
        assert s.strides == [3, 1]
        assert s.backstrides == [12, 2]
        s = create_slice(self.space, a, [Chunk(1, 9, 2, 4)])
        assert s.start == 15
        assert s.strides == [30, 3, 1]
        assert s.backstrides == [90, 12, 2]
        s = create_slice(self.space, a, [Chunk(1, 5, 3, 2), Chunk(1, 2, 1, 1),
                            Chunk(1, 0, 0, 1)])
        assert s.start == 19
        assert s.shape == [2, 1]
        assert s.strides == [45, 3]
        assert s.backstrides == [45, 0]
        s = create_slice(self.space, a, [Chunk(0, 10, 1, 10), Chunk(2, 0, 0, 1)])
        assert s.start == 6
        assert s.shape == [10, 3]

    def test_slice_of_slice_f(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.FORTRANORDER)
        s = create_slice(self.space, a, [Chunk(5, 0, 0, 1)])
        assert s.start == 5
        s2 = create_slice(self.space, s, [Chunk(3, 0, 0, 1)])
        assert s2.shape == [3]
        assert s2.strides == [50]
        assert s2.parent is a
        assert s2.backstrides == [100]
        assert s2.start == 35
        s = create_slice(self.space, a, [Chunk(1, 5, 3, 2)])
        s2 = create_slice(self.space, s, [Chunk(0, 2, 1, 2), Chunk(2, 0, 0, 1)])
        assert s2.shape == [2, 3]
        assert s2.strides == [3, 50]
        assert s2.backstrides == [3, 100]
        assert s2.start == 1 * 15 + 2 * 3

    def test_slice_of_slice_c(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.CORDER)
        s = create_slice(self.space, a, [Chunk(5, 0, 0, 1)])
        assert s.start == 15 * 5
        s2 = create_slice(self.space, s, [Chunk(3, 0, 0, 1)])
        assert s2.shape == [3]
        assert s2.strides == [1]
        assert s2.parent is a
        assert s2.backstrides == [2]
        assert s2.start == 5 * 15 + 3 * 3
        s = create_slice(self.space, a, [Chunk(1, 5, 3, 2)])
        s2 = create_slice(self.space, s, [Chunk(0, 2, 1, 2), Chunk(2, 0, 0, 1)])
        assert s2.shape == [2, 3]
        assert s2.strides == [45, 1]
        assert s2.backstrides == [45, 2]
        assert s2.start == 1 * 15 + 2 * 3

    def test_negative_step_f(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.FORTRANORDER)
        s = create_slice(self.space, a, [Chunk(9, -1, -2, 5)])
        assert s.start == 9
        assert s.strides == [-2, 10, 50]
        assert s.backstrides == [-8, 40, 100]

    def test_negative_step_c(self):
        a = create_array(self.space, [10, 5, 3], MockDtype(), order=NPY.CORDER)
        s = create_slice(self.space, a, [Chunk(9, -1, -2, 5)])
        assert s.start == 135
        assert s.strides == [-30, 3, 1]
        assert s.backstrides == [-120, 12, 2]

    def test_shape_agreement(self):
        from pypy.module.micronumpy.strides import _shape_agreement
        assert _shape_agreement([3], [3]) == [3]
        assert _shape_agreement([1, 2, 3], [1, 2, 3]) == [1, 2, 3]
        _shape_agreement([2], [3]) == 0
        assert _shape_agreement([4, 4], []) == [4, 4]
        assert _shape_agreement([8, 1, 6, 1], [7, 1, 5]) == [8, 7, 6, 5]
        assert _shape_agreement([5, 2], [4, 3, 5, 2]) == [4, 3, 5, 2]

    def test_calc_new_strides(self):
        from pypy.module.micronumpy.strides import calc_new_strides
        assert calc_new_strides([2, 4], [4, 2], [4, 2], NPY.CORDER) == [8, 2]
        assert calc_new_strides([2, 4, 3], [8, 3], [1, 16], NPY.FORTRANORDER) == [1, 2, 16]
        assert calc_new_strides([2, 3, 4], [8, 3], [1, 16], NPY.FORTRANORDER) is None
        assert calc_new_strides([24], [2, 4, 3], [48, 6, 1], NPY.CORDER) is None
        assert calc_new_strides([24], [2, 4, 3], [24, 6, 2], NPY.CORDER) == [2]
        assert calc_new_strides([105, 1], [3, 5, 7], [35, 7, 1],NPY.CORDER) == [1, 1]
        assert calc_new_strides([1, 105], [3, 5, 7], [35, 7, 1],NPY.CORDER) == [105, 1]
        assert calc_new_strides([1, 105], [3, 5, 7], [35, 7, 1],NPY.FORTRANORDER) is None
        assert calc_new_strides([1, 1, 1, 105, 1], [15, 7], [7, 1],NPY.CORDER) == \
                                    [105, 105, 105, 1, 1]
        assert calc_new_strides([1, 1, 105, 1, 1], [7, 15], [1, 7],NPY.FORTRANORDER) == \
                                    [1, 1, 1, 105, 105]

    def test_find_shape(self):
        from pypy.module.micronumpy.ctors import find_shape_and_elems

        space = self.space
        shape, elems = find_shape_and_elems(space,
                                            space.newlist([space.wrap("a"),
                                                           space.wrap("b")]),
                                            None)
        assert shape == [2]
        assert space.text_w(elems[0]) == "a"
        assert space.text_w(elems[1]) == "b"

    def test_from_shape_and_storage(self):
        from rpython.rlib.rawstorage import alloc_raw_storage, raw_storage_setitem
        from rpython.rtyper.lltypesystem import rffi
        from pypy.module.micronumpy.descriptor import get_dtype_cache
        storage = alloc_raw_storage(4, track_allocation=False, zero=True)
        for i in range(4):
            raw_storage_setitem(storage, i, rffi.cast(rffi.UCHAR, i))
        #
        dtypes = get_dtype_cache(self.space)
        w_array = W_NDimArray.from_shape_and_storage(self.space, [2, 2],
                                                storage, dtypes.w_int8dtype,
                                                storage_bytes=4)
        def get(i, j):
            return w_array.getitem(self.space, [i, j]).value
        assert get(0, 0) == 0
        assert get(0, 1) == 1
        assert get(1, 0) == 2
        assert get(1, 1) == 3


class AppTestNumArray(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "struct", "binascii"])

    def w_CustomIndexObject(self, index):
        class CustomIndexObject(object):
            def __init__(self, index):
                self.index = index
            def __index__(self):
                return self.index

        return CustomIndexObject(index)

    def w_CustomIndexIntObject(self, index, value):
        class CustomIndexIntObject(object):
            def __init__(self, index, value):
                self.index = index
                self.value = value
            def __index__(self):
                return self.index
            def __int__(self):
                return self.value

        return CustomIndexIntObject(index, value)

    def w_CustomIntObject(self, value):
        class CustomIntObject(object):
            def __init__(self, value):
                self.value = value
            def __index__(self):
                return self.value

        return CustomIntObject(value)

    def test_constants(self):
        import numpy as np
        assert np.MAXDIMS is 32
        assert np.CLIP is 0
        assert np.WRAP is 1
        assert np.RAISE is 2

    def test_creation(self):
        from numpy import ndarray, array, dtype, flatiter

        assert type(ndarray) is type
        assert repr(ndarray) == "<type 'numpy.ndarray'>"
        assert repr(flatiter) == "<type 'numpy.flatiter'>"
        assert type(array) is not type
        a = ndarray((2, 3))
        assert a.shape == (2, 3)
        assert a.dtype == dtype(float)

        raises(TypeError, ndarray, [[1], [2], [3]])

        a = ndarray(3, dtype=int)
        assert a.shape == (3,)
        assert a.dtype is dtype(int)
        a = ndarray([], dtype=float)
        assert a.shape == ()
        # test uninitialized value crash?
        assert len(str(a)) > 0

        x = array([[0, 2], [1, 1], [2, 0]])
        y = array(x.T, dtype=float)
        assert (y == x.T).all()
        y = array(x.T, copy=False)
        assert (y == x.T).all()

        exc = raises(ValueError, ndarray, [1,2,256]*10000)
        assert exc.value[0] == 'sequence too large; cannot be greater than 32'
        exc = raises(ValueError, ndarray, [1,2,256]*10)
        assert exc.value[0] == 'array is too big.'

    def test_ndmin(self):
        from numpy import array

        arr = array([[[1]]], ndmin=1)
        assert arr.shape == (1, 1, 1)

    def test_noop_ndmin(self):
        from numpy import array
        arr = array([1], ndmin=3)
        assert arr.shape == (1, 1, 1)

    def test_array_init(self):
        import numpy as np
        a = np.array('123', dtype='int64')
        assert a == 123
        assert a.dtype == np.int64
        a = np.array('123', dtype='intp')
        assert a == 123
        assert a.dtype == np.intp
        # required for numpy test suite
        raises(ValueError, np.array, type(a))

    def test_array_copy(self):
        from numpy import array
        a = array(range(12)).reshape(3,4)
        b = array(a, ndmin=4)
        assert b.shape == (1, 1, 3, 4)
        b = array(a, copy=False)
        b[0, 0] = 100
        assert a[0, 0] == 100
        b = array(a, copy=True, ndmin=2)
        b[0, 0] = 0
        assert a[0, 0] == 100
        b = array(a, dtype=float)
        assert (b[0] == [100, 1, 2, 3]).all()
        assert b.dtype.kind == 'f'
        b = array(a, copy=False, ndmin=4)
        b[0,0,0,0] = 0
        assert a[0, 0] == 0
        a = array([[[]]])
        # Simulate tiling an empty array, really tests repeat, reshape
        # b = tile(a, (3, 2, 5))
        reps = (3, 4, 5)
        c = array(a, copy=False, subok=True, ndmin=len(reps))
        d = c.reshape(3, 4, 0)
        e = d.repeat(3, 0)
        assert e.shape == (9, 4, 0)
        a = array(123)
        b = array(a, dtype=float)
        assert b == 123.0

        a = array([[123, 456]])
        assert a.flags['C']
        b = array(a, order='K')
        assert b.flags['C']
        assert (b == a).all()
        b = array(a, order='K', copy=True)
        assert b.flags['C']
        assert (b == a).all()

    def test_unicode(self):
        import numpy as np
        a = np.array([3, u'Aÿ', ''], dtype='U3')
        assert a.shape == (3,)
        assert a.dtype == np.dtype('U3')
        assert a[0] == u'3'
        assert a[1] == u'Aÿ'

    def test_dtype_attribute(self):
        import numpy as np
        a = np.array(40000, dtype='uint16')
        assert a.dtype == np.uint16
        a.dtype = np.int16
        assert a == -25536
        a = np.array([1, 2, 3, 4, 40000], dtype='uint16')
        assert a.dtype == np.uint16
        a.dtype = np.int16
        assert a[4] == -25536
        exc = raises(ValueError, 'a.dtype = None')
        assert exc.value[0] == 'new type not compatible with array.'
        exc = raises(ValueError, 'a.dtype = np.int32')
        assert exc.value[0] == 'new type not compatible with array.'
        exc = raises(AttributeError, 'del a.dtype')
        assert exc.value[0] == 'Cannot delete array dtype'

    def test_buffer(self):
        import numpy as np
        a = np.array([1,2,3])
        b = buffer(a)
        assert type(b) is buffer
        assert 'read-only buffer' in repr(b)
        exc = raises(TypeError, "b[0] = '0'")
        assert str(exc.value) == 'buffer is read-only'

    def test_type(self):
        from numpy import array
        ar = array(range(5))
        assert type(ar) is type(ar + ar)

    def test_ndim(self):
        from numpy import array
        x = array(0.2)
        assert x.ndim == 0
        x = array([1, 2])
        assert x.ndim == 1
        x = array([[1, 2], [3, 4]])
        assert x.ndim == 2
        x = array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        assert x.ndim == 3
        # numpy actually raises an AttributeError, but numpy.raises an
        # TypeError
        raises((TypeError, AttributeError), 'x.ndim = 3')

    def test_zeros(self):
        from numpy import zeros
        a = zeros(15)
        # Check that storage was actually zero'd.
        assert a[10] == 0.0
        # And check that changes stick.
        a[13] = 5.3
        assert a[13] == 5.3
        assert zeros(()) == 0
        assert zeros(()).shape == ()
        assert zeros((), dtype='S') == ''
        assert zeros((), dtype='S').shape == ()
        assert zeros((), dtype='S').dtype == '|S1'
        assert zeros(5, dtype='U')[4] == u''
        assert zeros(5, dtype='U').shape == (5,)
        assert zeros(5, dtype='U').dtype == '<U1'

    def test_check_shape(self):
        import numpy as np
        for func in [np.zeros, np.empty]:
            exc = raises(ValueError, func, [0, -1, 1], 'int8')
            assert str(exc.value) == "negative dimensions are not allowed"
            exc = raises(ValueError, func, [2, -1, 3], 'int8')
            assert str(exc.value) == "negative dimensions are not allowed"

            exc = raises(ValueError, func, [975]*7, 'int8')
            assert str(exc.value) == "array is too big."
            exc = raises(ValueError, func, [26244]*5, 'int8')
            assert str(exc.value) == "array is too big."

    def test_empty_like(self):
        import numpy as np
        a = np.empty_like(np.zeros(()))
        assert a.shape == ()
        assert a.dtype == np.float_
        a = np.empty_like(a, dtype='S')
        assert a.dtype == '|S1'
        a = np.zeros((2, 3))
        assert a.shape == (2, 3)
        a[0,0] = 1
        b = np.empty_like(a)
        assert b.shape == a.shape
        assert b.dtype == a.dtype
        assert b[0,0] != 1
        b = np.empty_like(np.array(True), dtype=None)
        assert b.dtype is np.dtype(bool)
        b = np.empty_like(a, dtype='i4')
        assert b.shape == a.shape
        assert b.dtype == np.dtype('i4')
        # assert b[0,0] != 1 # no guarantees on values in b
        b = np.empty_like([1,2,3])
        assert b.shape == (3,)
        assert b.dtype == np.int_
        class A(np.ndarray):
            pass
        b = np.empty_like(A((2, 3)))
        assert b.shape == (2, 3)
        assert type(b) is A
        b = np.empty_like(A((2, 3)), subok=False)
        assert b.shape == (2, 3)
        assert type(b) is np.ndarray
        b = np.empty_like(np.array(3.0), order='A')
        assert type(b) is np.ndarray

    def test_size(self):
        from numpy import array,arange,cos
        assert array(3).size == 1
        a = array([1, 2, 3])
        assert a.size == 3
        assert (a + a).size == 3
        ten = cos(1 + arange(10)).size
        assert ten == 10

    def test_empty(self):
        from numpy import empty
        a = empty(2)
        a[1] = 1.0
        assert a[1] == 1.0

    def test_ones(self):
        from numpy import ones, dtype
        a = ones(3)
        assert len(a) == 3
        assert a[0] == 1
        raises(IndexError, "a[3]")
        a[2] = 4
        assert a[2] == 4
        b = ones(3, complex)
        assert b[0] == 1+0j
        assert b.dtype is dtype(complex)

    def test_arange(self):
        from numpy import arange, dtype, array
        a = arange(3)
        assert (a == [0, 1, 2]).all()
        assert a.dtype is dtype(int)
        a = arange(3.0)
        assert (a == [0., 1., 2.]).all()
        assert a.dtype is dtype(float)
        a = arange(3, 7)
        assert (a == [3, 4, 5, 6]).all()
        assert a.dtype is dtype(int)
        a = arange(3, 7, 2)
        assert (a == [3, 5]).all()
        a = arange(3, 8, 2)
        assert (a == [3, 5, 7]).all()
        a = arange(3, dtype=float)
        assert (a == [0., 1., 2.]).all()
        assert a.dtype is dtype(float)
        a = arange(0, 0.8, 0.1)
        assert len(a) == 8
        assert arange(False, True, True).dtype is dtype(int)

        a = arange(array([10]))
        assert a.shape == (10,)

    def test_copy(self):
        from numpy import arange, array
        a = arange(5)
        b = a.copy()
        for i in xrange(5):
            assert b[i] == a[i]
        a[3] = 22
        assert b[3] == 3

        a = array(1)
        assert a.copy() == a

        a = arange(8)
        b = a[::2]
        c = b.copy()
        assert (c == b).all()
        assert ((a + a).copy() == (a + a)).all()

        a = arange(15).reshape(5,3)
        b = a.copy()
        assert (b == a).all()

        a = array(['abc', 'def','xyz'], dtype='S3')
        b = a.copy()
        assert b[0] == a[0]

        a = arange(8)
        b = a.copy(order=None)
        assert (b == a).all()
        b = a.copy(order=0)
        assert (b == a).all()
        b = a.copy(order='C')
        assert (b == a).all()
        b = a.copy(order='K')
        assert (b == a).all()
        b = a.copy(order='A')
        assert (b == a).all()
        b = a.copy(order='F')
        assert (b == a).all()
        b = a.copy(order=True)
        assert (b == a).all()

    def test_iterator_init(self):
        from numpy import array
        a = array(range(5))
        assert a[3] == 3

    def test_list_of_array_init(self):
        import numpy as np
        a = np.array([np.array(True), np.array(False)])
        assert a.shape == (2,)
        assert a.dtype == np.bool_
        assert (a == [True, False]).all()
        a = np.array([np.array(True), np.array(2)])
        assert a.shape == (2,)
        assert a.dtype == np.int_
        assert (a == [1, 2]).all()
        a = np.array([np.array(True), np.int_(2)])
        assert a.shape == (2,)
        assert a.dtype == np.int_
        assert (a == [1, 2]).all()
        a = np.array([np.array([True]), np.array([2])])
        assert a.shape == (2, 1)
        assert a.dtype == np.int_
        assert (a == [[1], [2]]).all()

    def test_getitem(self):
        from numpy import array
        a = array(range(5))
        raises(IndexError, "a[5]")
        a = a + a
        raises(IndexError, "a[5]")
        assert a[-1] == 8
        raises(IndexError, "a[-6]")

    def test_getitem_float(self):
        from numpy import array
        a = array([1, 2, 3, 4])
        assert a[1.2] == 2
        assert a[1.6] == 2
        assert a[-1.2] == 4

    def test_getitem_tuple(self):
        from numpy import array
        a = array(range(5))
        raises(IndexError, "a[(1,2)]")
        for i in xrange(5):
            assert a[(i,)] == i
        b = a[()]
        for i in xrange(5):
            assert a[i] == b[i]

    def test_getitem_nd(self):
        from numpy import arange
        a = arange(15).reshape(3, 5)
        assert a[1, 3] == 8
        assert a.T[1, 2] == 11

    def test_getitem_obj_index(self):
        from numpy import arange
        a = arange(10)
        assert a[self.CustomIndexObject(1)] == 1

    def test_getitem_obj_prefer_index_to_int(self):
        from numpy import arange
        a = arange(10)
        assert a[self.CustomIndexIntObject(0, 1)] == 0

    def test_getitem_obj_int(self):
        from numpy import arange
        a = arange(10)
        assert a[self.CustomIntObject(1)] == 1

    def test_setitem(self):
        from numpy import array
        a = array(range(5))
        a[-1] = 5.0
        assert a[4] == 5.0
        raises(IndexError, "a[5] = 0.0")
        raises(IndexError, "a[-6] = 3.0")
        a[1] = array(100)
        a[2] = array([100])
        assert a[1] == 100
        assert a[2] == 100
        a = array(range(5), dtype=float)
        a[0] = 0.005
        assert a[0] == 0.005
        a[1] = array(-0.005)
        a[2] = array([-0.005])
        assert a[1] == -0.005
        assert a[2] == -0.005

    def test_setitem_tuple(self):
        from numpy import array
        a = array(range(5))
        raises(IndexError, "a[(1,2)] = [0,1]")
        for i in xrange(5):
            a[(i,)] = i + 1
            assert a[i] == i + 1
        a[()] = range(5)
        for i in xrange(5):
            assert a[i] == i

    def test_setitem_record(self):
        from numpy import zeros
        trie =  zeros(200, dtype= [ ("A","uint32"),("C","uint32"), ])
        trie[0][0] = 1
        assert trie[0]['A'] == 1

    def test_setitem_array(self):
        import numpy as np
        a = np.array((-1., 0, 1))/0.
        b = np.array([False, False, True], dtype=bool)
        a[b] = 100
        assert a[2] == 100

    def test_setitem_obj_index(self):
        from numpy import arange
        a = arange(10)
        a[self.CustomIndexObject(1)] = 100
        assert a[1] == 100

    def test_setitem_obj_prefer_index_to_int(self):
        from numpy import arange
        a = arange(10)
        a[self.CustomIndexIntObject(0, 1)] = 100
        assert a[0] == 100

    def test_setitem_obj_int(self):
        from numpy import arange
        a = arange(10)
        a[self.CustomIntObject(1)] = 100
        assert a[1] == 100

    def test_setitem_list_of_float(self):
        from numpy import arange
        a = arange(10)
        a[[0.9]] = -10
        assert a[0] == -10

    def test_delitem(self):
        import numpy as np
        a = np.arange(10)
        exc = raises(ValueError, 'del a[2]')
        assert exc.value.message == 'cannot delete array elements'

    def test_access_swallow_exception(self):
        class ErrorIndex(object):
            def __index__(self):
                return 1 / 0

        class ErrorInt(object):
            def __int__(self):
                return 1 / 0

        # numpy will swallow errors in __int__ and __index__ and
        # just raise IndexError.

        from numpy import arange
        a = arange(10)
        exc = raises(IndexError, "a[ErrorIndex()] == 0")
        assert exc.value.message.startswith('only integers, slices')
        exc = raises(IndexError, "a[ErrorInt()] == 0")
        assert exc.value.message.startswith('only integers, slices')

    def test_setslice_array(self):
        from numpy import array
        a = array(5)
        exc = raises(ValueError, "a[:] = 4")
        assert exc.value[0] == "cannot slice a 0-d array"
        a = array(range(5))
        b = array(range(2))
        a[1:4:2] = b
        assert a[1] == 0.
        assert a[3] == 1.
        b[::-1] = b
        assert b[0] == 1.
        assert b[1] == 0.

    def test_setslice_of_slice_array(self):
        from numpy import array, zeros
        a = zeros(5)
        a[::2] = array([9., 10., 11.])
        assert a[0] == 9.
        assert a[2] == 10.
        assert a[4] == 11.
        a[1:4:2][::-1] = array([1., 2.])
        assert a[0] == 9.
        assert a[1] == 2.
        assert a[2] == 10.
        assert a[3] == 1.
        assert a[4] == 11.
        a = zeros(10)
        a[::2][::-1][::2] = array(range(1, 4))
        assert a[8] == 1.
        assert a[4] == 2.
        assert a[0] == 3.

    def test_setslice_list(self):
        from numpy import array
        a = array(range(5), float)
        b = [0., 1.]
        a[1:4:2] = b
        assert a[1] == 0.
        assert a[3] == 1.

    def test_setslice_constant(self):
        from numpy import array
        a = array(range(5), float)
        a[1:4:2] = 0.
        assert a[1] == 0.
        assert a[3] == 0.

    def test_newaxis(self):
        import math
        from numpy import array, cos, zeros, newaxis
        a = array(range(5))
        b = array([range(5)])
        assert (a[newaxis] == b).all()
        a = array(range(3))
        b = array([1, 3])
        expected = zeros((3, 2))
        for x in range(3):
            for y in range(2):
                expected[x, y] = math.cos(a[x]) * math.cos(b[y])
        assert ((cos(a)[:,newaxis] * cos(b).T) == expected).all()
        o = array(1)
        a = o[newaxis]
        assert a == array([1])
        assert a.shape == (1,)
        o[newaxis, newaxis] = 2
        assert o == 2
        a[:] = 3
        assert o == 3

    def test_newaxis_slice(self):
        from numpy import array, newaxis

        a = array(range(5))
        b = array(range(1,5))
        c = array([range(1,5)])
        d = array([[x] for x in range(1,5)])

        assert (a[1:] == b).all()
        assert (a[1:,newaxis] == d).all()
        assert (a[newaxis,1:] == c).all()
        n = a.dtype.itemsize
        assert a.strides == (n,)
        assert a[:, newaxis].strides == (n, 0)

    def test_newaxis_assign(self):
        from numpy import array, newaxis

        a = array(range(5))
        a[newaxis,1] = [2]
        assert a[1] == 2

    def test_newaxis_virtual(self):
        from numpy import array, newaxis

        a = array(range(5))
        b = (a + a)[newaxis]
        c = array([[0, 2, 4, 6, 8]])
        assert (b == c).all()

    def test_newaxis_then_slice(self):
        from numpy import array, newaxis
        a = array(range(5))
        b = a[newaxis]
        assert b.shape == (1, 5)
        assert (b[0,1:] == a[1:]).all()

    def test_slice_then_newaxis(self):
        from numpy import array, newaxis
        a = array(range(5))
        b = a[2:]
        assert (b[newaxis] == [[2, 3, 4]]).all()

    def test_scalar(self):
        from numpy import array, dtype, int_
        a = array(3)
        exc = raises(IndexError, "a[0]")
        assert exc.value[0] == "too many indices for array"
        exc = raises(IndexError, "a[0] = 5")
        assert exc.value[0] == "too many indices for array"
        assert a.size == 1
        assert a.shape == ()
        assert a.dtype is dtype(int)
        b = a[()]
        assert type(b) is int_
        assert b == 3
        a[()] = 4
        assert a == 4

    def test_build_scalar(self):
        from numpy import dtype
        import sys
        try:
            from numpy.core.multiarray import scalar
        except ImportError:
            from numpy import scalar
        exc = raises(TypeError, scalar, int, 2)
        assert exc.value[0] == 'argument 1 must be numpy.dtype, not type'
        if '__pypy__' in sys.builtin_module_names:
            exc = raises(TypeError, scalar, dtype('void'), 'abc')
        else:
            a = scalar(dtype('void'), 'abc')
            exc = raises(TypeError, str, a)
        assert exc.value[0] == 'Empty data-type'
        exc = raises(TypeError, scalar, dtype(float), 2.5)
        assert exc.value[0] == 'initializing object must be a string'
        exc = raises(ValueError, scalar, dtype(float), 'abc')
        assert exc.value[0] == 'initialization string is too small'
        a = scalar(dtype('<f8'), dtype('<f8').type(2.5).tostring())
        assert a == 2.5

    def test_len(self):
        from numpy import array
        a = array(range(5))
        assert len(a) == 5
        assert len(a + a) == 5

    def test_shape(self):
        from numpy import array
        a = array(range(5))
        assert a.shape == (5,)
        b = a + a
        assert b.shape == (5,)
        c = a[:3]
        assert c.shape == (3,)
        assert array([]).shape == (0,)

    def test_set_shape(self):
        from numpy import array, zeros
        a = array([])
        raises(ValueError, "a.shape = []")
        a = array(range(12))
        a.shape = (3, 4)
        assert (a == [range(4), range(4, 8), range(8, 12)]).all()
        a.shape = (3, 2, 2)
        assert a[1, 1, 1] == 7
        a.shape = (3, -1, 2)
        assert a.shape == (3, 2, 2)
        a.shape = 12
        assert a.shape == (12, )
        exc = raises(ValueError, "a.shape = 10")
        assert str(exc.value) == "total size of new array must be unchanged"
        a = array(3)
        a.shape = ()
        #numpy allows this
        a.shape = (1,)
        assert a[0] == 3
        a = array(range(6)).reshape(2,3).T
        raises(AttributeError, 'a.shape = 6')

    def test_reshape(self):
        from numpy import array, zeros
        for a in [array(1), array([1])]:
            for s in [(), (1,)]:
                b = a.reshape(s)
                assert b.shape == s
                assert (b == [1]).all()
        a = array(1.5)
        b = a.reshape(None)
        assert b is not a
        assert b == a
        b[...] = 2.5
        assert a == 2.5
        a = array([]).reshape((0, 2))
        assert a.shape == (0, 2)
        assert a.strides == (16, 8)
        a = array([])
        a.shape = (4, 0, 3, 0, 0, 2)
        assert a.strides == (48, 48, 16, 16, 16, 8)
        a = array(1.5)
        assert a.reshape(()).shape == ()
        a = array(1.5)
        a.shape = ()
        assert a.strides == ()
        a = array(range(12))
        exc = raises(ValueError, "b = a.reshape(())")
        assert str(exc.value) == "total size of new array must be unchanged"
        exc = raises(ValueError, "b = a.reshape((3, 10))")
        assert str(exc.value) == "total size of new array must be unchanged"
        b = a.reshape((3, 4))
        assert b.shape == (3, 4)
        assert (b == [range(4), range(4, 8), range(8, 12)]).all()
        b[:, 0] = 1000
        assert (a == [1000, 1, 2, 3, 1000, 5, 6, 7, 1000, 9, 10, 11]).all()
        a = zeros((4, 2, 3))
        a.shape = (12, 2)
        (a + a).reshape(2, 12) # assert did not explode
        a = array([[[[]]]])
        assert a.reshape((0,)).shape == (0,)
        assert a.reshape((0,), order='C').shape == (0,)
        assert a.reshape((0,), order='A').shape == (0,)
        raises(TypeError, a.reshape, (0,), badarg="C")
        raises(ValueError, a.reshape, (0,), order="K")
        b = a.reshape((0,), order='F')
        assert b.shape == (0,)
        a = array(range(24), 'uint8')
        assert a.reshape([2, 3, 4], order=True).strides ==(1, 2, 6)
        assert a.reshape([2, 3, 4], order=False).strides ==(12, 4, 1)

    def test_slice_reshape(self):
        from numpy import zeros, arange
        a = zeros((4, 2, 3))
        b = a[::2, :, :]
        b.shape = (2, 6)
        exc = raises(AttributeError, "b.shape = 12")
        assert str(exc.value) == \
                           "incompatible shape for a non-contiguous array"
        b = a[::2, :, :].reshape((2, 6))
        assert b.shape == (2, 6)
        b = arange(20)[1:17:2]
        b.shape = (4, 2)
        assert (b == [[1, 3], [5, 7], [9, 11], [13, 15]]).all()
        c = b.reshape((2, 4))
        assert (c == [[1, 3, 5, 7], [9, 11, 13, 15]]).all()

        z = arange(96).reshape((12, -1))
        assert z.shape == (12, 8)
        y = z.reshape((4, 3, 8))
        v = y[:, ::2, :]
        w = y.reshape(96)
        u = v.reshape(64)
        assert y[1, 2, 1] == z[5, 1]
        y[1, 2, 1] = 1000
        # z, y, w, v are views of eachother
        assert z[5, 1] == 1000
        assert v[1, 1, 1] == 1000
        assert w[41] == 1000
        # u is not a view, it is a copy!
        assert u[25] == 41

        a = zeros((5, 2))
        assert a.reshape(-1).shape == (10,)

        raises(ValueError, arange(10).reshape, (5, -1, -1))

    def test_reshape_varargs(self):
        from numpy import arange
        z = arange(96).reshape(12, -1)
        y = z.reshape(4, 3, 8)
        assert y.shape == (4, 3, 8)

    def test_scalar_reshape(self):
        from numpy import array
        a = array(3)
        assert a.reshape([1, 1]).shape == (1, 1)
        assert a.reshape([1]).shape == (1,)
        raises(ValueError, "a.reshape(3)")

    def test_strides(self):
        from numpy import array
        a = array([[1.0, 2.0],
                   [3.0, 4.0]])
        assert a.strides == (16, 8)
        assert a[1:].strides == (16, 8)

    def test_strides_scalar(self):
        from numpy import array
        a = array(42)
        assert a.strides == ()

    def test_add(self):
        from numpy import array
        a = array(range(5))
        b = a + a
        for i in range(5):
            assert b[i] == i + i

        a = array([True, False, True, False], dtype="?")
        b = array([True, True, False, False], dtype="?")
        c = a + b
        for i in range(4):
            assert c[i] == bool(a[i] + b[i])

    def test_add_other(self):
        from numpy import array
        a = array(range(5))
        b = array([i for i in reversed(range(5))])
        c = a + b
        for i in range(5):
            assert c[i] == 4

    def test_add_constant(self):
        from numpy import array
        a = array(range(5))
        b = a + 5
        for i in range(5):
            assert b[i] == i + 5

    def test_radd(self):
        from numpy import array
        r = 3 + array(range(3))
        for i in range(3):
            assert r[i] == i + 3
        r = [1, 2] + array([1, 2])
        assert (r == [2, 4]).all()

    def test_inplace_op_scalar(self):
        from numpy import array
        for op in [
                '__iadd__',
                '__isub__',
                '__imul__',
                '__idiv__',
                '__ifloordiv__',
                '__imod__',
                '__ipow__',
                '__ilshift__',
                '__irshift__',
                '__iand__',
                '__ior__',
                '__ixor__']:
            a = b = array(range(3))
            getattr(a, op).__call__(2)
            assert id(a) == id(b)

    def test_inplace_op_array(self):
        from numpy import array
        for op in [
                '__iadd__',
                '__isub__',
                '__imul__',
                '__idiv__',
                '__ifloordiv__',
                '__imod__',
                '__ipow__',
                '__ilshift__',
                '__irshift__',
                '__iand__',
                '__ior__',
                '__ixor__']:
            a = b = array(range(5))
            c = array(range(5))
            d = array(5 * [2])
            getattr(a, op).__call__(d)
            assert id(a) == id(b)
            reg_op = op.replace('__i', '__')
            for i in range(5):
                assert a[i] == getattr(c[i], reg_op).__call__(d[i])

    def test_add_list(self):
        from numpy import array, ndarray
        a = array(range(5))
        b = list(reversed(range(5)))
        c = a + b
        assert isinstance(c, ndarray)
        for i in range(5):
            assert c[i] == 4

    def test_subtract(self):
        from numpy import array
        a = array(range(5))
        b = a - a
        for i in range(5):
            assert b[i] == 0

    def test_subtract_other(self):
        from numpy import array
        a = array(range(5))
        b = array([1, 1, 1, 1, 1])
        c = a - b
        for i in range(5):
            assert c[i] == i - 1

    def test_subtract_constant(self):
        from numpy import array
        a = array(range(5))
        b = a - 5
        for i in range(5):
            assert b[i] == i - 5

    def test_scalar_subtract(self):
        from numpy import dtype
        int32 = dtype('int32').type
        assert int32(2) - 1 == 1
        assert 1 - int32(2) == -1

    def test_mul(self):
        import numpy

        a = numpy.array(range(5))
        b = a * a
        for i in range(5):
            assert b[i] == i * i
        assert a.dtype.num == b.dtype.num
        assert b.dtype is a.dtype

        a = numpy.array(range(5), dtype=bool)
        b = a * a
        assert b.dtype is numpy.dtype(bool)
        bool_ = numpy.dtype(bool).type
        assert b[0] is bool_(False)
        for i in range(1, 5):
            assert b[i] is bool_(True)

    def test_mul_constant(self):
        from numpy import array
        a = array(range(5))
        b = a * 5
        for i in range(5):
            assert b[i] == i * 5

    def test_div(self):
        from math import isnan
        from numpy import array, dtype

        a = array(range(1, 6))
        b = a / a
        for i in range(5):
            assert b[i] == 1

        a = array(range(1, 6), dtype=bool)
        b = a / a
        assert b.dtype is dtype("int8")
        for i in range(5):
            assert b[i] == 1

        a = array([-1, 0, 1])
        b = array([0, 0, 0])
        c = a / b
        assert (c == [0, 0, 0]).all()

        a = array([-1.0, 0.0, 1.0])
        b = array([0.0, 0.0, 0.0])
        c = a / b
        assert c[0] == float('-inf')
        assert isnan(c[1])
        assert c[2] == float('inf')

        b = array([-0.0, -0.0, -0.0])
        c = a / b
        assert c[0] == float('inf')
        assert isnan(c[1])
        assert c[2] == float('-inf')

    def test_div_other(self):
        from numpy import array
        a = array(range(5))
        b = array([2, 2, 2, 2, 2], float)
        c = a / b
        for i in range(5):
            assert c[i] == i / 2.0

    def test_div_constant(self):
        from numpy import array
        a = array(range(5))
        b = a / 5.0
        for i in range(5):
            assert b[i] == i / 5.0

    def test_floordiv(self):
        from math import isnan
        from numpy import array, dtype

        a = array(range(1, 6))
        b = a // a
        assert (b == [1, 1, 1, 1, 1]).all()

        a = array(range(1, 6), dtype=bool)
        b = a // a
        assert b.dtype is dtype("int8")
        assert (b == [1, 1, 1, 1, 1]).all()

        a = array([-1, 0, 1])
        b = array([0, 0, 0])
        c = a // b
        assert (c == [0, 0, 0]).all()

        a = array([-1.0, 0.0, 1.0])
        b = array([0.0, 0.0, 0.0])
        c = a // b
        assert c[0] == float('-inf')
        assert isnan(c[1])
        assert c[2] == float('inf')

        b = array([-0.0, -0.0, -0.0])
        c = a // b
        assert c[0] == float('inf')
        assert isnan(c[1])
        assert c[2] == float('-inf')

    def test_floordiv_other(self):
        from numpy import array
        a = array(range(5))
        b = array([2, 2, 2, 2, 2], float)
        c = a // b
        assert (c == [0, 0, 1, 1, 2]).all()

    def test_rfloordiv(self):
        from numpy import array
        a = array(range(1, 6))
        b = 3 // a
        assert (b == [3, 1, 1, 0, 0]).all()

    def test_floordiv_constant(self):
        from numpy import array
        a = array(range(5))
        b = a // 2
        assert (b == [0, 0, 1, 1, 2]).all()

    def test_signed_integer_division_overflow(self):
        import numpy as np
        for s in (8, 16, 32, 64):
            for o in ['__div__', '__floordiv__']:
                a = np.array([-2**(s-1)], dtype='int%d' % s)
                assert getattr(a, o)(-1) == 0

    def test_truediv(self):
        from operator import truediv
        from numpy import arange

        assert (truediv(arange(5), 2) == [0., .5, 1., 1.5, 2.]).all()
        assert (truediv(2, arange(3)) == [float("inf"), 2., 1.]).all()

    def test_divmod(self):
        from numpy import arange

        a, b = divmod(arange(10), 3)
        assert (a == [0, 0, 0, 1, 1, 1, 2, 2, 2, 3]).all()
        assert (b == [0, 1, 2, 0, 1, 2, 0, 1, 2, 0]).all()

    def test_rdivmod(self):
        from numpy import arange

        a, b = divmod(3, arange(1, 5))
        assert (a == [3, 1, 1, 0]).all()
        assert (b == [0, 1, 0, 3]).all()

    def test_lshift(self):
        from numpy import array

        a = array([0, 1, 2, 3])
        assert (a << 2 == [0, 4, 8, 12]).all()
        a = array([True, False])
        assert (a << 2 == [4, 0]).all()
        a = array([1.0])
        raises(TypeError, lambda: a << 2)

    def test_rlshift(self):
        from numpy import arange

        a = arange(3)
        assert (2 << a == [2, 4, 8]).all()

    def test_rshift(self):
        import numpy as np
        a = np.arange(10)
        assert (a >> 2 == [0, 0, 0, 0, 1, 1, 1, 1, 2, 2]).all()
        a = np.array([True, False])
        assert (a >> 1 == [0, 0]).all()
        a = np.arange(3, dtype=float)
        raises(TypeError, lambda: a >> 1)
        a = np.array([123], dtype='uint64')
        b = a >> 1
        assert b == 61
        assert b.dtype.type is np.uint64
        a = np.array(123, dtype='uint64')
        exc = raises(TypeError, "a >> 1")
        assert 'not supported for the input types' in exc.value.message

    def test_rrshift(self):
        from numpy import arange

        a = arange(5)
        assert (2 >> a == [2, 1, 0, 0, 0]).all()

    def test_pow(self):
        from numpy import array
        a = array(range(5), float)
        b = a ** a
        for i in range(5):
            assert b[i] == i ** i

        a = array(range(5))
        assert (a ** 2 == a * a).all()

    def test_pow_other(self):
        from numpy import array
        a = array(range(5), float)
        b = array([2, 2, 2, 2, 2])
        c = a ** b
        for i in range(5):
            assert c[i] == i ** 2

    def test_pow_constant(self):
        from numpy import array
        a = array(range(5), float)
        b = a ** 2
        for i in range(5):
            assert b[i] == i ** 2

    def test_mod(self):
        from numpy import array
        a = array(range(1, 6))
        b = a % a
        for i in range(5):
            assert b[i] == 0

        a = array(range(1, 6), float)
        b = (a + 1) % a
        assert b[0] == 0
        for i in range(1, 5):
            assert b[i] == 1

    def test_mod_other(self):
        from numpy import array
        a = array(range(5))
        b = array([2, 2, 2, 2, 2])
        c = a % b
        for i in range(5):
            assert c[i] == i % 2

    def test_mod_constant(self):
        from numpy import array
        a = array(range(5))
        b = a % 2
        for i in range(5):
            assert b[i] == i % 2

    def test_rand(self):
        from numpy import arange

        a = arange(5)
        assert (3 & a == [0, 1, 2, 3, 0]).all()

    def test_ror(self):
        from numpy import arange

        a = arange(5)
        assert (3 | a == [3, 3, 3, 3, 7]).all()

    def test_xor(self):
        from numpy import arange

        a = arange(5)
        assert (a ^ 3 == [3, 2, 1, 0, 7]).all()

    def test_rxor(self):
        from numpy import arange

        a = arange(5)
        assert (3 ^ a == [3, 2, 1, 0, 7]).all()

    def test_pos(self):
        from numpy import array
        a = array([1., -2., 3., -4., -5.])
        b = +a
        for i in range(5):
            assert b[i] == a[i]

        a = +array(range(5))
        for i in range(5):
            assert a[i] == i

    def test_neg(self):
        from numpy import array
        a = array([1., -2., 3., -4., -5.])
        b = -a
        for i in range(5):
            assert b[i] == -a[i]

        a = -array(range(5), dtype="int8")
        for i in range(5):
            assert a[i] == -i

    def test_abs(self):
        from numpy import array
        a = array([1., -2., 3., -4., -5.])
        b = abs(a)
        for i in range(5):
            assert b[i] == abs(a[i])

        a = abs(array(range(-5, 5), dtype="int8"))
        for i in range(-5, 5):
            assert a[i + 5] == abs(i)

    def test_auto_force(self):
        from numpy import array
        a = array(range(5))
        b = a - 1
        a[2] = 3
        for i in range(5):
            assert b[i] == i - 1

        a = array(range(5))
        b = a + a
        c = b + b
        b[1] = 5
        assert c[1] == 4

    def test_getslice(self):
        from numpy import array
        a = array(5)
        exc = raises(ValueError, "a[:]")
        assert exc.value[0] == "cannot slice a 0-d array"
        a = array(range(5))
        s = a[1:5]
        assert len(s) == 4
        for i in range(4):
            assert s[i] == a[i + 1]

        s = (a + a)[1:2]
        assert len(s) == 1
        assert s[0] == 2
        s[:1] = array([5])
        assert s[0] == 5

    def test_getslice_step(self):
        from numpy import array
        a = array(range(10))
        s = a[1:9:2]
        assert len(s) == 4
        for i in range(4):
            assert s[i] == a[2 * i + 1]

    def test_slice_update(self):
        from numpy import array
        a = array(range(5))
        s = a[0:3]
        s[1] = 10
        assert a[1] == 10
        a[2] = 20
        assert s[2] == 20

    def test_slice_invaidate(self):
        # check that slice shares invalidation list with
        from numpy import array
        a = array(range(5))
        s = a[0:2]
        b = array([10, 11])
        c = s + b
        a[0] = 100
        assert c[0] == 10
        assert c[1] == 12
        d = s + b
        a[1] = 101
        assert d[0] == 110
        assert d[1] == 12

    def test_sum(self):
        from numpy import array, zeros, float16, complex64, str_, isscalar, add
        a = array(range(5))
        assert a.sum() == 10
        assert a[:4].sum() == 6

        a = array([True] * 5, bool)
        assert a.sum() == 5

        assert array([True, False] * 200).sum() == 200
        assert array([True, False] * 200, dtype='int8').sum() == 200
        assert array([True, False] * 200).sum(dtype='int8') == -56
        assert type(array([True, False] * 200, dtype='float16').sum()) is float16
        assert type(array([True, False] * 200, dtype='complex64').sum()) is complex64

        raises(TypeError, 'a.sum(axis=0, out=3)')
        raises(ValueError, 'a.sum(axis=2)')
        d = array(0.)
        b = a.sum(out=d)
        assert b == d
        assert b is d
        c = array(1.5+2.5j)
        assert c.real == 1.5
        assert c.imag == 2.5
        a.sum(out=c.imag)
        assert c.real == 1.5
        assert c.imag == 5

        assert list(zeros((0, 2)).sum(axis=1)) == []

        a = array([1, 2, 3, 4]).sum()
        s = isscalar(a)
        assert s is True
        a = add.reduce([1.0, 2, 3, 4])
        s = isscalar(a)
        assert s is True,'%r is not a scalar' % type(a)

    def test_reduce_nd(self):
        from numpy import arange, array
        a = arange(15).reshape(5, 3)
        assert a.sum() == 105
        assert a.sum(keepdims=True) == 105
        assert a.sum(keepdims=True).shape == (1, 1)
        assert a.max() == 14
        assert array([]).sum() == 0.0
        assert array([]).reshape(0, 2).sum() == 0.
        assert (array([]).reshape(0, 2).sum(0) == [0., 0.]).all()
        assert (array([]).reshape(0, 2).prod(0) == [1., 1.]).all()
        raises(ValueError, 'array([]).max()')
        assert (a.sum(0) == [30, 35, 40]).all()
        assert (a.sum(axis=0) == [30, 35, 40]).all()
        assert (a.sum(1) == [3, 12, 21, 30, 39]).all()
        assert (a.sum(-1) == a.sum(-1)).all()
        assert (a.sum(-2) == a.sum(-2)).all()
        raises(ValueError, a.sum, -3)
        raises(ValueError, a.sum, 2)
        assert (a.max(0) == [12, 13, 14]).all()
        assert (a.max(1) == [2, 5, 8, 11, 14]).all()
        assert ((a + a).max() == 28)
        assert ((a + a).max(0) == [24, 26, 28]).all()
        assert ((a + a).sum(1) == [6, 24, 42, 60, 78]).all()
        a = array(range(105)).reshape(3, 5, 7)
        assert (a[:, 1, :].sum(0) == [126, 129, 132, 135, 138, 141, 144]).all()
        assert (a[:, 1, :].sum(1) == [70, 315, 560]).all()
        raises (ValueError, 'a[:, 1, :].sum(2)')
        assert ((a + a).T.sum(2).T == (a + a).sum(0)).all()
        assert (a.reshape(1,-1).sum(0) == range(105)).all()
        assert (a.reshape(1,-1).sum(1) == 5460)
        assert (array([[1,2],[3,4]]).prod(0) == [3, 8]).all()
        assert (array([[1,2],[3,4]]).prod(1) == [2, 12]).all()

    def test_prod(self):
        from numpy import array, dtype
        a = array(range(1, 6))
        assert a.prod() == 120.0
        assert a.prod(keepdims=True) == 120.0
        assert a.prod(keepdims=True).shape == (1,)
        assert a[:4].prod() == 24.0
        for dt in ['bool', 'int8', 'uint8', 'int16', 'uint16']:
            a = array([True, False], dtype=dt)
            assert a.prod() == 0
            assert a.prod().dtype is dtype('uint' if dt[0] == 'u' else 'int')
        for dt in ['l', 'L', 'q', 'Q', 'e', 'f', 'd', 'F', 'D']:
            a = array([True, False], dtype=dt)
            assert a.prod() == 0
            assert a.prod().dtype is dtype(dt)

    def test_max(self):
        from numpy import array, zeros
        a = array([-1.2, 3.4, 5.7, -3.0, 2.7])
        assert a.max() == 5.7
        assert a.max().shape == ()
        assert a.max(axis=(0,)) == 5.7
        assert a.max(axis=(0,)).shape == ()
        assert a.max(keepdims=True) == 5.7
        assert a.max(keepdims=True).shape == (1,)
        b = array([])
        raises(ValueError, "b.max()")
        assert list(zeros((0, 2)).max(axis=1)) == []

    def test_max_add(self):
        from numpy import array
        a = array([-1.2, 3.4, 5.7, -3.0, 2.7])
        assert (a + a).max() == 11.4

    def test_min(self):
        from numpy import array, zeros
        a = array([-1.2, 3.4, 5.7, -3.0, 2.7])
        assert a.min() == -3.0
        assert a.min().shape == ()
        assert a.min(axis=(0,)) == -3.0
        assert a.min(axis=(0,)).shape == ()
        assert a.min(keepdims=True) == -3.0
        assert a.min(keepdims=True).shape == (1,)
        b = array([])
        raises(ValueError, "b.min()")
        assert list(zeros((0, 2)).min(axis=1)) == []

    def test_argmax(self):
        from numpy import array
        a = array([-1.2, 3.4, 5.7, -3.0, 2.7])
        r = a.argmax()
        assert r == 2
        b = array([])
        raises(ValueError, b.argmax)

        a = array(range(-5, 5))
        r = a.argmax()
        assert r == 9
        b = a[::2]
        r = b.argmax()
        assert r == 4
        r = (a + a).argmax()
        assert r == 9
        a = array([1, 0, 0])
        assert a.argmax() == 0
        a = array([0, 0, 1])
        assert a.argmax() == 2

        a = array([[1, 2], [3, 4], [5, 6]])
        assert a.argmax() == 5
        assert a.argmax(axis=None, out=None) == 5
        assert a[:2, ].argmax() == 3
        assert (a.argmax(axis=0) == array([2, 2])).all()

    def test_argmin(self):
        import numpy as np
        a = np.array([-1.2, 3.4, 5.7, -3.0, 2.7])
        assert a.argmin() == 3
        assert a.argmin(axis=0) == 3
        assert a.argmin(axis=None, out=None) == 3
        b = np.array([])
        raises(ValueError, "b.argmin()")
        c = np.arange(6).reshape(2, 3)
        assert c.argmin() == 0
        assert (c.argmin(axis=0) == np.array([0, 0, 0])).all()
        assert (c.argmin(axis=1) == [0, 0]).all()


    def test_all(self):
        from numpy import array
        a = array(range(5))
        assert a.all() == False
        a[0] = 3.0
        assert a.all() == True
        assert a.all(keepdims=True) == True
        assert a.all(keepdims=True).shape == (1,)
        b = array([])
        assert b.all() == True

    def test_any(self):
        from numpy import array, zeros
        a = array(range(5))
        assert a.any() == True
        assert a.any(keepdims=True) == True
        assert a.any(keepdims=True).shape == (1,)
        b = zeros(5)
        assert b.any() == False
        c = array([])
        assert c.any() == False

    def test_dtype_guessing(self):
        from numpy import array, dtype
        import sys
        assert array([True]).dtype is dtype(bool)
        assert array([True, False]).dtype is dtype(bool)
        assert array([True, 1]).dtype is dtype(int)
        assert array([1, 2, 3]).dtype is dtype(int)
        assert array([1L, 2, 3]).dtype is dtype('q')
        assert array([1.2, True]).dtype is dtype(float)
        assert array([1.2, 5]).dtype is dtype(float)
        assert array([]).dtype is dtype(float)
        float64 = dtype('float64').type
        int8 = dtype('int8').type
        bool_ = dtype('bool').type
        assert array([float64(2)]).dtype is dtype(float)
        assert array([int8(3)]).dtype is dtype("int8")
        assert array([bool_(True)]).dtype is dtype(bool)
        assert array([bool_(True), 3.0]).dtype is dtype(float)
        assert array(sys.maxint + 42).dtype is dtype('Q')
        assert array([sys.maxint + 42] * 2).dtype is dtype('Q')
        assert array([sys.maxint + 42, 123]).dtype is dtype(float)
        assert array([sys.maxint + 42, 123L]).dtype is dtype(float)
        assert array([1+2j, 123]).dtype is dtype(complex)
        assert array([1+2j, 123L]).dtype is dtype(complex)

    def test_comparison(self):
        import operator
        from numpy import array, dtype

        a = array(range(5))
        b = array(range(5), float)
        for func in [
            operator.eq, operator.ne, operator.lt, operator.le, operator.gt,
            operator.ge
        ]:
            c = func(a, 3)
            assert c.dtype is dtype(bool)
            for i in xrange(5):
                assert c[i] == func(a[i], 3)

            c = func(b, 3)
            assert c.dtype is dtype(bool)
            for i in xrange(5):
                assert c[i] == func(b[i], 3)

    def test___nonzero__(self):
        from numpy import array
        a = array([1, 2])
        raises(ValueError, bool, a)
        raises(ValueError, bool, a == a)
        assert bool(array(1))
        assert not bool(array(0))
        assert bool(array([1]))
        assert not bool(array([0]))

    def test_slice_assignment(self):
        from numpy import array
        a = array(range(5))
        a[::-1] = a
        assert (a == [4, 3, 2, 1, 0]).all()
        # but we force intermediates
        a = array(range(5))
        a[::-1] = a + a
        assert (a == [8, 6, 4, 2, 0]).all()

    def test_virtual_views(self):
        from numpy import arange
        a = arange(15)
        c = (a + a)
        d = c[::2]
        assert d[3] == 12
        c[6] = 5
        assert d[3] == 5
        a = arange(15)
        c = (a + a)
        d = c[::2][::2]
        assert d[1] == 8
        b = a + a
        c = b[::2]
        c[:] = 3
        assert b[0] == 3
        assert b[1] == 2

    def test_realimag_views(self):
        from numpy import arange, array
        a = array(1.5)
        assert a.real == 1.5
        assert a.imag == 0.0
        a = array([1.5, 2.5])
        assert (a.real == [1.5, 2.5]).all()
        assert (a.imag == [0.0, 0.0]).all()
        a = arange(15)
        b = a.real
        b[5]=50
        assert a[5] == 50
        b = a.imag
        assert b[7] == 0
        raises(ValueError, 'b[7] = -2')
        raises(TypeError, 'a.imag = -2')
        a = array(['abc','def'],dtype='S3')
        b = a.real
        assert a[0] == b[0]
        assert a[1] == b[1]
        b[1] = 'xyz'
        assert a[1] == 'xyz'
        assert a.imag[0] == ''
        raises(TypeError, 'a.imag = "qop"')
        a=array([[1+1j, 2-3j, 4+5j],[-6+7j, 8-9j, -2-1j]])
        assert a.real[0,1] == 2
        a.real[0,1] = -20
        assert a[0,1].real == -20
        b = a.imag
        assert b[1,2] == -1
        b[1,2] = 30
        assert a[1,2].imag == 30
        a.real = 13
        assert a[1,1].real == 13
        a=array([1+1j, 2-3j, 4+5j, -6+7j, 8-9j, -2-1j])
        a.real = 13
        assert a[3].real == 13
        a.imag = -5
        a.imag[3] = -10
        assert a[3].imag == -10
        assert a[2].imag == -5

        assert arange(4, dtype='>c8').imag.max() == 0.0
        assert arange(4, dtype='<c8').imag.max() == 0.0
        assert arange(4, dtype='>c8').real.max() == 3.0
        assert arange(4, dtype='<c8').real.max() == 3.0

    def test_scalar_view(self):
        from numpy import array
        import sys
        a = array(3, dtype='int32')
        b = a.view(dtype='float32')
        assert b.shape == ()
        assert b < 1
        exc = raises(ValueError, a.view, 'int8')
        assert exc.value[0] == "new type not compatible with array."
        exc = raises(TypeError, a.view, 'string')
        assert exc.value[0] == "data-type must not be 0-sized"
        if sys.byteorder == 'big':
            assert a.view('S4') == '\x00\x00\x00\x03'
        else:
            assert a.view('S4') == '\x03'
        a = array('abc1', dtype='c')
        assert (a == ['a', 'b', 'c', '1']).all()
        assert a.view('S4') == 'abc1'
        b = a.view([('a', 'i2'), ('b', 'i2')])
        assert b.shape == (1,)
        if sys.byteorder == 'big':
            assert b[0][0] == 0x6162
            assert b[0][1] == 0x6331
        else:
            assert b[0][0] == 25185
            assert b[0][1] == 12643
        a = array([(1, 2)], dtype=[('a', 'int64'), ('b', 'int64')])[0]
        assert a.shape == ()
        if sys.byteorder == 'big':
            assert a.view('S16') == '\x00' * 7 + '\x01' + '\x00' * 7 + '\x02'
        else:
            assert a.view('S16') == '\x01' + '\x00' * 7 + '\x02'
        a = array(2, dtype='<i8')
        b = a.view('<c8')
        assert 0 < b.real < 1
        assert b.real.tostring() == '\x02\x00\x00\x00'
        assert b.imag.tostring() == '\x00' * 4

    def test_array_view(self):
        from numpy import array, dtype
        import sys
        x = array((1, 2), dtype='int8')
        assert x.shape == (2,)
        y = x.view(dtype='int16')
        assert x.shape == (2,)
        if sys.byteorder == 'big':
            assert y[0] == 0x0102
        else:
            assert y[0] == 513 == 0x0201
        assert y.dtype == dtype('int16')
        y[0] = 670
        if sys.byteorder == 'little':
            assert x[0] == -98
            assert x[1] == 2
        else:
            assert x[0] == 2
            assert x[1] == -98
        f = array([1000, -1234], dtype='i4')
        nnp = self.non_native_prefix
        d = f.view(dtype=nnp + 'i4')
        assert (d == [-402456576,  788267007]).all()
        x = array(range(15), dtype='i2').reshape(3,5)
        exc = raises(ValueError, x.view, dtype='i4')
        assert exc.value[0] == "new type not compatible with array."
        exc = raises(TypeError, x.view, 'string')
        assert exc.value[0] == "data-type must not be 0-sized"
        assert x.view('int8').shape == (3, 10)
        x = array(range(15), dtype='int16').reshape(3,5).T
        assert x.view('int8').shape == (10, 3)
        #assert x.view('S2')[1][1] == '\x06'
        x = array(['abc', 'defg'], dtype='c')
        assert x.view('S1')[0] == 'a'
        assert x.view('S1')[1] == 'd'
        x = array(['abc', 'defg'], dtype='string')
        assert x.view('S4')[0] == 'abc'
        assert x.view('S4')[1] == 'defg'
        a = array([(1, 2)], dtype=[('a', 'int64'), ('b', 'int64')])
        if sys.byteorder == 'big':
            assert a.view('S16')[0] == '\x00' * 7 + '\x01' + '\x00' * 7 + '\x02'
        else:
            assert a.view('S16')[0] == '\x01' + '\x00' * 7 + '\x02'

    def test_half_conversions(self):
        from numpy import array, arange
        from math import isnan, isinf
        e = array([0, -1, -float('inf'), float('nan'), 6], dtype='float16')
        assert map(isnan, e) == [False, False, False, True, False]
        assert map(isinf, e) == [False, False, True, False, False]
        assert e.argmax() == 3
        # numpy preserves value for uint16 -> cast_as_float16 ->
        #     convert_to_float64 -> convert_to_float16 -> uint16
        #  even for float16 various float16 nans
        all_f16 = arange(0xfe00, 0xffff, dtype='uint16')
        all_f16.dtype = 'float16'
        all_f32 = array(all_f16, dtype='float32')
        b = array(all_f32, dtype='float16')
        c = b.view(dtype='uint16')
        d = all_f16.view(dtype='uint16')
        assert (c == d).all()

    def test_ndarray_view_empty(self):
        from numpy import array, dtype
        x = array([], dtype=[('a', 'int8'), ('b', 'int8')])
        y = x.view(dtype='int16')

    def test_view_of_slice(self):
        from numpy import empty, dtype
        x = empty([6], 'uint32')
        x.fill(0xdeadbeef)
        s = x[::3]
        exc = raises(ValueError, s.view, 'uint8')
        assert exc.value[0] == 'new type not compatible with array.'
        s[...] = 2
        v = s.view(x.__class__)
        assert v.strides == s.strides
        assert v.base is s.base
        assert (v == 2).all()
        y = empty([6,6], 'uint32')
        s = y.swapaxes(0, 1)
        v = s.view(y.__class__)
        assert v.strides == (4, 24)

        x = empty([12, 8, 8], 'float64')
        y = x[::-4, :, :]
        assert y.base is x
        assert y.strides == (-2048, 64, 8)
        y[:] = 1000
        assert x[-1, 0, 0] == 1000

        a = empty([3, 2, 1], dtype='float64')
        b = a.view(dtype('uint32'))
        assert b.strides == (16, 8, 4)
        assert b.shape == (3, 2, 2)
        b.fill(0xdeadbeef)

    def test_tolist_scalar(self):
        from numpy import dtype
        int32 = dtype('int32').type
        bool_ = dtype('bool').type
        x = int32(23)
        assert x.tolist() == 23
        assert type(x.tolist()) is int
        y = bool_(True)
        assert y.tolist() is True

    def test_tolist_zerodim(self):
        from numpy import array
        x = array(3)
        assert x.tolist() == 3
        assert type(x.tolist()) is int

    def test_tolist_singledim(self):
        from numpy import array
        a = array(range(5))
        assert a.tolist() == [0, 1, 2, 3, 4]
        assert type(a.tolist()[0]) is int
        b = array([0.2, 0.4, 0.6])
        assert b.tolist() == [0.2, 0.4, 0.6]

    def test_tolist_multidim(self):
        from numpy import array
        a = array([[1, 2], [3, 4]])
        assert a.tolist() == [[1, 2], [3, 4]]

    def test_tolist_view(self):
        from numpy import array
        a = array([[1, 2], [3, 4]])
        assert (a + a).tolist() == [[2, 4], [6, 8]]

    def test_tolist_object(self):
        from numpy import array
        a = array([0], dtype=object)
        assert a.tolist() == [0]

    def test_tolist_object_slice(self):
        from numpy import array
        list_expected = [slice(0, 1), 0]
        a = array(list_expected, dtype=object)
        assert a.tolist() == list_expected

    def test_tolist_object_slice_2d(self):
        from numpy import array
        a = array([(slice(0, 1), 1), (0, 1)], dtype=object)
        assert a.tolist() == [[slice(0, 1, None), 1], [0, 1]]

    def test_tolist_slice(self):
        from numpy import array
        a = array([[17.1, 27.2], [40.3, 50.3]])
        assert a[:, 0].tolist() == [17.1, 40.3]
        assert a[0].tolist() == [17.1, 27.2]

    def test_concatenate(self):
        from numpy import array, concatenate, dtype
        exc = raises(ValueError, concatenate, (array(1.5), array(2.5)))
        assert exc.value[0] == 'zero-dimensional arrays cannot be concatenated'
        a = concatenate((array(1.5), array(2.5)), axis=None)
        assert (a == [1.5, 2.5]).all()
        assert exc.value[0] == 'zero-dimensional arrays cannot be concatenated'
        exc = raises(ValueError, concatenate, (array([1.5]), array(2.5)))
        assert exc.value[0] == 'all the input arrays must have same number ' \
                               'of dimensions'
        exc = raises(ValueError, concatenate, (array(1.5), array([2.5])))
        assert exc.value[0] == 'zero-dimensional arrays cannot be concatenated'
        a = concatenate((array([1.5]), array([2.5])))
        assert (a == [1.5, 2.5]).all()
        a1 = array([0,1,2])
        a2 = array([3,4,5])
        a = concatenate((a1, a2))
        assert len(a) == 6
        assert (a == [0,1,2,3,4,5]).all()
        assert a.dtype is dtype(int)
        a = concatenate((a1, a2), axis=0)
        assert (a == [0,1,2,3,4,5]).all()
        a = concatenate((a1, a2), axis=-1)
        assert (a == [0,1,2,3,4,5]).all()
        a = concatenate((a1, a2), axis=None)
        assert (a == [0,1,2,3,4,5]).all()

        b1 = array([[1, 2], [3, 4]])
        b2 = array([[5, 6]])
        b = concatenate((b1, b2), axis=0)
        assert (b == [[1, 2],[3, 4],[5, 6]]).all()
        c = concatenate((b1, b2.T), axis=1)
        assert (c == [[1, 2, 5],[3, 4, 6]]).all()
        c1 = concatenate((b1, b2), axis=None)
        assert (c1 == [1, 2, 3, 4, 5, 6]).all()
        d = concatenate(([0],[1]))
        assert (d == [0,1]).all()
        e1 = array([[0,1],[2,3]])
        e = concatenate(e1)
        assert (e == [0,1,2,3]).all()
        f1 = array([0,1])
        f = concatenate((f1, [2], f1, [7]))
        assert (f == [0,1,2,0,1,7]).all()

        g1 = array([[0,1,2]])
        g2 = array([[3,4,5]])
        g = concatenate((g1, g2), axis=-2)
        assert (g == [[0,1,2],[3,4,5]]).all()
        exc = raises(IndexError, concatenate, (g1, g2), axis=-3)
        assert str(exc.value) == "axis -3 out of bounds [0, 2)"
        exc = raises(IndexError, concatenate, (g1, g2), axis=2)
        assert str(exc.value) == "axis 2 out of bounds [0, 2)"

        exc = raises(ValueError, concatenate, ())
        assert str(exc.value) == \
                "need at least one array to concatenate"

        exc = raises(ValueError, concatenate, (a1, b1), axis=0)
        assert str(exc.value) == \
                "all the input arrays must have same number of dimensions"

        exc = raises(ValueError, concatenate, (b1, b2), axis=1)
        assert str(exc.value) == \
                "all the input array dimensions except for the " \
                "concatenation axis must match exactly"

        g1 = array([0,1,2])
        g2 = array([[3,4,5]])
        exc = raises(ValueError, concatenate, (g1, g2), axis=0)
        assert str(exc.value) == \
                "all the input arrays must have same number of dimensions"

        a = array([1, 2, 3, 4, 5, 6])
        a = (a + a)[::2]
        b = concatenate((a[:3], a[-3:]))
        assert (b == [2, 6, 10, 2, 6, 10]).all()
        a = concatenate((array([1]), array(['abc'])))
        if dtype('l').itemsize == 4:  # 32-bit platform
            assert str(a.dtype) == '|S11'
        else:
            assert str(a.dtype) == '|S21'
        a = concatenate((array([]), array(['abc'])))
        assert a[0] == 'abc'
        a = concatenate((['abcdef'], ['abc']))
        assert a[0] == 'abcdef'
        assert str(a.dtype) == '|S6'

    def test_record_concatenate(self):
        # only an exact match can succeed
        from numpy import zeros, concatenate
        a = concatenate((zeros((2,),dtype=[('x', int), ('y', float)]),
                         zeros((2,),dtype=[('x', int), ('y', float)])))
        assert a.shape == (4,)
        exc = raises(TypeError, concatenate,
                            (zeros((2,), dtype=[('x', int), ('y', float)]),
                            (zeros((2,), dtype=[('x', float), ('y', float)]))))
        assert str(exc.value).startswith('invalid type promotion')
        exc = raises(TypeError, concatenate, ([1], zeros((2,),
                                            dtype=[('x', int), ('y', float)])))
        assert str(exc.value).startswith('invalid type promotion')
        exc = raises(TypeError, concatenate, (['abc'], zeros((2,),
                                            dtype=[('x', int), ('y', float)])))
        assert str(exc.value).startswith('invalid type promotion')

    def test_flatten(self):
        from numpy import array

        assert array(3).flatten().shape == (1,)
        a = array([[1, 2], [3, 4]])
        b = a.flatten()
        c = a.ravel()
        a[0, 0] = 15
        assert b[0] == 1
        assert c[0] == 15
        a = array([[1, 2, 3], [4, 5, 6]])
        assert (a.flatten() == [1, 2, 3, 4, 5, 6]).all()
        a = array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        assert (a.flatten() == [1, 2, 3, 4, 5, 6, 7, 8]).all()
        a = array([1, 2, 3, 4, 5, 6, 7, 8])
        assert (a[::2].flatten() == [1, 3, 5, 7]).all()
        a = array([1, 2, 3])
        assert ((a + a).flatten() == [2, 4, 6]).all()
        a = array(2)
        assert (a.flatten() == [2]).all()
        a = array([[1, 2], [3, 4]])
        assert (a.T.flatten() == [1, 3, 2, 4]).all()

    def test_itemsize(self):
        from numpy import ones, dtype, array

        for obj in [float, bool, int]:
            assert ones(1, dtype=obj).itemsize == dtype(obj).itemsize
        assert (ones(1) + ones(1)).itemsize == 8
        assert array(1.0).itemsize == 8
        assert ones(1)[:].itemsize == 8

    def test_nbytes(self):
        from numpy import array, ones

        assert ones(1).nbytes == 8
        assert ones((2, 2)).nbytes == 32
        assert ones((2, 2))[1:,].nbytes == 16
        assert (ones(1) + ones(1)).nbytes == 8
        assert array(3.0).nbytes == 8

    def test_repeat(self):
        from numpy import array
        a = array([[1, 2], [3, 4]])
        assert (a.repeat(3) == [1, 1, 1, 2, 2, 2,
                                 3, 3, 3, 4, 4, 4]).all()
        assert (a.repeat(2, axis=0) == [[1, 2], [1, 2], [3, 4],
                                         [3, 4]]).all()
        assert (a.repeat(2, axis=1) == [[1, 1, 2, 2], [3, 3,
                                                        4, 4]]).all()
        assert (array([1, 2]).repeat(2) == array([1, 1, 2, 2])).all()

    def test_resize(self):
        import numpy as np
        a = np.array([1,2,3])
        import sys
        if '__pypy__' in sys.builtin_module_names:
            raises(NotImplementedError, a.resize, ())

    def test_squeeze(self):
        import numpy as np
        a = np.array([1,2,3])
        assert a.squeeze() is a
        a = np.array([[1,2,3]])
        b = a.squeeze()
        assert b.shape == (3,)
        assert (b == a).all()
        b[1] = -1
        assert a[0][1] == -1
        a = np.arange(9).reshape((3, 1, 3, 1))
        b = a.squeeze(1)
        assert b.shape == (3, 3, 1)
        b = a.squeeze((1,))
        assert b.shape == (3, 3, 1)
        b = a.squeeze((1, -1))
        assert b.shape == (3, 3)
        exc = raises(ValueError, a.squeeze, 5)
        assert exc.value.message == "'axis' entry 5 is out of bounds [-4, 4)"
        exc = raises(ValueError, a.squeeze, 0)
        assert exc.value.message == "cannot select an axis to squeeze out " \
                                    "which has size not equal to one"
        exc = raises(ValueError, a.squeeze, (1, 1))
        assert exc.value.message == "duplicate value in 'axis'"

    def test_swapaxes(self):
        from numpy import array
        x = array([])
        raises(ValueError, x.swapaxes,0, 2)
        x = array([[1, 2]])
        assert x.swapaxes(0, 0) is not x
        exc = raises(ValueError, x.swapaxes, -3, 0)
        assert exc.value.message == "bad axis1 argument to swapaxes"
        exc = raises(ValueError, x.swapaxes, 0, 3)
        assert exc.value.message == "bad axis2 argument to swapaxes"
        # testcases from numpy docstring
        x = array([[1, 2, 3]])
        assert (x.swapaxes(0, 1) == array([[1], [2], [3]])).all()
        x = array([[[0,1],[2,3]],[[4,5],[6,7]]]) # shape = (2, 2, 2)
        assert (x.swapaxes(0, 2) == array([[[0, 4], [2, 6]],
                                           [[1, 5], [3, 7]]])).all()
        assert (x.swapaxes(0, 1) == array([[[0, 1], [4, 5]],
                                           [[2, 3], [6, 7]]])).all()
        assert (x.swapaxes(1, 2) == array([[[0, 2], [1, 3]],
                                           [[4, 6],[5, 7]]])).all()

        # more complex shape i.e. (2, 2, 3)
        x = array([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]])
        assert (x.swapaxes(0, 1) == array([[[1, 2, 3], [7, 8, 9]],
                                           [[4, 5, 6], [10, 11, 12]]])).all()
        assert (x.swapaxes(0, 2) == array([[[1, 7], [4, 10]], [[2, 8], [5, 11]],
                                           [[3, 9], [6, 12]]])).all()
        assert (x.swapaxes(1, 2) == array([[[1, 4], [2, 5], [3, 6]],
                                           [[7, 10], [8, 11],[9, 12]]])).all()

        # test slice
        assert (x[0:1,0:2].swapaxes(0,2) == array([[[1], [4]], [[2], [5]],
                                                   [[3], [6]]])).all()
        # test virtual
        assert ((x + x).swapaxes(0,1) == array([[[ 2,  4,  6], [14, 16, 18]],
                                         [[ 8, 10, 12], [20, 22, 24]]])).all()
        raises(ValueError, array(1).swapaxes, 10, 12)

    def test_filter_bug(self):
        from numpy import array
        a = array([1.0,-1.0])
        a[a<0] = -a[a<0]
        assert (a == [1, 1]).all()

    def test_int_list_index(slf):
        from numpy import array, arange
        assert (array([10,11,12,13])[[1,2]] == [11, 12]).all()
        assert (arange(6).reshape((2,3))[[0,1]] == [[0, 1, 2], [3, 4, 5]]).all()
        assert arange(6).reshape((2,3))[(0,1)] == 1

    def test_int_array_index(self):
        from numpy import array, arange, zeros
        b = arange(10)[array([3, 2, 1, 5])]
        assert (b == [3, 2, 1, 5]).all()
        raises(IndexError, "arange(10)[array([10])]")
        assert (arange(10)[[-5, -3]] == [5, 7]).all()
        raises(IndexError, "arange(10)[[-11]]")
        a = arange(1)
        a[[0, 0]] += 1
        assert a[0] == 1
        assert (zeros(1)[[]] == []).all()

    def test_int_array_index_setitem(self):
        from numpy import arange, zeros, array
        a = arange(10)
        a[[3, 2, 1, 5]] = zeros(4, dtype=int)
        assert (a == [0, 0, 0, 0, 4, 0, 6, 7, 8, 9]).all()
        a[[-9, -8]] = [1, 1]
        assert (a == [0, 1, 1, 0, 4, 0, 6, 7, 8, 9]).all()
        raises(IndexError, "arange(10)[array([10])] = 3")
        raises(IndexError, "arange(10)[[-11]] = 3")
        a = zeros(10)
        b = array([3,4,5])
        a[b] = 1
        assert (a == [0, 0, 0, 1, 1, 1, 0, 0, 0, 0]).all()

    def test_array_scalar_index(self):
        import numpy as np
        a = np.array([[1, 2, 3],
                      [4, 5, 6],
                      [7, 8, 9]])
        assert (a[np.array(0)] == a[0]).all()
        assert (a[np.array(1)] == a[1]).all()
        exc = raises(IndexError, "a[np.array(True)]")
        assert exc.value.message == 'in the future, 0-d boolean arrays will be interpreted as a valid boolean index'
        exc = raises(IndexError, "a[np.array(1.1)]")
        assert exc.value.message == 'arrays used as indices must be of ' \
                                    'integer (or boolean) type'

        a[np.array(1)] = a[2]
        assert a[1][1] == 8
        exc = raises(IndexError, "a[np.array(1.1)] = a[2]")
        assert exc.value.message == 'arrays used as indices must be of ' \
                                    'integer (or boolean) type'

    def test_bool_array_index(self):
        from numpy import arange, array
        b = arange(10)
        assert (b[array([True, False, True])] == [0, 2]).all()
        raises(IndexError, "array([1, 2])[array([True, True, True])]")
        raises(IndexError, "b[array([[True, False], [True, False]])]")
        a = array([[1,2,3],[4,5,6],[7,8,9]],int)
        c = array([True,False,True],bool)
        b = a[c]
        assert (a[c] == [[1, 2, 3], [7, 8, 9]]).all()
        c = array([True])
        b = a[c]
        assert b.shape == (1, 3)

    def test_bool_array_index_setitem(self):
        from numpy import arange, array
        b = arange(5)
        b[array([True, False, True])] = [20, 21, 0, 0, 0, 0, 0]
        assert (b == [20, 1, 21, 3, 4]).all()
        raises(IndexError, "array([1, 2])[array([True, False, True])] = [1, 2, 3]")

    def test_weakref(self):
        import _weakref
        from numpy import array
        a = array([1, 2, 3])
        assert _weakref.ref(a)
        a = array(42)
        assert _weakref.ref(a)

    def test_astype(self):
        from numpy import array, arange, empty
        b = array(1).astype(float)
        assert b == 1
        assert b.dtype == float
        b = array([1, 2]).astype(float)
        assert (b == [1, 2]).all()
        assert b.dtype == 'float'
        b = array([1, 2], dtype=complex).astype(int)
        assert (b == [1, 2]).all()
        assert b.dtype == 'int'
        b = array([0, 1, 2], dtype=complex).astype(bool)
        assert (b == [False, True, True]).all()
        assert b.dtype == 'bool'

        a = arange(11)[::-1]
        b = a.astype('int32')
        assert (b == a).all()

        a = arange(6, dtype='f4').reshape(2,3)
        b = a.T.astype('i4')
        assert (a.T.strides == b.strides)

        a = array('x').astype('S3').dtype
        assert a.itemsize == 3
        # scalar vs. array
        a = array([1, 2, 3.14156]).astype('S3').dtype
        assert a.itemsize == 3
        a = array(3.1415).astype('S3').dtype
        assert a.itemsize == 3

        a = array(['1', '2','3']).astype(float)
        assert a[2] == 3.0

        a = array('123')
        assert a.astype('S0').dtype == 'S3'
        assert a.astype('i8') == 123
        a = array('abcdefgh')
        exc = raises(ValueError, a.astype, 'i8')
        assert exc.value.message.startswith('invalid literal for int()')

        a = arange(5, dtype=complex)
        b = a.real
        c = b.astype("int64")
        assert c.shape == b.shape
        assert c.strides == (8,)

        exc = raises(TypeError, a.astype, 'i8', casting='safe')
        assert exc.value.message.startswith(
                "Cannot cast array from dtype('complex128') to dtype('int64')")
        a = arange(6, dtype='f4').reshape(2, 3)
        b = a.astype('f4', copy=False)
        assert a is b
        b = a.astype('f4', order='C', copy=False)
        assert a is b

        a = empty([3, 3, 3, 3], 'uint8')
        a[:] = 0
        b = a[2]
        c = b[:, :2, :]
        d = c.swapaxes(1, -1)
        e = d.astype('complex128')
        assert e.shape == (3, 3, 2)
        assert e.strides == (96, 16, 48)
        assert (e.real == d).all()

    def test_base(self):
        from numpy import array, empty
        assert array(1).base is None
        assert array([1, 2]).base is None
        a = array([1, 2, 3, 4])
        b = a[::2]
        assert b.base is a

        a = empty([3, 3, 3, 3], 'uint8')
        a[:] = 0
        b = a[2]
        assert b.base.base is None
        c = b[:, :2, :]
        d = c.swapaxes(1, -1)
        assert c.base.base is None
        assert d.base.base is None
        assert d.shape == (3, 3, 2)
        assert d.__array_interface__['data'][0] == \
               a.__array_interface__['data'][0] + a.strides[0] * 2

    def test_byteswap(self):
        from numpy import array

        s1 = array(1.).byteswap().tostring()
        s2 = array([1.]).byteswap().tostring()
        assert s1 == s2

        a = array([1, 256 + 2, 3], dtype='i2')
        assert (a.byteswap() == [0x0100, 0x0201, 0x0300]).all()
        assert (a == [1, 256 + 2, 3]).all()
        assert (a.byteswap(True) == [0x0100, 0x0201, 0x0300]).all()
        assert (a == [0x0100, 0x0201, 0x0300]).all()

        a = array([1, -1, 1e300], dtype=float)
        s1 = map(ord, a.tostring())
        s2 = map(ord, a.byteswap().tostring())
        assert a.dtype.itemsize == 8
        for i in range(a.size):
            i1 = i * a.dtype.itemsize
            i2 = (i+1) * a.dtype.itemsize
            assert list(reversed(s1[i1:i2])) == s2[i1:i2]

        a = array([1+1e30j, -1, 1e10], dtype=complex)
        s1 = map(ord, a.tostring())
        s2 = map(ord, a.byteswap().tostring())
        assert a.dtype.itemsize == 16
        for i in range(a.size*2):
            i1 = i * a.dtype.itemsize/2
            i2 = (i+1) * a.dtype.itemsize/2
            assert list(reversed(s1[i1:i2])) == s2[i1:i2]

        a = array([3.14, -1.5, 10000], dtype='float16')
        s1 = map(ord, a.tostring())
        s2 = map(ord, a.byteswap().tostring())
        assert a.dtype.itemsize == 2
        for i in range(a.size):
            i1 = i * a.dtype.itemsize
            i2 = (i+1) * a.dtype.itemsize
            assert list(reversed(s1[i1:i2])) == s2[i1:i2]

        a = array([1, -1, 10000], dtype='longfloat')
        s1 = map(ord, a.tostring())
        s2 = map(ord, a.byteswap().tostring())
        assert a.dtype.itemsize >= 8
        for i in range(a.size):
            i1 = i * a.dtype.itemsize
            i2 = (i+1) * a.dtype.itemsize
            assert list(reversed(s1[i1:i2])) == s2[i1:i2]

    def test_clip(self):
        from numpy import array
        a = array([1, 2, 17, -3, 12])
        exc = raises(ValueError, a.clip)
        assert str(exc.value) == "One of max or min must be given."
        assert (a.clip(-2, 13) == [1, 2, 13, -2, 12]).all()
        assert (a.clip(min=-2) == [1, 2, 17, -2, 12]).all()
        assert (a.clip(min=-2, max=None) == [1, 2, 17, -2, 12]).all()
        assert (a.clip(max=13) == [1, 2, 13, -3, 12]).all()
        assert (a.clip(min=None, max=13) == [1, 2, 13, -3, 12]).all()
        assert (a.clip(-1, 1, out=None) == [1, 1, 1, -1, 1]).all()
        assert (a == [1, 2, 17, -3, 12]).all()
        assert (a.clip(-1, [1, 2, 3, 4, 5]) == [1, 2, 3, -1, 5]).all()
        assert (a.clip(-2, 13, out=a) == [1, 2, 13, -2, 12]).all()
        assert (a == [1, 2, 13, -2, 12]).all()

    def test_data(self):
        from numpy import array
        import sys
        a = array([1, 2, 3, 4], dtype='i4')
        assert a.data[0] == ('\x01' if sys.byteorder == 'little' else '\x00')
        assert a.data[1] == '\x00'
        assert a.data[3] == ('\x00' if sys.byteorder == 'little' else '\x01')
        assert a.data[4] == ('\x02' if sys.byteorder == 'little' else '\x00')
        a.data[4] = '\x7f'
        if sys.byteorder == 'big':
            a.data[7] = '\x00' # make sure 0x02 is reset to 0
            assert a[1] == (0x7f000000)
        else:
            assert a[1] == 0x7f
        assert len(a.data) == 16
        assert type(a.data) is buffer
        if '__pypy__' in sys.builtin_module_names:
            assert a[1:].data._pypy_raw_address() - a.data._pypy_raw_address() == a.strides[0]

    def test_explicit_dtype_conversion(self):
        from numpy import array
        a = array([1.0, 2.0])
        b = array(a, dtype='d')
        assert a.dtype is b.dtype

    def test_notequal_different_shapes(self):
        from numpy import array
        a = array([1, 2])
        b = array([1, 2, 3, 4])
        assert (a == b) == False

    def test__int__(self):
        from numpy import array
        assert int(array(1)) == 1
        assert int(array([1])) == 1
        assert raises(TypeError, "int(array([1, 2]))")
        assert int(array([1.5])) == 1
        for op in ["int", "float", "long"]:
            for a in [array('123'), array(['123'])]:
                exc = raises(TypeError, "%s(a)" % op)
                assert exc.value.message == "don't know how to convert " \
                                            "scalar number to %s" % op

    def test__float__(self):
        import numpy as np
        assert float(np.array(1.5)) == 1.5
        exc = raises(TypeError, "float(np.array([1.5, 2.5]))")
        assert exc.value[0] == 'only length-1 arrays can be converted to Python scalars'

    def test__hex__(self):
        import numpy as np
        assert hex(np.array(True)) == '0x1'
        assert hex(np.array(15)) == '0xf'
        assert hex(np.array([15])) == '0xf'
        exc = raises(TypeError, "hex(np.array(1.5))")
        assert str(exc.value) == "don't know how to convert scalar number to hex"
        exc = raises(TypeError, "hex(np.array('15'))")
        assert str(exc.value) == "don't know how to convert scalar number to hex"
        exc = raises(TypeError, "hex(np.array([1, 2]))")
        assert str(exc.value) == "only length-1 arrays can be converted to Python scalars"

    def test__oct__(self):
        import numpy as np
        assert oct(np.array(True)) == '01'
        assert oct(np.array(15)) == '017'
        assert oct(np.array([15])) == '017'
        exc = raises(TypeError, "oct(np.array(1.5))")
        assert str(exc.value) == "don't know how to convert scalar number to oct"
        exc = raises(TypeError, "oct(np.array('15'))")
        assert str(exc.value) == "don't know how to convert scalar number to oct"
        exc = raises(TypeError, "oct(np.array([1, 2]))")
        assert str(exc.value) == "only length-1 arrays can be converted to Python scalars"

    def test__reduce__(self):
        from numpy import array, dtype
        from cPickle import loads, dumps
        import sys

        a = array([1, 2], dtype="int64")
        data = a.__reduce__()

        if sys.byteorder == 'big':
            assert data[2][4] == '\x00\x00\x00\x00\x00\x00\x00\x01' \
                                 '\x00\x00\x00\x00\x00\x00\x00\x02'
        else:
            assert data[2][4] == '\x01\x00\x00\x00\x00\x00\x00\x00' \
                                 '\x02\x00\x00\x00\x00\x00\x00\x00'

        pickled_data = dumps(a)
        assert (loads(pickled_data) == a).all()

    def test_pickle_slice(self):
        from cPickle import loads, dumps
        import numpy

        a = numpy.arange(10.).reshape((5, 2))[::2]
        assert (loads(dumps(a)) == a).all()

    def test_string_filling(self):
        import numpy
        a = numpy.empty((10,10), dtype='S1')
        a.fill(12)
        assert (a == '1').all()

    def test_unicode_filling(self):
        import numpy as np
        a = np.empty((10,10), dtype='U1')
        a.fill(12)
        assert (a == u'1').all()

    def test_unicode_record_array(self) :
        from numpy import dtype, array
        t = dtype([('a', 'S3'), ('b', 'U2')])
        x = array([('a', u'b')], dtype=t)
        assert str(x) ==  "[('a', u'b')]"

        t = dtype([('a', 'U3'), ('b', 'S2')])
        x = array([(u'a', 'b')], dtype=t)
        x['a'] = u'1'
        assert str(x) ==  "[(u'1', 'b')]"


    def test_boolean_indexing(self):
        import numpy as np
        a = np.zeros((1, 3))
        b = np.array([True])

        assert (a[b] == a).all()
        a[b] = 1.
        assert (a == [[1., 1., 1.]]).all()
        a[b] = np.array(2.)
        assert (a == [[2., 2., 2.]]).all()
        a[b] = np.array([3.])
        assert (a == [[3., 3., 3.]]).all()
        a[b] = np.array([[4.]])
        assert (a == [[4., 4., 4.]]).all()

    def test_indexing_by_boolean(self):
        import numpy as np
        a = np.arange(6).reshape(2,3)
        assert (a[[True, False], :] == [[3, 4, 5], [0, 1, 2]]).all()
        b = a[np.array([True, False]), :]
        assert (b == [[0, 1, 2]]).all()
        assert b.base is None
        b = a[:, np.array([True, False, True])]
        assert b.base is not None
        a[np.array([True, False]), 0] = 100
        b = a[np.array([True, False]), 0]
        assert b.shape == (1,)
        assert (b ==[100]).all()

    def test_scalar_indexing(self):
        import numpy as np
        a = np.arange(6).reshape(2,3)
        i = np.dtype('int32').type(0)
        assert (a[0] == a[i]).all()


    def test_ellipsis_indexing(self):
        import numpy as np
        import sys
        a = np.array(1.5)
        assert a[...].base is a
        a[...] = 2.5
        assert a == 2.5
        a = np.array([1, 2, 3])
        assert a[...].base is a
        a[...] = 4
        assert (a == [4, 4, 4]).all()
        assert a[..., 0] == 4

        b = np.arange(24).reshape(2,3,4)
        b[...] = 100
        assert (b == 100).all()
        assert b.shape == (2, 3, 4)
        b[...] = [10, 20, 30, 40]
        assert (b[:,:,0] == 10).all()
        assert (b[0,0,:] == [10, 20, 30, 40]).all()
        assert b.shape == b[...].shape
        assert (b == b[...]).all()

        a = np.arange(6)
        if '__pypy__' in sys.builtin_module_names:
            raises(ValueError, "a[..., ...]")
        b = a.reshape(2, 3)[..., 0]
        assert (b == [0, 3]).all()
        assert b.base is a

    def test_empty_indexing(self):
        import numpy as np
        r = np.ones(3)
        ind = np.array([], np.int32)
        tmp = np.array([], np.float64)
        assert r[ind].shape == (0,)
        r[ind] = 0
        assert (r == np.ones(3)).all()
        r[ind] = tmp
        assert (r == np.ones(3)).all()
        r[[]] = 0
        assert (r == np.ones(3)).all()


class AppTestNumArrayFromBuffer(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "array", "mmap"])

    def setup_class(cls):
        from rpython.tool.udir import udir
        BaseNumpyAppTest.setup_class.im_func(cls)
        cls.w_tmpname = cls.space.wrap(str(udir.join('mmap-')))

    def test_ndarray_from_buffer(self):
        import numpy as np
        import array
        import sys
        buf = array.array('c', ['\x00']*2*3)
        a = np.ndarray((3,), buffer=buf, dtype='i2')
        a[0] = ord('b')
        a[1] = ord('a')
        a[2] = ord('r')
        if sys.byteorder == 'big':
            assert list(buf) == ['\x00', 'b', '\x00', 'a', '\x00', 'r']
        else:
            assert list(buf) == ['b', '\x00', 'a', '\x00', 'r', '\x00']
        assert a.base is buf

    def test_ndarray_subclass_from_buffer(self):
        import numpy as np
        import array
        buf = array.array('c', ['\x00']*2*3)
        class X(np.ndarray):
            pass
        a = X((3,), buffer=buf, dtype='i2')
        assert type(a) is X

    def test_ndarray_from_buffer_and_offset(self):
        import numpy as np
        import array
        import sys
        buf = array.array('c', ['\x00']*7)
        buf[0] = 'X'
        a = np.ndarray((3,), buffer=buf, offset=1, dtype='i2')
        a[0] = ord('b')
        a[1] = ord('a')
        a[2] = ord('r')
        if sys.byteorder == 'big':
            assert list(buf) == ['X', '\x00', 'b', '\x00', 'a', '\x00', 'r']
        else:
            assert list(buf) == ['X', 'b', '\x00', 'a', '\x00', 'r', '\x00']

    def test_ndarray_from_buffer_out_of_bounds(self):
        import numpy as np
        import array
        buf = array.array('c', ['\x00']*2*10) # 20 bytes
        info = raises(TypeError, "np.ndarray((11,), buffer=buf, dtype='i2')")
        assert str(info.value).startswith('buffer is too small')
        info = raises(TypeError, "np.ndarray((5,), buffer=buf, offset=15, dtype='i2')")
        assert str(info.value).startswith('buffer is too small')

    def test_ndarray_from_readonly_buffer(self):
        import numpy as np
        from mmap import mmap, ACCESS_READ
        f = open(self.tmpname, "w+")
        f.write("hello")
        f.flush()
        buf = mmap(f.fileno(), 5, access=ACCESS_READ)
        a = np.ndarray((5,), buffer=buf, dtype='c')
        raises(ValueError, "a[0] = 'X'")
        buf.close()
        f.close()


class AppTestMultiDim(BaseNumpyAppTest):
    def test_init(self):
        import numpy
        a = numpy.zeros((2, 2))
        assert len(a) == 2

    def test_shape(self):
        import numpy
        assert numpy.zeros(1).shape == (1,)
        assert numpy.zeros((2, 2)).shape == (2, 2)
        assert numpy.zeros((3, 1, 2)).shape == (3, 1, 2)
        assert numpy.array([[1], [2], [3]]).shape == (3, 1)
        assert len(numpy.zeros((3, 1, 2))) == 3
        raises(TypeError, len, numpy.zeros(()))
        raises(ValueError, numpy.array, [[1, 2], 3], dtype=float)

    def test_getsetitem(self):
        import numpy
        a = numpy.zeros((2, 3, 1))
        raises(IndexError, a.__getitem__, (2, 0, 0))
        raises(IndexError, a.__getitem__, (0, 3, 0))
        raises(IndexError, a.__getitem__, (0, 0, 1))
        assert a[1, 1, 0] == 0
        a[1, 2, 0] = 3
        assert a[1, 2, 0] == 3
        assert a[1, 1, 0] == 0
        assert a[1, -1, 0] == 3

    def test_slices(self):
        import numpy
        a = numpy.zeros((4, 3, 2))
        raises(IndexError, a.__getitem__, (4,))
        raises(IndexError, a.__getitem__, (3, 3))
        raises(IndexError, a.__getitem__, (slice(None), 3))
        a[0, 1, 1] = 13
        a[1, 2, 1] = 15
        b = a[0]
        assert len(b) == 3
        assert b.shape == (3, 2)
        assert b[1, 1] == 13
        b = a[1]
        assert b.shape == (3, 2)
        assert b[2, 1] == 15
        b = a[:, 1]
        assert b.shape == (4, 2)
        assert b[0, 1] == 13
        b = a[:, 1, :]
        assert b.shape == (4, 2)
        assert b[0, 1] == 13
        b = a[1, 2]
        assert b[1] == 15
        b = a[:]
        assert b.shape == (4, 3, 2)
        assert b[1, 2, 1] == 15
        assert b[0, 1, 1] == 13
        b = a[:][:, 1][:]
        assert b[2, 1] == 0.0
        assert b[0, 1] == 13
        raises(IndexError, b.__getitem__, (4, 1))
        assert a[0][1][1] == 13
        assert a[1][2][1] == 15

    def test_create_order(self):
        import numpy as np
        for order in [False, True, 'C', 'F']:
            a = np.empty((2, 3), float, order=order)
            assert a.shape == (2, 3)
            if order in [True, 'F']:
                assert a.flags['F']
                assert not a.flags['C']
            else:
                assert a.flags['C'], "flags['C'] False for %r" % order
                assert not a.flags['F']

    def test_setitem_slice(self):
        import numpy
        a = numpy.zeros((3, 4))
        a[1] = [1, 2, 3, 4]
        assert a[1, 2] == 3
        raises(TypeError, a[1].__setitem__, [1, 2, 3])
        a = numpy.array([[1, 2], [3, 4]])
        assert (a == [[1, 2], [3, 4]]).all()
        a[1] = numpy.array([5, 6])
        assert (a == [[1, 2], [5, 6]]).all()
        a[:, 1] = numpy.array([8, 10])
        assert (a == [[1, 8], [5, 10]]).all()
        a[0, :: -1] = numpy.array([11, 12])
        assert (a == [[12, 11], [5, 10]]).all()

        a = numpy.zeros((3, 2), int)
        b = numpy.ones((3, 1), int)
        exc = raises(ValueError, 'a[:, 1] = b')
        assert str(exc.value) == "could not broadcast " +\
                "input array from shape (3,1) into shape (3)"
        a[:, 1] = b[:,0] > 0.5
        assert (a == [[0, 1], [0, 1], [0, 1]]).all()


    def test_ufunc(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6]])
        assert ((a + a) == \
            array([[1 + 1, 2 + 2], [3 + 3, 4 + 4], [5 + 5, 6 + 6]])).all()

    def test_getitem_add(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]])
        assert (a + a)[1, 1] == 8

    def test_getitem_3(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6], [7, 8],
                   [9, 10], [11, 12], [13, 14]])
        b = a[::2]
        assert (b == [[1, 2], [5, 6], [9, 10], [13, 14]]).all()
        c = b + b
        assert c[1][1] == 12

    def test_multidim_ones(self):
        from numpy import ones
        a = ones((1, 2, 3))
        assert a[0, 1, 2] == 1.0

    def test_multidim_setslice(self):
        from numpy import zeros, ones
        a = zeros((3, 3))
        b = ones((3, 3))
        a[:, 1:3] = b[:, 1:3]
        assert (a == [[0, 1, 1], [0, 1, 1], [0, 1, 1]]).all()
        a = zeros((3, 3))
        b = ones((3, 3))
        a[:, ::2] = b[:, ::2]
        assert (a == [[1, 0, 1], [1, 0, 1], [1, 0, 1]]).all()

    def test_broadcast_ufunc(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6]])
        b = array([5, 6])
        c = ((a + b) == [[1 + 5, 2 + 6], [3 + 5, 4 + 6], [5 + 5, 6 + 6]])
        assert c.all()

    def test_broadcast_setslice(self):
        from numpy import zeros, ones
        a = zeros((10, 10))
        b = ones(10)
        a[:, :] = b
        assert a[3, 5] == 1

    def test_broadcast_shape_agreement(self):
        from numpy import zeros, array
        a = zeros((3, 1, 3))
        b = array(((10, 11, 12), (20, 21, 22), (30, 31, 32)))
        c = ((a + b) == [b, b, b])
        assert c.all()
        a = array((((10, 11, 12), ), ((20, 21, 22), ), ((30, 31, 32), )))
        assert(a.shape == (3, 1, 3))
        d = zeros((3, 3))
        c = ((a + d) == [b, b, b])
        c = ((a + d) == array([[[10., 11., 12.]] * 3,
                               [[20., 21., 22.]] * 3, [[30., 31., 32.]] * 3]))
        assert c.all()

    def test_broadcast_scalar(self):
        from numpy import zeros
        a = zeros((4, 5), 'd')
        a[:, 1] = 3
        assert a[2, 1] == 3
        assert a[0, 2] == 0
        a[0, :] = 5
        assert a[0, 3] == 5
        assert a[2, 1] == 3
        assert a[3, 2] == 0

    def test_broadcast_call2(self):
        from numpy import zeros, ones
        a = zeros((4, 1, 5))
        b = ones((4, 3, 5))
        b[:] = (a + a)
        assert (b == zeros((4, 3, 5))).all()

    def test_broadcast_virtualview(self):
        from numpy import arange, zeros
        a = arange(8).reshape([2, 2, 2])
        b = (a + a)[1, 1]
        c = zeros((2, 2, 2))
        c[:] = b
        assert (c == [[[12, 14], [12, 14]], [[12, 14], [12, 14]]]).all()

    def test_broadcast_wrong_shapes(self):
        from numpy import zeros
        a = zeros((4, 3, 2))
        b = zeros((4, 2))
        exc = raises(ValueError, lambda: a + b)
        assert str(exc.value).startswith("operands could not be broadcast")

    def test_reduce(self):
        from numpy import array
        a = array([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
        assert a.sum() == (13 * 12) / 2
        b = a[1:, 1::2]
        c = b + b
        assert c.sum() == (6 + 8 + 10 + 12) * 2
        assert isinstance(c.sum(dtype='f8'), float)
        assert isinstance(c.sum(None, 'f8'), float)

    def test_transpose(self):
        from numpy import array
        a = array(((range(3), range(3, 6)),
                   (range(6, 9), range(9, 12)),
                   (range(12, 15), range(15, 18)),
                   (range(18, 21), range(21, 24))))
        assert a.shape == (4, 2, 3)
        b = a.T
        assert b.shape == (3, 2, 4)
        assert(b[0, :, 0] == [0, 3]).all()

        c = a.transpose((1, 0, 2))
        assert c.shape == (2, 4, 3)
        assert (c.transpose(1, 0, 2) == a).all()

        b[:, 0, 0] = 1000
        assert(a[0, 0, :] == [1000, 1000, 1000]).all()
        a = array(range(5))
        b = a.T
        assert(b == range(5)).all()
        a = array((range(10), range(20, 30)))
        b = a.T
        assert(b[:, 0] == a[0, :]).all()
        assert (a.transpose() == b).all()
        assert (a.transpose(None) == b).all()

    def test_transpose_arg_tuple(self):
        import numpy as np
        a = np.arange(24).reshape(2, 3, 4)
        transpose_args = a.transpose(1, 2, 0)

        transpose_test = a.transpose((1, 2, 0))

        assert transpose_test.shape == (3, 4, 2)
        assert (transpose_args == transpose_test).all()

    def test_transpose_arg_list(self):
        import numpy as np
        a = np.arange(24).reshape(2, 3, 4)
        transpose_args = a.transpose(1, 2, 0)

        transpose_test = a.transpose([1, 2, 0])

        assert transpose_test.shape == (3, 4, 2)
        assert (transpose_args == transpose_test).all()

    def test_transpose_arg_array(self):
        import numpy as np
        a = np.arange(24).reshape(2, 3, 4)
        transpose_args = a.transpose(1, 2, 0)

        transpose_test = a.transpose(np.array([1, 2, 0]))

        assert transpose_test.shape == (3, 4, 2)
        assert (transpose_args == transpose_test).all()

    def test_transpose_error(self):
        import numpy as np
        a = np.arange(24).reshape(2, 3, 4)
        raises(ValueError, a.transpose, 2, 1)
        raises(ValueError, a.transpose, 1, 0, 3)
        raises(ValueError, a.transpose, 1, 0, 1)
        raises(TypeError, a.transpose, 1, 0, '2')

    def test_transpose_unexpected_argument(self):
        import numpy as np
        a = np.array([[1, 2], [3, 4], [5, 6]])
        raises(TypeError, 'a.transpose(axes=(1,2,0))')

    def test_flatiter(self):
        from numpy import array, flatiter, arange, zeros
        a = array([[10, 30], [40, 60]])
        f_iter = a.flat
        assert f_iter.next() == 10
        assert f_iter.next() == 30
        assert f_iter.next() == 40
        assert f_iter.next() == 60
        raises(StopIteration, "f_iter.next()")
        raises(TypeError, "flatiter()")
        s = 0
        for k in a.flat:
            s += k
        assert s == 140
        a = arange(10).reshape(5, 2)
        raises(IndexError, 'a.flat[(1, 2)]')
        assert a.flat.base is a
        m = zeros((2,2), dtype='S3')
        m.flat[1] = 1
        assert m[0,1] == '1'

    def test_flatiter_array_conv(self):
        from numpy import array, dot
        a = array([1, 2, 3])
        assert dot(a.flat, a.flat) == 14

    def test_flatiter_varray(self):
        from numpy import ones
        a = ones((2, 2))
        assert list(((a + a).flat)) == [2, 2, 2, 2]

    def test_flatiter_getitem(self):
        from numpy import arange
        a = arange(10)
        assert a.flat[3] == 3
        assert a[2:].flat[3] == 5
        assert (a + a).flat[3] == 6
        assert a[::2].flat[3] == 6
        assert a.reshape(2,5).flat[3] == 3
        b = a.reshape(2,5).flat
        b.next()
        b.next()
        b.next()
        assert b.index == 3
        assert b.coords == (0, 3)
        b.next()
        assert b[3] == 3
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        assert (b[::3] == [0, 3, 6, 9]).all()
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        assert (b[2::5] == [2, 7]).all()
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        assert b[-2] == 8
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        raises(IndexError, "b[11]")
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        raises(IndexError, "b[-11]")
        assert b.index == 0
        assert b.coords == (0, 0)
        b.next()
        exc = raises(IndexError, 'b[0, 1]')
        assert str(exc.value) == "unsupported iterator index"
        assert b.index == 1
        assert b.coords == (0, 1)

    def test_flatiter_setitem(self):
        from numpy import arange, array
        a = arange(12).reshape(3,4)
        b = a.T.flat
        b[6::2] = [-1, -2]
        assert (a == [[0, 1, -1, 3], [4, 5, 6, -1], [8, 9, -2, 11]]).all()
        assert b[2] == 8
        assert b.index == 0
        b.next()
        b[6::2] = [-21, -42]
        assert (a == [[0, 1, -21, 3], [4, 5, 6, -21], [8, 9, -42, 11]]).all()
        b[0:2] = [[[100]]]
        assert(a[0,0] == 100)
        assert(a[1,0] == 100)
        b.next()
        assert b.index == 1
        exc = raises(ValueError, "b[0] = [1, 2]")
        assert str(exc.value) == "Error setting single item of array."
        assert b.index == 0
        b.next()
        raises(IndexError, "b[100] = 42")
        assert b.index == 1
        exc = raises(IndexError, "b[0, 1] = 42")
        assert str(exc.value) == "unsupported iterator index"
        assert b.index == 1
        a = array([(False, False, False),
                   (False, False, False),
                   (False, False, False),
                  ],
                   dtype=[('a', '|b1'), ('b', '|b1'), ('c', '|b1')])
        a.flat = [(True, True, True),
                  (True, True, True),
                  (True, True, True)]
        assert (a.view(bool) == True).all()

    def test_flatiter_ops(self):
        from numpy import arange, array
        a = arange(12).reshape(3,4)
        b = a.T.flat
        assert (b == [0,  4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11]).all()
        assert not (b != [0,  4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11]).any()
        assert ((b >= range(12)) == [True, True, True,False, True, True,
                             False, False, True, False, False, True]).all()
        assert ((b < range(12)) != [True, True, True,False, True, True,
                             False, False, True, False, False, True]).all()
        assert ((b <= range(12)) != [False, True, True,False, True, True,
                            False, False, True, False, False, False]).all()
        assert ((b > range(12)) == [False, True, True,False, True, True,
                            False, False, True, False, False, False]).all()

    def test_flatiter_view(self):
        from numpy import arange
        a = arange(10).reshape(5, 2)
        assert (a[::2].flat == [0, 1, 4, 5, 8, 9]).all()

    def test_flatiter_transpose(self):
        from numpy import arange
        a = arange(10).reshape(2, 5).T
        b = a.flat
        assert (b[:5] == [0, 5, 1, 6, 2]).all()
        b.next()
        b.next()
        b.next()
        assert b.index == 3
        assert b.coords == (1, 1)

    def test_flatiter_len(self):
        from numpy import arange

        assert len(arange(10).flat) == 10
        assert len(arange(10).reshape(2, 5).flat) == 10
        assert len(arange(10)[:2].flat) == 2
        assert len((arange(2) + arange(2)).flat) == 2

    def test_flatiter_setter(self):
        from numpy import arange, array
        a = arange(24).reshape(2, 3, 4)
        a.flat = [4, 5]
        assert (a.flatten() == [4, 5]*12).all()
        a.flat = [[4, 5, 6, 7, 8], [4, 5, 6, 7, 8]]
        assert (a.flatten() == ([4, 5, 6, 7, 8]*5)[:24]).all()
        exc = raises(ValueError, 'a.flat = [[4, 5, 6, 7, 8], [4, 5, 6]]')
        assert str(exc.value).find("sequence") > 0
        b = a[::-1, :, ::-1]
        b.flat = range(24)
        assert (a.flatten() == [15, 14 ,13, 12, 19, 18, 17, 16, 23, 22,
                                21, 20, 3, 2, 1, 0, 7, 6, 5, 4,
                                11, 10, 9, 8]).all()
        c = array(['abc'] * 10).reshape(2, 5)
        c.flat = ['defgh', 'ijklmnop']
        assert (c.flatten() == ['def', 'ijk']*5).all()

    def test_flatiter_subtype(self):
        from numpy import array
        x = array([[1, 2], [3, 4]]).T
        y = array(x.flat)
        assert (x == [[1, 3], [2, 4]]).all()


    def test_slice_copy(self):
        from numpy import zeros
        a = zeros((10, 10))
        b = a[0].copy()
        assert (b == zeros(10)).all()

    def test_array_interface(self):
        from numpy import array
        import numpy as np
        a = array(2.5)
        i = a.__array_interface__
        assert isinstance(i['data'][0], int)
        assert i['shape'] == ()
        assert i['strides'] is None
        a = array([1, 2, 3])
        i = a.__array_interface__
        assert isinstance(i['data'][0], int)
        assert i['shape'] == (3,)
        assert i['strides'] == None  # Because array is in C order
        assert i['typestr'] == a.dtype.str
        a = a[::2]
        i = a.__array_interface__
        assert isinstance(i['data'][0], int)
        b = array(range(9), dtype=int)
        c = b[3:5]
        b_data = b.__array_interface__['data'][0]
        c_data = c.__array_interface__['data'][0]
        assert b_data + 3 * b.dtype.itemsize == c_data

        class Dummy(object):
            def __init__(self, aif=None, base=None):
                if aif is not None:
                    self.__array_interface__ = aif
                self.base = base

        a = array(Dummy())
        assert a.dtype == object
        raises(ValueError, array, Dummy({'xxx': 0}))
        raises(ValueError, array, Dummy({'version': 0}))
        raises(ValueError, array, Dummy({'version': 'abc'}))
        raises(ValueError, array, Dummy({'version': 3}))
        raises(TypeError, array, Dummy({'version': 3, 'typestr': 'f8', 'shape': ('a', 3)}))

        a = array([1, 2, 3])
        d = Dummy(a.__array_interface__)
        b = array(d)
        assert b.base is None
        b[1] = 200
        assert a[1] == 2 # upstream compatibility, is this a bug?
        interface_a = a.__array_interface__
        interface_b = b.__array_interface__
        # only the data[0] value should differ
        assert interface_a['data'][0] != interface_b['data'][0]
        assert interface_b['data'][1] == interface_a['data'][1]
        interface_b.pop('data')
        interface_a.pop('data')
        assert interface_a == interface_b
        b = array(d, copy=False)
        assert b.base is d

        b = array(Dummy({'version':3, 'shape': (50,), 'typestr': 'u1',
                         'data': 'a'*100}))
        assert b.dtype == 'uint8'
        assert b.shape == (50,)

        a = np.ones((1,), dtype='float16')
        b = Dummy(a.__array_interface__)
        c = array(b)
        assert c.dtype == 'float16'
        assert (a == c).all()

        t = np.dtype([("a", np.float64), ("b", np.float64)], align=True)
        a = np.zeros(10, dtype=t)
        a['a'] = range(10, 20)
        a['b'] = range(20, 30)
        interface = dict(a.__array_interface__)
        array = np.array(Dummy(interface))
        assert array.dtype.kind == 'V'
        array.dtype = a.dtype
        assert array[5]['b'] == 25

    def test_array_indexing_one_elem(self):
        from numpy import array, arange
        raises(IndexError, 'arange(3)[array([3.5])]')
        a = arange(3)[array([1])]
        assert a == 1
        assert a[0] == 1
        raises(IndexError,'arange(3)[array([15])]')
        assert arange(3)[array([-3])] == 0
        raises(IndexError,'arange(3)[array([-15])]')
        assert arange(3)[array(1)] == 1

    def test_fill(self):
        from numpy import array, empty, dtype, zeros
        a = array([1, 2, 3])
        a.fill(10)
        assert (a == [10, 10, 10]).all()
        a.fill(False)
        assert (a == [0, 0, 0]).all()
        b = a[:1]
        b.fill(4)
        assert (b == [4]).all()
        assert (a == [4, 0, 0]).all()

        c = b + b
        c.fill(27)
        assert (c == [27]).all()

        d = array(10)
        d.fill(100)
        assert d == 100

        e = array(10, dtype=complex)
        e.fill(1.5-3j)
        assert e == 1.5-3j

        a = empty(5, dtype='S3')
        a.fill('abc')
        for i in a:
            assert i == 'abc'

        a = empty(10, dtype=[(_, int) for _ in 'abcde'])
        a.fill(123)
        for i in a:
            assert tuple(i) == (123,) * 5

        a = zeros(3, dtype=dtype(complex).newbyteorder())
        a.fill(1.5+2.5j)
        for i in a:
            assert i == 1.5+2.5j

    def test_array_indexing_bool(self):
        from numpy import arange
        a = arange(10)
        assert (a[a > 3] == [4, 5, 6, 7, 8, 9]).all()
        a = arange(10).reshape(5, 2)
        assert (a[a > 3] == [4, 5, 6, 7, 8, 9]).all()
        assert (a[a & 1 == 1] == [1, 3, 5, 7, 9]).all()

    def test_array_indexing_bool_setitem(self):
        from numpy import arange, array
        a = arange(6)
        a[a > 3] = 15
        assert (a == [0, 1, 2, 3, 15, 15]).all()
        a = arange(6).reshape(3, 2)
        a[a & 1 == 1] = array([8, 9, 10])
        assert (a == [[0, 8], [2, 9], [4, 10]]).all()

    def test_array_indexing_bool_setitem_multidim(self):
        from numpy import arange
        a = arange(10).reshape(5, 2)
        a[a & 1 == 0] = 15
        assert (a == [[15, 1], [15, 3], [15, 5], [15, 7], [15, 9]]).all()

    def test_array_indexing_bool_setitem_2(self):
        from numpy import arange
        a = arange(10).reshape(5, 2)
        a = a[::2]
        a[a & 1 == 0] = 15
        assert (a == [[15, 1], [15, 5], [15, 9]]).all()

    def test_array_indexing_bool_specialcases(self):
        from numpy import arange, array
        a = arange(6)
        exc = raises(ValueError, 'a[a < 3] = [1, 2]')
        assert exc.value[0].find('cannot assign') >= 0
        b = arange(4).reshape(2, 2) + 10
        a[a < 4] = b
        assert (a == [10, 11, 12, 13, 4, 5]).all()
        b += 10
        c = arange(8).reshape(2, 2, 2)
        a[a > 9] = c[:, :, 1]
        assert (c[:, :, 1] == [[1, 3], [5, 7]]).all()
        assert (a == [1, 3, 5, 7, 4, 5]).all()
        a = arange(6)
        a[a > 3] = array([15])
        assert (a == [0, 1, 2, 3, 15, 15]).all()
        a = arange(6).reshape(3, 2)
        exc = raises(ValueError, 'a[a & 1 == 1] = []')
        assert exc.value[0].find('cannot assign') >= 0
        assert (a == [[0, 1], [2, 3], [4, 5]]).all()

    def test_copy_kwarg(self):
        from numpy import array
        x = array([1, 2, 3])
        assert (array(x) == x).all()
        assert array(x) is not x
        assert array(x, copy=False) is x
        assert array(x, copy=True) is not x

    def test_ravel(self):
        from numpy import arange
        assert (arange(3).ravel() == arange(3)).all()
        assert (arange(6).reshape(2, 3).ravel() == arange(6)).all()
        assert (arange(6).reshape(2, 3).T.ravel() == [0, 3, 1, 4, 2, 5]).all()
        assert (arange(3).ravel('K') == arange(3)).all()

    def test_nonzero(self):
        from numpy import array
        nz = array(0).nonzero()
        assert nz[0].size == 0

        nz = array(2).nonzero()
        assert (nz[0] == [0]).all()

        nz = array([1, 0, 3]).nonzero()
        assert (nz[0] == [0, 2]).all()

        nz = array([[1, 0, 3], [2, 0, 4]]).nonzero()
        assert (nz[0] == [0, 0, 1, 1]).all()
        assert (nz[1] == [0, 2, 0, 2]).all()

    def test_take(self):
        from numpy import arange
        assert (arange(10).take([1, 2, 1, 1]) == [1, 2, 1, 1]).all()
        raises(IndexError, "arange(3).take([15])")
        a = arange(6).reshape(2, 3)
        assert a.take(3) == 3
        assert a.take(3).shape == ()
        assert (a.take([1, 0, 3]) == [1, 0, 3]).all()
        assert (a.take([[1, 0], [2, 3]]) == [[1, 0], [2, 3]]).all()
        assert (a.take([1], axis=0) == [[3, 4, 5]]).all()
        assert (a.take([1], axis=1) == [[1], [4]]).all()
        assert ((a + a).take([3]) == [6]).all()
        a = arange(12).reshape(2, 6)
        assert (a[:,::2].take([3, 2, 1]) == [6, 4, 2]).all()
        import sys
        if '__pypy__' in sys.builtin_module_names:
            exc = raises(NotImplementedError, "a.take([3, 2, 1], mode='clip')")
            assert exc.value[0] == "mode != raise not implemented"

    def test_ptp(self):
        import numpy as np
        x = np.arange(4).reshape((2,2))
        assert x.ptp() == 3
        assert (x.ptp(axis=0) == [2, 2]).all()
        assert (x.ptp(axis=1) == [1, 1]).all()

    def test_compress(self):
        from numpy import arange, array
        a = arange(10)
        assert (a.compress([True, False, True]) == [0, 2]).all()
        assert (a.compress([1, 0, 13]) == [0, 2]).all()
        assert (a.compress([1, 0, 13]) == [0, 2]).all()
        assert (a.compress([1, 0, 13.5]) == [0, 2]).all()
        assert (a.compress(array([1, 0, 13.5], dtype='>f4')) == [0, 2]).all()
        assert (a.compress(array([1, 0, 13.5], dtype='<f4')) == [0, 2]).all()
        assert (a.compress([1, -0-0j, 1.3+13.5j]) == [0, 2]).all()
        a = arange(10).reshape(2, 5)
        assert (a.compress([True, False, True]) == [0, 2]).all()
        raises((IndexError, ValueError), "a.compress([1] * 100)")

    def test_item(self):
        import numpy as np
        from numpy import array
        assert array(3).item() == 3
        assert type(array(3).item()) is int
        assert type(array(True).item()) is bool
        assert type(array(3.5).item()) is float
        exc = raises(IndexError, "array(3).item(15)")
        assert str(exc.value) == 'index 15 is out of bounds for size 1'
        raises(ValueError, "array([1, 2, 3]).item()")
        assert array([3]).item(0) == 3
        assert type(array([3]).item(0)) is int
        assert array([1, 2, 3]).item(-1) == 3
        a = array([1, 2, 3])
        assert a[::2].item(1) == 3
        assert (a + a).item(1) == 4
        raises(IndexError, "array(5).item(1)")
        assert array([1]).item() == 1
        a = array('x')
        assert a.item() == 'x'
        a = array([(1, 'abc')], dtype=[('a', int), ('b', 'S2')])
        b = a.item(0)
        assert type(b) is tuple
        assert type(b[0]) is int
        assert type(b[1]) is str
        assert b[0] == 1
        assert b[1] == 'ab'
        a = np.arange(24).reshape(2, 4, 3)
        assert a.item(1, 1, 1) == 16
        assert a.item((1, 1, 1)) == 16
        exc = raises(ValueError, a.item, 1, 1, 1, 1)
        assert str(exc.value) == "incorrect number of indices for array"
        raises(TypeError, "array([1]).item(a=1)")

    def test_itemset(self):
        import numpy as np
        a = np.array(range(5))
        exc = raises(ValueError, a.itemset)
        assert exc.value[0] == 'itemset must have at least one argument'
        exc = raises(ValueError, a.itemset, 1, 2, 3)
        assert exc.value[0] == 'incorrect number of indices for array'
        a.itemset(1, 5)
        assert a[1] == 5
        a = np.array(range(6)).reshape(2, 3)
        a.itemset(1, 2, 100)
        assert a[1, 2] == 100

    def test_index_int(self):
        import numpy as np
        a = np.array([10, 20, 30], dtype='int64')
        res = a[np.int64(1)]
        assert isinstance(res, np.int64)
        assert res == 20
        res = a[np.int32(0)]
        assert isinstance(res, np.int64)
        assert res == 10

        b = a.astype(float)
        res = b[np.int64(1)]
        assert res == 20.0
        assert isinstance(res, np.float64)

    def test_index(self):
        import numpy as np
        a = np.array([1], np.uint16)
        i = a.__index__()
        assert type(i) is int
        assert i == 1
        for a in [np.array('abc'), np.array([1,2]), np.array([True])]:
            exc = raises(TypeError, a.__index__)
            assert exc.value.message == 'only integer arrays with one element ' \
                                        'can be converted to an index'


    def test_int_array_index(self):
        from numpy import array
        assert (array([])[[]] == []).all()
        a = array([[1, 2], [3, 4], [5, 6]])
        assert (a[slice(0, 3), [0, 0]] == [[1, 1], [3, 3], [5, 5]]).all()
        assert (a[array([0, 2]), slice(0, 2)] == [[1, 2], [5, 6]]).all()
        b = a[array([0, 0])]
        assert (b == [[1, 2], [1, 2]]).all()
        assert (a[[[0, 1], [0, 0]]] == array([1, 3])).all()
        assert (a[array([0, 2])] == [[1, 2], [5, 6]]).all()
        assert (a[array([0, 2]), 1] == [2, 6]).all()
        assert (a[array([0, 2]), array([1])] == [2, 6]).all()

    def test_int_array_index_setitem(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6]])
        a[slice(0, 3), [0, 0]] = [[0, 0], [0, 0], [0, 0]]
        assert (a == [[0, 2], [0, 4], [0, 6]]).all()
        a = array([[1, 2], [3, 4], [5, 6]])
        a[array([0, 2]), slice(0, 2)] = [[10, 11], [12, 13]]
        assert (a == [[10, 11], [3, 4], [12, 13]]).all()

    def test_slice_vector_index(self):
        from numpy import arange
        b = arange(145)
        a = b[slice(25, 125, None)]
        assert (a == range(25, 125)).all()
        a = b[[slice(25, 125, None)]]
        assert a.shape == (100,)
        # a is a view into b
        a[10] = 200
        assert b[35] == 200
        b[[slice(25, 30)]] = range(5)
        assert all(a[:5] == range(5))
        raises(IndexError, 'b[[[slice(25, 125)]]]')

    def test_cumsum(self):
        from numpy import arange
        a = arange(6).reshape(3, 2)
        b = arange(6)
        assert (a.cumsum() == [0, 1, 3, 6, 10, 15]).all()
        a.cumsum(out=b)
        assert (b == [0, 1, 3, 6, 10, 15]).all()
        raises(ValueError, "a.cumsum(out=arange(6).reshape(3, 2))")

    def test_cumprod(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6]])
        assert (a.cumprod() == [1, 2, 6, 24, 120, 720]).all()

    def test_cumsum_axis(self):
        from numpy import arange, array
        a = arange(6).reshape(3, 2)
        assert (a.cumsum(0) == [[0, 1], [2, 4], [6, 9]]).all()
        assert (a.cumsum(1) == [[0, 1], [2, 5], [4, 9]]).all()
        a = array([[1, 1], [2, 2], [3, 4]])
        assert (a.cumsum(1) == [[1, 2], [2, 4], [3, 7]]).all()
        assert (a.cumsum(0) == [[1, 1], [3, 3], [6, 7]]).all()

    def test_diagonal(self):
        from numpy import array
        a = array([[1, 2], [3, 4], [5, 6]])
        raises(ValueError, 'array([1, 2]).diagonal()')
        raises(ValueError, 'a.diagonal(0, 0, 0)')
        raises(ValueError, 'a.diagonal(0, 0, 13)')
        assert (a.diagonal() == [1, 4]).all()
        assert (a.diagonal(1) == [2]).all()

    def test_diagonal_axis(self):
        from numpy import arange
        a = arange(12).reshape(2, 3, 2)
        assert (a.diagonal(0, 0, 1) == [[0, 8], [1, 9]]).all()
        assert a.diagonal(3, 0, 1).shape == (2, 0)
        assert (a.diagonal(1, 0, 1) == [[2, 10], [3, 11]]).all()
        assert (a.diagonal(0, 2, 1) == [[0, 3], [6, 9]]).all()
        assert (a.diagonal(2, 2, 1) == [[4], [10]]).all()
        assert (a.diagonal(1, 2, 1) == [[2, 5], [8, 11]]).all()

    def test_diagonal_axis_neg_ofs(self):
        from numpy import arange
        a = arange(12).reshape(2, 3, 2)
        assert (a.diagonal(-1, 0, 1) == [[6], [7]]).all()
        assert a.diagonal(-2, 0, 1).shape == (2, 0)


class AppTestSupport(BaseNumpyAppTest):
    spaceconfig = {'usemodules': ['micronumpy', 'array']}

    def setup_class(cls):
        import struct
        BaseNumpyAppTest.setup_class.im_func(cls)
        cls.w_data = cls.space.wrap(struct.pack('dddd', 1, 2, 3, 4))
        cls.w_fdata = cls.space.wrap(struct.pack('f', 2.3))
        import sys
        if sys.byteorder == 'big':
            cls.w_float16val = cls.space.wrap('E\x00') # 5.0 in float16
        else:
            cls.w_float16val = cls.space.wrap('\x00E') # 5.0 in float16
        cls.w_float32val = cls.space.wrap(struct.pack('f', 5.2))
        cls.w_float64val = cls.space.wrap(struct.pack('d', 300.4))
        cls.w_ulongval = cls.space.wrap(struct.pack('L', 12))
        cls.w_one = cls.space.wrap(struct.pack('i', 1))

    def test_frombuffer(self):
        import numpy as np
        exc = raises(AttributeError, np.frombuffer, None)
        assert str(exc.value) == "'NoneType' object has no attribute '__buffer__'"
        exc = raises(ValueError, np.frombuffer, self.data, 'S0')
        assert str(exc.value) == "itemsize cannot be zero in type"
        exc = raises(ValueError, np.frombuffer, self.data, offset=-1)
        assert str(exc.value) == "offset must be non-negative and no greater than buffer length (32)"
        exc = raises(ValueError, np.frombuffer, self.data, count=100)
        assert str(exc.value) == "buffer is smaller than requested size"
        for data in [self.data, buffer(self.data)]:
            a = np.frombuffer(data)
            for i in range(4):
                assert a[i] == i + 1

        import array
        data = array.array('c', 'testing')
        a = np.frombuffer(data, 'c')
        assert a.base is data
        a[2] = 'Z'
        assert data.tostring() == 'teZting'

        data = buffer(data)
        a = np.frombuffer(data, 'c')
        assert a.base is data
        exc = raises(ValueError, "a[2] = 'Z'")
        assert str(exc.value) == "assignment destination is read-only"

        class A(object):
            def __buffer__(self, flags):
                return 'abc'

        data = A()
        a = np.frombuffer(data, 'c')
        #assert a.base is data.__buffer__
        assert a.tostring() == 'abc'

    def test_memoryview(self):
        import numpy as np
        import sys
        if sys.version_info[:2] > (3, 2):
            # In Python 3.3 the representation of empty shape, strides and sub-offsets
            # is an empty tuple instead of None.
            # http://docs.python.org/dev/whatsnew/3.3.html#api-changes
            EMPTY = ()
        else:
            EMPTY = None
        x = np.array([1, 2, 3, 4, 5], dtype='i')
        y = memoryview(x)
        assert y.format == 'i'
        assert y.shape == (5,)
        assert y.ndim == 1
        assert y.strides == (4,)
        assert y.suboffsets == EMPTY
        assert y.itemsize == 4
        assert isinstance(y, memoryview)
        assert y[0] == self.one
        assert (np.array(y) == x).all()

        x = np.array([0, 0, 0, 0], dtype='O')
        y = memoryview(x)
        # handles conversion of address to pinned object?
        z = np.array(y)
        assert z.dtype == 'O'
        assert (z == x).all()

        dt1 = np.dtype(
             [('a', 'b'), ('b', 'i'), ('sub', np.dtype('b,i')), ('c', 'i')],
             align=True)
        x = np.arange(dt1.itemsize, dtype=np.int8).view(dt1)
        y = memoryview(x)
        if '__pypy__' in sys.builtin_module_names:
            assert y.format == 'T{b:a:xxxi:b:T{b:f0:i:f1:}:sub:xxxi:c:}'
        else:
            assert y.format == 'T{b:a:xxxi:b:T{b:f0:=i:f1:}:sub:xxx@i:c:}'


        dt1 = np.dtype(
             [('a', 'b'), ('b', 'i'), ('sub', np.dtype('b,i')), ('c', 'i')],
             align=True)
        x = np.arange(dt1.itemsize, dtype=np.int8).view(dt1)
        y = memoryview(x)
        if '__pypy__' in sys.builtin_module_names:
            assert y.format == 'T{b:a:xxxi:b:T{b:f0:i:f1:}:sub:xxxi:c:}'
        else:
            assert y.format == 'T{b:a:xxxi:b:T{b:f0:=i:f1:}:sub:xxx@i:c:}'


    def test_fromstring(self):
        import sys
        from numpy import fromstring, dtype

        a = fromstring(self.data)
        for i in range(4):
            assert a[i] == i + 1
        b = fromstring('\x01\x02', dtype='uint8')
        assert a[0] == 1
        assert a[1] == 2
        c = fromstring(self.fdata, dtype='float32')
        assert c[0] == dtype('float32').type(2.3)
        d = fromstring("1 2", sep=' ', count=2, dtype='uint8')
        assert len(d) == 2
        assert d[0] == 1
        assert d[1] == 2
        e = fromstring('3, 4,5', dtype='uint8', sep=',')
        assert len(e) == 3
        assert e[0] == 3
        assert e[1] == 4
        assert e[2] == 5
        f = fromstring('\x01\x02\x03\x04\x05', dtype='uint8', count=3)
        assert len(f) == 3
        assert f[0] == 1
        assert f[1] == 2
        assert f[2] == 3
        g = fromstring("1  2    3 ", dtype='uint8', sep=" ")
        assert len(g) == 3
        assert g[0] == 1
        assert g[1] == 2
        assert g[2] == 3
        h = fromstring("1, , 2, 3", dtype='uint8', sep=",")
        assert (h == [1, 0, 2, 3]).all()
        i = fromstring("1    2 3", dtype='uint8', sep=" ")
        assert (i == [1, 2, 3]).all()
        j = fromstring("1\t\t\t\t2\t3", dtype='uint8', sep="\t")
        assert (j == [1, 2, 3]).all()
        k = fromstring("1,x,2,3", dtype='uint8', sep=",")
        assert (k == [1, 0]).all()
        l = fromstring("1,x,2,3", dtype='float32', sep=",")
        assert (l == [1.0, -1.0]).all()
        m = fromstring("1,,2,3", sep=",")
        assert (m == [1.0, -1.0, 2.0, 3.0]).all()
        n = fromstring("3.4 2.0 3.8 2.2", dtype='int32', sep=" ")
        assert (n == [3]).all()
        n = fromstring('\x00\x00\x00{', dtype='>i4')
        assert n == 123
        n = fromstring('W\xb0', dtype='>f2')
        assert n == 123.
        o = fromstring("1.0 2f.0f 3.8 2.2", dtype='float32', sep=" ")
        assert len(o) == 2
        assert o[0] == 1.0
        assert o[1] == 2.0
        p = fromstring("1.0,,2.0,3.0", sep=",")
        assert (p == [1.0, -1.0, 2.0, 3.0]).all()
        q = fromstring("1.0,,2.0,3.0", sep=" ")
        assert (q == [1.0]).all()
        r = fromstring("\x01\x00\x02", dtype='bool')
        assert (r == [True, False, True]).all()
        s = fromstring("1,2,3,,5", dtype=bool, sep=",")
        assert (s == [True, True, True, True, True]).all()
        t = fromstring("", bool)
        assert (t == []).all()
        u = fromstring("\x01\x00\x00\x00\x00\x00\x00\x00", dtype=int)
        if sys.maxint > 2 ** 31 - 1:
            if sys.byteorder == 'big':
                assert (u == [0x0100000000000000]).all()
            else:
                assert (u == [1]).all()
        else:
            if sys.byteorder == 'big':
                assert (u == [0x01000000, 0]).all()
            else:
                assert (u == [1, 0]).all()
        v = fromstring("abcd", dtype="|S2")
        assert v[0] == "ab"
        assert v[1] == "cd"

        v = fromstring('@\x01\x99\x99\x99\x99\x99\x9a\xbf\xf1\x99\x99\x99\x99\x99\x9a',
                       dtype=dtype('>c16'))
        assert v.tostring() == \
            '@\x01\x99\x99\x99\x99\x99\x9a\xbf\xf1\x99\x99\x99\x99\x99\x9a'
        assert v[0] == 2.2-1.1j
        assert v.real == 2.2
        assert v.imag == -1.1
        v = fromstring('\x9a\x99\x99\x99\x99\x99\x01@\x9a\x99\x99\x99\x99\x99\xf1\xbf',
                       dtype=dtype('<c16'))
        assert v.tostring() == \
            '\x9a\x99\x99\x99\x99\x99\x01@\x9a\x99\x99\x99\x99\x99\xf1\xbf'
        assert v[0] == 2.2-1.1j
        assert v.real == 2.2
        assert v.imag == -1.1

        d = [('f0', 'i4'), ('f1', 'u2', (2, 3))]
        if '__pypy__' not in sys.builtin_module_names:
            r = fromstring('abcdefghijklmnop'*4*3, dtype=d)
            assert (r[0:3:2]['f1'] == r['f1'][0:3:2]).all()
            assert (r[0:3:2]['f1'][0] == r[0:3:2][0]['f1']).all()
            assert (r[0:3:2]['f1'][0][()] == r[0:3:2][0]['f1'][()]).all()
            assert r[0:3:2]['f1'][0].strides == r[0:3:2][0]['f1'].strides
        else:
            exc = raises(NotImplementedError, fromstring,
                         'abcdefghijklmnop'*4*3, dtype=d)
            assert exc.value[0] == "fromstring not implemented for record types"

    def test_fromstring_types(self):
        from numpy import fromstring, array, dtype
        a = fromstring('\xFF', dtype='int8')
        assert a[0] == -1
        b = fromstring('\xFF', dtype='uint8')
        assert b[0] == 255
        c = fromstring('\xFF\xFF', dtype='int16')
        assert c[0] == -1
        d = fromstring('\xFF\xFF', dtype='uint16')
        assert d[0] == 65535
        e = fromstring('\xFF\xFF\xFF\xFF', dtype='int32')
        assert e[0] == -1
        f = fromstring('\xFF\xFF\xFF\xFF', dtype='uint32')
        assert repr(f[0]) == '4294967295'
        g = fromstring('\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF', dtype='int64')
        assert g[0] == -1
        h = fromstring(self.float32val, dtype='float32')
        assert h[0] == dtype('float32').type(5.2)
        i = fromstring(self.float64val, dtype='float64')
        assert i[0] == dtype('float64').type(300.4)
        j = fromstring(self.ulongval, dtype='L')
        assert j[0] == 12
        k = fromstring(self.float16val, dtype='float16')
        assert k[0] == dtype('float16').type(5.)
        dt =  array([5], dtype='longfloat').dtype
        print(dt.itemsize)
        if dt.itemsize == 8:
            import sys
            if sys.byteorder == 'big':
                m = fromstring('@\x14\x00\x00\x00\x00\x00\x00',
                               dtype='float64')
            else:
                m = fromstring('\x00\x00\x00\x00\x00\x00\x14@',
                               dtype='float64')
        elif dt.itemsize == 12:
            m = fromstring('\x00\x00\x00\x00\x00\x00\x00\xa0\x01@\x00\x00',
                           dtype='float96')
        elif dt.itemsize == 16:
            m = fromstring('\x00\x00\x00\x00\x00\x00\x00\xa0\x01@\x00\x00' \
                           '\x00\x00\x00\x00', dtype='float128')
        else:
            assert False, 'unknown itemsize for longfloat'
        assert m[0] == dtype('longfloat').type(5.)

    def test_fromstring_invalid(self):
        from numpy import fromstring
        #default dtype is 64-bit float, so 3 bytes should fail
        raises(ValueError, fromstring, "\x01\x02\x03")
        #3 bytes is not modulo 2 bytes (int16)
        raises(ValueError, fromstring, "\x01\x03\x03", dtype='uint16')
        #5 bytes is larger than 3 bytes
        raises(ValueError, fromstring, "\x01\x02\x03", count=5, dtype='uint8')

    def test_tostring(self):
        from numpy import array
        import sys
        if sys.byteorder == 'big':
            assert array([1, 2, 3], 'i2').tostring() == '\x00\x01\x00\x02\x00\x03'
            assert array([1, 2, 3], 'i2')[::2].tostring() == '\x00\x01\x00\x03'
        else:
            assert array([1, 2, 3], 'i2').tostring() == '\x01\x00\x02\x00\x03\x00'
            assert array([1, 2, 3], 'i2')[::2].tostring() == '\x01\x00\x03\x00'
        assert array([1, 2, 3], '<i2')[::2].tostring() == '\x01\x00\x03\x00'
        assert array([1, 2, 3], '>i2')[::2].tostring() == '\x00\x01\x00\x03'
        assert array(0, dtype='i2').tostring() == '\x00\x00'
        a = array([[1, 2], [3, 4]], dtype='i1')
        for order in (None, False, 'C', 'K', 'a'):
            assert a.tostring(order) == '\x01\x02\x03\x04'
        import sys
        for order in (True, 'F'):
            assert a.tostring(order) == '\x01\x03\x02\x04'
        assert array(2.2-1.1j, dtype='>c16').tostring() == \
            '@\x01\x99\x99\x99\x99\x99\x9a\xbf\xf1\x99\x99\x99\x99\x99\x9a'
        assert array(2.2-1.1j, dtype='<c16').tostring() == \
            '\x9a\x99\x99\x99\x99\x99\x01@\x9a\x99\x99\x99\x99\x99\xf1\xbf'
        assert a.tostring == a.tobytes

    def test_str(self):
        from numpy import array
        assert str(array([1, 2, 3])) == '[1 2 3]'
        assert str(array(['abc'], 'S3')) == "['abc']"
        assert str(array('abc')) == 'abc'
        assert str(array(1.5)) == '1.5'
        assert str(array(1.5).real) == '1.5'
        arr = array(['abc', 'abc'])
        for a in arr.flat:
             assert str(a) == 'abc'

    def test_ndarray_buffer_strides(self):
        from numpy import ndarray, array
        base = array([1, 2, 3, 4], dtype=int)
        a = ndarray((4,), buffer=base, dtype=int)
        assert a[1] == 2
        a = ndarray((4,), buffer=base, dtype=int, strides=[base.strides[0]])
        assert a[1] == 2
        a = ndarray((2,), buffer=base, dtype=int, strides=[2 * base.strides[0]])
        assert a[1] == 3
        exc = raises(ValueError, ndarray, (4,), buffer=base, dtype=int, strides=[2 * base.strides[0]])
        assert exc.value[0] == 'strides is incompatible with shape of requested array and size of buffer'
        exc = raises(ValueError, ndarray, (2, 1), buffer=base, dtype=int, strides=[base.strides[0]])
        assert exc.value[0] == 'strides, if given, must be the same length as shape'



class AppTestRepr(BaseNumpyAppTest):
    def setup_class(cls):
        if option.runappdirect:
            py.test.skip("Can't be run directly.")
        BaseNumpyAppTest.setup_class.im_func(cls)
        cache = get_appbridge_cache(cls.space)
        cls.old_array_repr = cache.w_array_repr
        cls.old_array_str = cache.w_array_str
        cache.w_array_str = None
        cache.w_array_repr = None

    def test_repr(self):
        from numpy import array
        assert repr(array([1, 2, 3])) == 'array([1, 2, 3])'
        assert repr(array(['abc'], 'S3')) == "array(['abc'])"
        assert repr(array(1.5)) == "array(1.5)"
        assert repr(array(1.5).real) == "array(1.5)"

    def teardown_class(cls):
        if option.runappdirect:
            return
        cache = get_appbridge_cache(cls.space)
        cache.w_array_repr = cls.old_array_repr
        cache.w_array_str = cls.old_array_str


class AppTestRecordDtype(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "struct", "binascii"])

    def test_zeros(self):
        from numpy import zeros, void
        a = zeros((), dtype=[('x', int), ('y', float)])
        assert type(a[()]) is void
        assert type(a.item()) is tuple
        assert a[()]['x'] == 0
        assert a[()]['y'] == 0
        assert a.shape == ()
        a = zeros(2, dtype=[('x', int), ('y', float)])
        raises(ValueError, 'a[0]["xyz"]')
        assert a[0]['x'] == 0
        assert a[0]['y'] == 0
        exc = raises(ValueError, "a[0] = (1, 2, 3)")
        assert exc.value[0] == 'size of tuple must match number of fields.'
        a[0]['x'] = 13
        assert a[0]['x'] == 13
        a[1] = (1, 2)
        assert a[1]['y'] == 2
        b = zeros(2, dtype=[('x', int), ('y', float)])
        b[1] = a[1]
        assert a[1]['y'] == 2

    def test_views(self):
        from numpy import array, zeros, ndarray
        a = zeros((), dtype=[('x', int), ('y', float)])
        raises(IndexError, 'a[0]')
        assert type(a['x']) is ndarray
        assert a['x'] == 0
        assert a['y'] == 0
        a = array([(1, 2), (3, 4)], dtype=[('x', int), ('y', float)])
        raises((IndexError, ValueError), 'array([1])["x"]')
        raises((IndexError, ValueError), 'a["z"]')
        assert a['x'][1] == 3
        assert a['y'][1] == 4
        a['x'][0] = 15
        assert a['x'][0] == 15
        b = a['x'] + a['y']
        assert (b == [15+2, 3+4]).all()
        assert b.dtype == float

    def test_assign_tuple(self):
        from numpy import zeros
        a = zeros((2, 3), dtype=[('x', int), ('y', float)])
        a[1, 2] = (1, 2)
        assert a['x'][1, 2] == 1
        assert a['y'][1, 2] == 2

    def test_creation_and_repr(self):
        from numpy import array
        a = array((1, 2), dtype=[('x', int), ('y', float)])
        assert a.shape == ()
        assert repr(a[()]) == '(1, 2.0)'
        a = array([(1, 2), (3, 4)], dtype=[('x', int), ('y', float)])
        assert repr(a[0]) == '(1, 2.0)'

    def test_void_copyswap(self):
        import numpy as np
        dt = np.dtype([('one', '<i4'), ('two', '<i4')])
        x = np.array((1, 2), dtype=dt)
        x = x.byteswap()
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            assert x['one'] > 0 and x['two'] > 2
        else:
            assert x['one'] == 1 and x['two'] == 2

    def test_nested_dtype(self):
        import numpy as np
        a = [('x', int), ('y', float)]
        b = [('x', int), ('y', a)]
        arr = np.zeros((), dtype=b)
        assert arr['x'] == 0
        arr['x'] = 2
        assert arr['x'] == 2
        exc = raises(IndexError, "arr[3L]")
        assert exc.value.message == "too many indices for array"
        exc = raises(ValueError, "arr['xx'] = 2")
        assert exc.value.message == "no field of name xx"
        assert arr['y'].dtype == a
        assert arr['y'].shape == ()
        assert arr['y'][()]['x'] == 0
        assert arr['y'][()]['y'] == 0
        arr['y'][()]['x'] = 2
        arr['y'][()]['y'] = 3
        assert arr['y'][()]['x'] == 2
        assert arr['y'][()]['y'] == 3
        arr = np.zeros(3, dtype=b)
        arr[1]['x'] = 15
        assert arr[1]['x'] == 15
        arr[1]['y']['y'] = 3.5
        assert arr[1]['y']['y'] == 3.5
        assert arr[1]['y']['x'] == 0.0
        assert arr[1]['x'] == 15

    def test_count_nonzero(self):
        import numpy as np
        import sys
        d = [('f0', 'i4'), ('f1', 'i4', 2)]
        arr = np.array([0, 1])
        if '__pypy__' not in sys.builtin_module_names:
            arr = arr.astype(d)[:1]
            assert np.count_nonzero(arr) == 0
        else:
            raises(NotImplementedError, "arr.astype(d)")

    def test_string_record(self):
        from numpy import dtype, array

        d = dtype([('x', str), ('y', 'int32')])
        assert str(d.fields['x'][0]) == '|S0'
        assert d.fields['x'][1] == 0
        assert str(d.fields['y'][0]) == 'int32'
        assert d.fields['y'][1] == 0
        assert d.name == 'void32'

        a = array([('a', 2), ('cde', 1)], dtype=d)
        if 0: # XXX why does numpy allow this?
            assert a[0]['x'] == '\x02'
        assert a[0]['y'] == 2
        if 0: # XXX why does numpy allow this?
            assert a[1]['x'] == '\x01'
        assert a[1]['y'] == 1

        d = dtype([('x', 'S1'), ('y', 'int32')])
        assert str(d.fields['x'][0]) == '|S1'
        assert d.fields['x'][1] == 0
        assert str(d.fields['y'][0]) == 'int32'
        assert d.fields['y'][1] == 1
        assert d.name == 'void40'

        a = array([('a', 2), ('cde', 1)], dtype=d)
        assert a[0]['x'] == 'a'
        assert a[0]['y'] == 2
        assert a[1]['x'] == 'c'
        assert a[1]['y'] == 1

    def test_string_array(self):
        from numpy import array
        a = array(['abc'])
        assert str(a.dtype) == '|S3'
        a = array(['abc'], 'S')
        assert str(a.dtype) == '|S3'
        a = array(['abc'], 'S3')
        assert str(a.dtype) == '|S3'
        a = array(['abcde'], 'S3')
        assert str(a.dtype) == '|S3'
        a = array(['abc', 'defg', 'ab'])
        assert str(a.dtype) == '|S4'
        assert a[0] == 'abc'
        assert a[1] == 'defg'
        assert a[2] == 'ab'
        a = array(['abc', 'defg', 'ab'], 'S3')
        assert str(a.dtype) == '|S3'
        assert a[0] == 'abc'
        assert a[1] == 'def'
        assert a[2] == 'ab'
        b = array(["\x00\x01", "\x00\x02\x03"], dtype=str)
        assert str(b.dtype) == '|S3'
        assert b[0] == "\x00\x01"
        assert b[1] == "\x00\x02\x03"
        assert b.tostring() == "\x00\x01\x00\x00\x02\x03"
        c = b.astype(b.dtype)
        assert (b == c).all()
        assert c.tostring() == "\x00\x01\x00\x00\x02\x03"
        raises(TypeError, a, 'sum')
        raises(TypeError, 'a+a')
        b = array(['abcdefg', 'ab', 'cd'])
        assert a[2] == b[1]
        assert bool(a[1])
        c = array(['ab','cdefg','hi','jk'])
        # not implemented yet
        #c[0] += c[3]
        #assert c[0] == 'abjk'

    def test_to_str(self):
        from numpy import array
        a = array(['abc','abc', 'def', 'ab'], 'S3')
        b = array(['mnopqr','abcdef', 'ab', 'cd'])
        assert b[1] != a[1]

    def test_string_scalar(self):
        from numpy import array
        a = array('ffff')
        assert a.shape == ()
        a = array([], dtype='S')
        assert str(a.dtype) == '|S1'
        a = array('x', dtype='>S')
        assert str(a.dtype) == '|S1'
        a = array('x', dtype='c')
        assert str(a.dtype) == '|S1'
        assert a == 'x'
        a = array('abc', 'S2')
        assert a.dtype.str == '|S2'
        assert a == 'ab'
        a = array('abc', 'S5')
        assert a.dtype.str == '|S5'
        assert a == 'abc'

    def test_newbyteorder(self):
        import numpy as np
        a = np.array([1, 2], dtype=np.int16)
        b = a.newbyteorder()
        assert (b == [256, 512]).all()
        c = b.byteswap()
        assert (c == [1, 2]).all()
        assert (a == [1, 2]).all()

    def test_pickle(self):
        from numpy import dtype, array, int32
        from cPickle import loads, dumps

        d = dtype([('x', str), ('y', 'int32')])
        a = array([('a', 2), ('cde', 1)], dtype=d)

        a = loads(dumps(a))
        d = a.dtype

        assert str(d.fields['x'][0]) == '|S0'
        assert d.fields['x'][1] == 0
        assert str(d.fields['y'][0]) == 'int32'
        assert d.fields['y'][1] == 0
        assert d.name == 'void32'

        assert a[0]['y'] == 2
        assert a[1]['y'] == 1

        a = array([(1, [])], dtype=[('a', int32), ('b', int32, 0)])
        assert a['b'].shape == (1, 0)
        b = loads(dumps(a))
        assert b['b'].shape == (1, 0)

    def test_subarrays(self):
        from numpy import dtype, array, zeros
        d = dtype([("x", "int", 3), ("y", "float", 5)])

        a = zeros((), dtype=d)
        #assert a['x'].dtype == int
        #assert a['x'].shape == (3,)
        #assert (a['x'] == [0, 0, 0]).all()

        a = array([([1, 2, 3], [0.5, 1.5, 2.5, 3.5, 4.5]),
                   ([4, 5, 6], [5.5, 6.5, 7.5, 8.5, 9.5])], dtype=d)
        for v in ['x', u'x', 0, -2]:
            assert (a[0][v] == [1, 2, 3]).all()
            assert (a[1][v] == [4, 5, 6]).all()
        for v in ['y', u'y', -1, 1]:
            assert (a[0][v] == [0.5, 1.5, 2.5, 3.5, 4.5]).all()
            assert (a[1][v] == [5.5, 6.5, 7.5, 8.5, 9.5]).all()
        for v in [-3, 2]:
            exc = raises(IndexError, "a[0][%d]" % v)
            assert exc.value.message == "invalid index (%d)" % \
                                        (v + 2 if v < 0 else v)
        exc = raises(ValueError, "a[0]['z']")
        assert exc.value.message == "no field of name z"
        exc = raises(IndexError, "a[0][None]")
        assert exc.value.message == "invalid index"

        a[0]["x"][0] = 200
        assert a[0]["x"][0] == 200
        a[1]["x"][2] = 123
        assert (a[1]["x"] == [4, 5, 123]).all()
        a[1]['y'][3] = 4
        assert a[1]['y'][3] == 4
        assert a['y'][1][3] == 4
        a['y'][1][4] = 5
        assert a[1]['y'][4] == 5

        d = dtype([("x", "int64", (2, 3))])
        a = array([([[1, 2, 3], [4, 5, 6]],)], dtype=d)

        assert a[0]["x"].dtype == dtype("int64")
        assert a[0]["x"][0].dtype == dtype("int64")

        assert (a[0]["x"][0] == [1, 2, 3]).all()
        assert (a[0]["x"] == [[1, 2, 3], [4, 5, 6]]).all()

        d = dtype((float, (10, 10)))
        a = zeros((3,3), dtype=d)
        assert a[0, 0].shape == (10, 10)
        assert a.shape == (3, 3, 10, 10)
        a[0, 0] = 500
        assert (a[0, 0, 0] == 500).all()
        assert a[0, 0, 0].shape == (10,)
        exc = raises(IndexError, "a[0, 0]['z']")
        assert exc.value.message.startswith('only integers, slices')

        import sys
        a = array(1.5, dtype=float)
        assert a.shape == ()
        if '__pypy__' not in sys.builtin_module_names:
            a = a.astype((float, 2))
            repr(a)  # check for crash
            assert a.shape == (2,)
            assert tuple(a) == (1.5, 1.5)
        else:
            raises(NotImplementedError, "a.astype((float, 2))")

        a = array([1.5], dtype=float)
        assert a.shape == (1,)
        if '__pypy__' not in sys.builtin_module_names:
            a = a.astype((float, 2))
            repr(a)  # check for crash
            assert a.shape == (1, 2)
            assert tuple(a[0]) == (1.5, 1.5)
        else:
            raises(NotImplementedError, "a.astype((float, 2))")

    def test_subarray_multiple_rows(self):
        import numpy as np
        descr = [
            ('x', 'i4', (2,)),
            ('y', 'f8', (2, 2)),
            ('z', 'u1')]
        buf = [
            # x     y                  z
            ([3,2], [[6.,4.],[6.,4.]], 8),
            ([4,3], [[7.,5.],[7.,5.]], 9),
            ]
        h = np.array(buf, dtype=descr)
        assert len(h) == 2
        assert h['x'].shape == (2, 2)
        assert h['y'].strides == (41, 16, 8)
        assert h['z'].shape == (2,)
        for v in (h, h[0], h['x']):
            repr(v)  # check for crash in repr
        assert (h['x'] == np.array([buf[0][0],
                                    buf[1][0]], dtype='i4')).all()
        assert (h['y'] == np.array([buf[0][1],
                                    buf[1][1]], dtype='f8')).all()
        assert (h['z'] == np.array([buf[0][2],
                                    buf[1][2]], dtype='u1')).all()

    def test_multidim_subarray(self):
        from numpy import dtype, array

        d = dtype([("x", "int64", (2, 3))])
        a = array([([[1, 2, 3], [4, 5, 6]],)], dtype=d)

        assert a[0]["x"].dtype == dtype("int64")
        assert a[0]["x"][0].dtype == dtype("int64")

        assert (a[0]["x"][0] == [1, 2, 3]).all()
        assert (a[0]["x"] == [[1, 2, 3], [4, 5, 6]]).all()

    def test_list_record(self):
        from numpy import dtype, array

        d = dtype([("x", "int", 3), ("y", "float", 5)])
        a = array([([1, 2, 3], [0.5, 1.5, 2.5, 3.5, 4.5]),
                   ([4, 5, 6], [5.5, 6.5, 7.5, 8.5, 9.5])], dtype=d)

        assert len(list(a[0])) == 2

        mdtype = dtype([('a', bool), ('b', bool), ('c', bool)])
        a = array([0, 0, 0, 1, 1])
        # this creates a value of (x, x, x) in b for each x in a
        b = array(a, dtype=mdtype)
        assert b.shape == a.shape
        c = array([(x, x, x) for x in [0, 0, 0, 1, 1]], dtype=mdtype)
        assert (b == c).all()

    def test_3d_record(self):
        from numpy import dtype, array
        dt = dtype([('name', 'S4'), ('x', float), ('y', float),
                    ('block', int, (2, 2, 3))])
        a = array([('aaaa', 1.0, 8.0, [[[1, 2, 3], [4, 5, 6]],
                                       [[7, 8, 9], [10, 11, 12]]])],
                  dtype=dt)
        i = a.item()
        assert isinstance(i, tuple)
        assert len(i) == 4
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            assert str(a) == "[('aaaa', 1.0, 8.0, [[[1, 2, 3], [4, 5, 6]], " \
                                                  "[[7, 8, 9], [10, 11, 12]]])]"
        else:
            assert str(a) == "[('aaaa', 1.0, 8.0, [1, 2, 3, 4, 5, 6, " \
                                                  "7, 8, 9, 10, 11, 12])]"

    def test_issue_1589(self):
        import numpy
        c = numpy.array([[(1, 2, 'a'), (3, 4, 'b')], [(5, 6, 'c'), (7, 8, 'd')]],
                        dtype=[('bg', 'i8'), ('fg', 'i8'), ('char', 'S1')])
        assert c[0][0]["char"] == 'a'

    def test_scalar_coercion(self):
        import numpy as np
        a = np.array([1,2,3], dtype='int16')
        assert (a * 2).dtype == np.dtype('int16')

    def test_coerce_record(self):
        import numpy as np
        dt = np.dtype([('a', '?'), ('b', '?')])
        b = np.array([True, True])
        a = np.array([b, b, b], dtype=dt)
        assert a.shape == (3, 2)
        for i in a.flat:
            assert tuple(i) == (True, True)

        dt = np.dtype([('A', '<i8'), ('B', '<f8'), ('C', '<c16')])
        b = np.array((999999, 1e+20, 1e+20+0j), dtype=dt)
        a = np.array(b, copy=False, dtype=dt.descr)
        assert tuple(a[()]) == (999999, 1e+20, 1e+20+0j)

    def test_reduce_record(self):
        import numpy as np
        dt = np.dtype([('a', float), ('b', float)])
        a = np.array(list(zip(range(10), reversed(range(10)))), dtype=dt)
        exc = raises(TypeError, np.maximum.reduce, a)
        assert exc.value[0] == 'cannot perform reduce with flexible type'
        v = a.view((float, 2))
        assert v.dtype == np.dtype(float)
        assert v.shape == (10, 2)
        m = np.maximum.reduce(v)
        assert (m == [9, 9]).all()
        m = np.maximum.reduce(v, axis=None)
        assert (m == [9, 9]).all()
        m = np.maximum.reduce(v, axis=-1)
        assert (m == [9, 8, 7, 6, 5, 5, 6, 7, 8, 9]).all()
        m = v.argmax()
        assert m == 1
        v = a.view(('float32', 4))
        assert v.dtype == np.dtype('float32')
        assert v.shape == (10, 4)
        import sys
        if sys.byteorder == 'big':
            assert v[0][-2] == 2.53125
        else:
            assert v[0][-1] == 2.53125
        exc = raises(ValueError, "a.view(('float32', 2))")
        assert exc.value[0] == 'new type not compatible with array.'

    def test_record_ufuncs(self):
        import numpy as np
        a = np.zeros(3, dtype=[('a', 'i8'), ('b', 'i8')])
        b = np.zeros(3, dtype=[('a', 'i8'), ('b', 'i8')])
        c = np.zeros(3, dtype=[('a', 'f8'), ('b', 'f8')])
        d = np.ones(3, dtype=[('a', 'i8'), ('b', 'i8')])
        e = np.ones(3, dtype=[('a', 'i8'), ('b', 'i8'), ('c', 'i8')])
        exc = raises(TypeError, abs, a)
        assert exc.value[0].startswith("ufunc 'absolute' did not contain a loop")
        assert (a == a).all()
        assert not (a != a).any()
        assert (a == b).all()
        assert not (a != b).any()
        assert a != c
        assert not a == c
        assert (a != d).all()
        assert not (a == d).any()
        assert a != e
        assert not a == e
        assert np.greater(a, a) is NotImplemented
        assert np.less_equal(a, a) is NotImplemented

    def test_create_from_memory(self):
        import numpy as np
        import sys
        builtins = getattr(__builtins__, '__dict__', __builtins__)
        _buffer = builtins.get('buffer')
        dat = np.array(_buffer('1.0'))
        assert (dat == [49, 46, 48]).all()
        assert dat.dtype == np.dtype('uint8')


class AppTestPyPy(BaseNumpyAppTest):
    def setup_class(cls):
        if option.runappdirect and '__pypy__' not in sys.builtin_module_names:
            py.test.skip("pypy only test")
        BaseNumpyAppTest.setup_class.im_func(cls)

    def test_init_2(self):
        # this test is pypy only since in numpy it becomes an object dtype
        import numpy
        raises(ValueError, numpy.array, [[1], 2])
        raises(ValueError, numpy.array, [[1, 2], [3]])
        raises(ValueError, numpy.array, [[[1, 2], [3, 4], 5]])
        raises(ValueError, numpy.array, [[[1, 2], [3, 4], [5]]])
        a = numpy.array([[1, 2], [4, 5]])
        assert a[0, 1] == 2
        assert a[0][1] == 2
        a = numpy.array(([[[1, 2], [3, 4], [5, 6]]]))
        assert (a[0, 1] == [3, 4]).all()

    def test_from_shape_and_storage(self):
        from numpy import array, ndarray
        x = array([1, 2, 3, 4])
        addr, _ = x.__array_interface__['data']
        sz = x.size * x.dtype.itemsize
        y = ndarray._from_shape_and_storage([2, 2], addr, x.dtype, sz)
        assert y[0, 1] == 2
        y[0, 1] = 42
        assert x[1] == 42
        class C(ndarray):
            pass
        z = ndarray._from_shape_and_storage([4, 1], addr, x.dtype, sz, C)
        assert isinstance(z, C)
        assert z.shape == (4, 1)
        assert z[1, 0] == 42

    def test___pypy_data__(self):
        from numpy import array
        x = array([1, 2, 3, 4])
        x.__pypy_data__ is None
        obj = object()
        x.__pypy_data__ = obj
        assert x.__pypy_data__ is obj
        del x.__pypy_data__
        assert x.__pypy_data__ is None

    def test_from_shape_and_storage_strides(self):
        from numpy import ndarray, array
        base = array([1, 2, 3, 4], dtype=int)
        addr, _ = base.__array_interface__['data']
        sz = base.size * base.dtype.itemsize
        a = ndarray._from_shape_and_storage((4,), addr, int, sz)
        assert a[1] == 2
        a = ndarray._from_shape_and_storage((4,), addr, int, sz,
                                           strides=[base.strides[0]])
        assert a[1] == 2
        a = ndarray._from_shape_and_storage((2,), addr, int, sz,
                                           strides=[2 * base.strides[0]])
        assert a[1] == 3
