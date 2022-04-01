from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest

class AppTestSorting(BaseNumpyAppTest):
    def test_argsort_dtypes(self):
        from numpy import array, arange
        assert array(2.0).argsort() == 0
        nnp = self.non_native_prefix
        for dtype in ['int', 'float', 'int16', 'float32', 'uint64',
                      nnp + 'i2', complex]:
            a = array([6, 4, -1, 3, 8, 3, 256+20, 100, 101], dtype=dtype)
            exp = list(a)
            exp = sorted(range(len(exp)), key=exp.__getitem__)
            c = a.copy()
            res = a.argsort()
            assert (res == exp).all(), 'Failed sortng %r\na=%r\nres=%r\nexp=%r' % (dtype,a,res,exp)
            assert (a == c).all() # not modified

            a = arange(100, dtype=dtype)
            assert (a.argsort() == a).all()

    def test_argsort_ndim(self):
        from numpy import array
        a = array([[4, 2], [1, 3]])
        assert (a.argsort() == [[1, 0], [0, 1]]).all()
        a = array(range(10) + range(10) + range(10))
        b = a.argsort()
        assert ((b[:3] == [0, 10, 20]).all() or
                (b[:3] == [0, 20, 10]).all())
        #trigger timsort 'run' mode which calls arg_getitem_slice
        a = array(range(100) + range(100) + range(100))
        b = a.argsort()
        assert ((b[:3] == [0, 100, 200]).all() or
                (b[:3] == [0, 200, 100]).all())
        a = array([[[]]]).reshape(3,4,0)
        b = a.argsort()
        assert b.size == 0

    def test_argsort_random(self):
        from numpy import array
        from _random import Random
        rnd = Random(1)
        a = array([rnd.random() for i in range(512*2)]).reshape(512,2)
        a.argsort()

    def test_argsort_axis(self):
        from numpy import array
        a = array([])
        for axis in [None, -1, 0]:
            assert a.argsort(axis=axis).shape == (0,)
        a = array([[4, 2], [1, 3]])
        assert (a.argsort(axis=None) == [2, 1, 3, 0]).all()
        assert (a.argsort(axis=-1) == [[1, 0], [0, 1]]).all()
        assert (a.argsort(axis=0) == [[1, 0], [0, 1]]).all()
        assert (a.argsort(axis=1) == [[1, 0], [0, 1]]).all()
        a = array([[3, 2, 1], [1, 2, 3]])
        assert (a.argsort(axis=0) == [[1, 0, 0], [0, 1, 1]]).all()
        assert (a.argsort(axis=1) == [[2, 1, 0], [0, 1, 2]]).all()

    def test_sort_dtypes(self):
        from numpy import array, arange
        for dtype in ['int', 'float', 'int16', 'float32', 'uint64',
                      'i2', complex]:
            a = array([6, 4, -1, 3, 8, 3, 256+20, 100, 101], dtype=dtype)
            exp = sorted(list(a))
            a.sort()
            assert (a == exp).all(), 'Failed sorting %r\n%r\n%r' % (dtype, a, exp)

            a = arange(100, dtype=dtype)
            c = a.copy()
            a.sort()
            assert (a == c).all(), 'Failed sortng %r\na=%r\nc=%r' % (dtype,a,c)

    def test_sort_nonnative(self):
        from numpy import array
        nnp = self.non_native_prefix
        for dtype in [ nnp + 'i2']:
            a = array([6, 4, -1, 3, 8, 3, 256+20, 100, 101], dtype=dtype)
            b = array([-1, 3, 3, 4, 6, 8, 100, 101, 256+20], dtype=dtype)
            c = a.copy()
            import sys
            if '__pypy__' in sys.builtin_module_names:
                exc = raises(NotImplementedError, a.sort)
                assert exc.value[0].find('supported') >= 0
            #assert (a == b).all(), \
            #    'a,orig,dtype %r,%r,%r' % (a,c,dtype)

    def test_sort_noncontiguous(self):
        from numpy import array
        x = array([[2, 10], [1, 11]])
        assert (x[:, 0].argsort() == [1, 0]).all()
        x[:, 0].sort()
        assert (x == [[1, 10], [2, 11]]).all()

# tests from numpy/tests/test_multiarray.py
    def test_sort_corner_cases(self):
        # test ordering for floats and complex containing nans. It is only
        # necessary to check the lessthan comparison, so sorts that
        # only follow the insertion sort path are sufficient. We only
        # test doubles and complex doubles as the logic is the same.

        # check doubles
        from numpy import array, zeros, arange
        from math import isnan
        nan = float('nan')
        a = array([nan, 1, 0])
        b = a.copy()
        b.sort()
        assert [isnan(bb) for bb in b] == [isnan(aa) for aa in a[::-1]]
        assert (b[:2] == a[::-1][:2]).all()

        b = a.argsort()
        assert (b == [2, 1, 0]).all()

        # check complex
        a = zeros(9, dtype='complex128')
        a.real += [nan, nan, nan, 1, 0, 1, 1, 0, 0]
        a.imag += [nan, 1, 0, nan, nan, 1, 0, 1, 0]
        b = a.copy()
        b.sort()
        assert [isnan(bb) for bb in b] == [isnan(aa) for aa in a[::-1]]
        assert (b[:4] == a[::-1][:4]).all()

        b = a.argsort()
        assert (b == [8, 7, 6, 5, 4, 3, 2, 1, 0]).all()

        # all c scalar sorts use the same code with different types
        # so it suffices to run a quick check with one type. The number
        # of sorted items must be greater than ~50 to check the actual
        # algorithm because quick and merge sort fall over to insertion
        # sort for small arrays.
        a = arange(101)
        b = a[::-1].copy()
        for kind in ['q', 'm', 'h'] :
            msg = "scalar sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg

        # test complex sorts. These use the same code as the scalars
        # but the compare fuction differs.
        ai = a*1j + 1
        bi = b*1j + 1
        for kind in ['q', 'm', 'h'] :
            msg = "complex sort, real part == 1, kind=%s" % kind
            c = ai.copy();
            c.sort(kind=kind)
            assert (c == ai).all(), msg
            c = bi.copy();
            c.sort(kind=kind)
            assert (c == ai).all(), msg
        ai = a + 1j
        bi = b + 1j
        for kind in ['q', 'm', 'h'] :
            msg = "complex sort, imag part == 1, kind=%s" % kind
            c = ai.copy();
            c.sort(kind=kind)
            assert (c == ai).all(), msg
            c = bi.copy();
            c.sort(kind=kind)
            assert (c == ai).all(), msg

        # check axis handling. This should be the same for all type
        # specific sorts, so we only check it for one type and one kind
        a = array([[3, 2], [1, 0]])
        b = array([[1, 0], [3, 2]])
        c = array([[2, 3], [0, 1]])
        d = a.copy()
        d.sort(axis=0)
        assert (d == b).all(), "test sort with axis=0"
        d = a.copy()
        d.sort(axis=1)
        assert (d == c).all(), "test sort with axis=1"
        d = a.copy()
        d.sort()
        assert (d == c).all(), "test sort with default axis"

    def test_sort_corner_cases_string_records(self):
        from numpy import array, dtype
        import sys
        if '__pypy__' in sys.builtin_module_names:
            skip('not implemented yet in PyPy')
        # test string sorts.
        s = 'aaaaaaaa'
        a = array([s + chr(i) for i in range(101)])
        b = a[::-1].copy()
        for kind in ['q', 'm', 'h'] :
            msg = "string sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg


        # test record array sorts.
        dt =dtype([('f', float), ('i', int)])
        a = array([(i, i) for i in range(101)], dtype = dt)
        b = a[::-1]
        for kind in ['q', 'h', 'm'] :
            msg = "object sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg

    def test_sort_unicode(self):
        import sys
        from numpy import array
        # test unicode sorts.
        s = 'aaaaaaaa'
        a = array([s + chr(i) for i in range(101)], dtype=unicode)
        b = a[::-1].copy()
        for kind in ['q', 'm', 'h']:
            msg = "unicode sort, kind=%s" % kind
            c = a.copy()
            if '__pypy__' in sys.builtin_module_names:
                exc = raises(NotImplementedError, "c.sort(kind=kind)")
                assert 'non-numeric types' in exc.value.message
            else:
                c.sort(kind=kind)
                assert (c == a).all(), msg
            c = b.copy()
            if '__pypy__' in sys.builtin_module_names:
                exc = raises(NotImplementedError, "c.sort(kind=kind)")
                assert 'non-numeric types' in exc.value.message
            else:
                c.sort(kind=kind)
                assert (c == a).all(), msg

    def test_sort_objects(self):
        # test object array sorts.
        from numpy import empty
        import sys
        if '__pypy__' in sys.builtin_module_names:
            skip('not implemented yet in PyPy')
        try:
            a = empty((101,), dtype=object)
        except:
            skip('object type not supported yet')
        a[:] = list(range(101))
        b = a[::-1]
        for kind in ['q', 'h', 'm'] :
            msg = "object sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg

    def test_sort_datetime(self):
        from numpy import arange
        # test datetime64 sorts.
        try:
            a = arange(0, 101, dtype='datetime64[D]')
        except:
            skip('datetime type not supported yet')
        b = a[::-1]
        for kind in ['q', 'h', 'm'] :
            msg = "datetime64 sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg

        # test timedelta64 sorts.
        a = arange(0, 101, dtype='timedelta64[D]')
        b = a[::-1]
        for kind in ['q', 'h', 'm'] :
            msg = "timedelta64 sort, kind=%s" % kind
            c = a.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg
            c = b.copy();
            c.sort(kind=kind)
            assert (c == a).all(), msg

    def test_sort_order(self):
        from numpy import array, zeros
        from sys import byteorder, builtin_module_names
        if '__pypy__' in builtin_module_names:
            skip('not implemented yet in PyPy')
        # Test sorting an array with fields
        x1 = array([21, 32, 14])
        x2 = array(['my', 'first', 'name'])
        x3=array([3.1, 4.5, 6.2])
        r=zeros(3, dtype=[('id','i'),('word','S5'),('number','f')])
        r['id'] = x1
        r['word'] = x2
        r['number'] = x3

        r.sort(order=['id'])
        assert (r['id'] == [14, 21, 32]).all()
        assert (r['word'] == ['name', 'my', 'first']).all()
        assert max(abs(r['number'] - [6.2, 3.1, 4.5])) < 1e-6

        r.sort(order=['word'])
        assert (r['id'] == [32, 21, 14]).all()
        assert (r['word'] == ['first', 'my', 'name']).all()
        assert max(abs(r['number'] - [4.5, 3.1, 6.2])) < 1e-6

        r.sort(order=['number'])
        assert (r['id'] == [21, 32, 14]).all()
        assert (r['word'] == ['my', 'first', 'name']).all()
        assert max(abs(r['number'] - [3.1, 4.5, 6.2])) < 1e-6

        if byteorder == 'little':
            strtype = '>i2'
        else:
            strtype = '<i2'
        mydtype = [('name', 'S5'), ('col2', strtype)]
        r = array([('a', 1), ('b', 255), ('c', 3), ('d', 258)],
                     dtype= mydtype)
        r.sort(order='col2')
        assert (r['col2'] == [1, 3, 255, 258]).all()
        assert (r == array([('a', 1), ('c', 3), ('b', 255), ('d', 258)],
                                 dtype=mydtype)).all()

# tests from numpy/core/tests/test_regression.py
    def test_sort_bigendian(self):
        from numpy import array, dtype
        import sys

        # little endian sorting for big endian machine
        # is not yet supported! IMPL ME
        if sys.byteorder == 'little':
            a = array(range(11), dtype='float64')
            c = a.astype(dtype('<f8'))
            c.sort()
            assert max(abs(a-c)) < 1e-32

    def test_string_argsort_with_zeros(self):
        import numpy as np
        import sys
        x = np.fromstring("\x00\x02\x00\x01", dtype="|S2")
        if '__pypy__' in sys.builtin_module_names:
            exc = raises(NotImplementedError, "x.argsort(kind='m')")
            assert 'non-numeric types' in exc.value.message
            exc = raises(NotImplementedError, "x.argsort(kind='q')")
            assert 'non-numeric types' in exc.value.message
        else:
            assert (x.argsort(kind='m') == np.array([1, 0])).all()
            assert (x.argsort(kind='q') == np.array([1, 0])).all()

    def test_string_sort_with_zeros(self):
        import numpy as np
        import sys
        x = np.fromstring("\x00\x02\x00\x01", dtype="S2")
        y = np.fromstring("\x00\x01\x00\x02", dtype="S2")
        if '__pypy__' in sys.builtin_module_names:
            exc = raises(NotImplementedError, "x.sort(kind='q')")
            assert 'non-numeric types' in exc.value.message
        else:
            x.sort(kind='q')
            assert (x == y).all()

    def test_string_mergesort(self):
        import numpy as np
        import sys
        x = np.array(['a'] * 32)
        if '__pypy__' in sys.builtin_module_names:
            exc = raises(NotImplementedError, "x.argsort(kind='m')")
            assert 'non-numeric types' in exc.value.message
        else:
            assert (x.argsort(kind='m') == np.arange(32)).all()

    def test_searchsort(self):
        import numpy as np

        a = np.array(2)
        raises(ValueError, a.searchsorted, 3)

        a = np.arange(1, 6)

        ret = a.searchsorted(3)
        assert ret == 2
        assert isinstance(ret, np.generic)

        ret = a.searchsorted(np.array(3))
        assert ret == 2
        assert isinstance(ret, np.generic)

        ret = a.searchsorted(np.array([]))
        assert isinstance(ret, np.ndarray)
        assert ret.shape == (0,)

        ret = a.searchsorted(np.array([3]))
        assert ret == 2
        assert isinstance(ret, np.ndarray)

        ret = a.searchsorted(np.array([[2, 3]]))
        assert (ret == [1, 2]).all()
        assert ret.shape == (1, 2)

        ret = a.searchsorted(3, side='right')
        assert ret == 3
        assert isinstance(ret, np.generic)

        assert a.searchsorted(3.1) == 3
        assert a.searchsorted(3.9) == 3

        exc = raises(ValueError, a.searchsorted, 3, side=None)
        assert str(exc.value) == "expected nonempty string for keyword 'side'"
        exc = raises(ValueError, a.searchsorted, 3, side='')
        assert str(exc.value) == "expected nonempty string for keyword 'side'"
        exc = raises(ValueError, a.searchsorted, 3, side=2)
        assert str(exc.value) == "expected nonempty string for keyword 'side'"

        ret = a.searchsorted([-10, 10, 2, 3])
        assert (ret == [0, 5, 1, 2]).all()

        import sys
        if '__pypy__' in sys.builtin_module_names:
            raises(NotImplementedError, "a.searchsorted(3, sorter=range(6))")
