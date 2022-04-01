from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestNumSupport(BaseNumpyAppTest):
    def test_zeros(self):
        from numpy import zeros
        a = zeros(3)
        assert len(a) == 3
        assert a[0] == a[1] == a[2] == 0

    def test_empty(self):
        from numpy import empty
        import gc
        for i in range(1000):
            a = empty(3)
            assert len(a) == 3
            if not (a[0] == a[1] == a[2] == 0):
                break     # done
            a[0] = 1.23
            a[1] = 4.56
            a[2] = 7.89
            del a
            gc.collect()
        else:
            raise AssertionError(
                "empty() returned a zeroed out array every time")

    def test_where(self):
        from numpy import where, ones, zeros, array
        a = [1, 2, 3, 0, -3]
        a = where(array(a) > 0, ones(5), zeros(5))
        assert (a == [1, 1, 1, 0, 0]).all()

    def test_where_differing_dtypes(self):
        from numpy import array, ones, zeros, where
        a = [1, 2, 3, 0, -3]
        a = where(array(a) > 0, ones(5, dtype=int), zeros(5, dtype=float))
        assert (a == [1, 1, 1, 0, 0]).all()

    def test_where_broadcast(self):
        from numpy import array, where
        a = where(array([[1, 2, 3], [4, 5, 6]]) > 3, [1, 1, 1], 2)
        assert (a == [[2, 2, 2], [1, 1, 1]]).all()
        a = where(True, [1, 1, 1], 2)
        assert (a == [1, 1, 1]).all()

    def test_where_errors(self):
        from numpy import where, array
        raises(ValueError, "where([1, 2, 3], [3, 4, 5])")
        raises(ValueError, "where([1, 2, 3], [3, 4, 5], [6, 7])")
        assert where(True, 1, 2) == array(1)
        assert where(False, 1, 2) == array(2)
        assert (where(True, [1, 2, 3], 2) == [1, 2, 3]).all()
        assert (where(False, 1, [1, 2, 3]) == [1, 2, 3]).all()
        assert (where([1, 2, 3], True, False) == [True, True, True]).all()

    def test_where_1_arg(self):
        from numpy import where, array

        result = where([1,0,1])

        assert isinstance(result, tuple)
        assert len(result) == 1
        assert (result[0] == array([0, 2])).all()

    def test_where_1_arg_2d(self):
        from numpy import where, array

        result = where([[1,0,1],[2,-1,-1]])

        assert isinstance(result, tuple)
        assert len(result) == 2
        assert (result[0] == array([0, 0, 1, 1, 1])).all()
        assert (result[1] == array([0, 2, 0, 1, 2])).all()

    def test_where_invalidates(self):
        from numpy import where, ones, zeros, array
        a = array([1, 2, 3, 0, -3])
        b = where(a > 0, ones(5), zeros(5))
        a[0] = 0
        assert (b == [1, 1, 1, 0, 0]).all()

    def test_dot_basic(self):
        from numpy import array, dot, arange
        a = array(range(5))
        assert dot(a, a) == 30.0

        a = array(range(5))
        assert a.dot(range(5)) == 30
        assert dot(range(5), range(5)) == 30
        assert (dot(5, [1, 2, 3]) == [5, 10, 15]).all()

        a = arange(12).reshape(3, 4)
        b = arange(12).reshape(4, 3)
        c = a.dot(b)
        assert (c == [[ 42, 48, 54], [114, 136, 158], [186, 224, 262]]).all()
        c = a.dot(b.astype(float))
        assert (c == [[ 42, 48, 54], [114, 136, 158], [186, 224, 262]]).all()
        c = a.astype(float).dot(b)
        assert (c == [[ 42, 48, 54], [114, 136, 158], [186, 224, 262]]).all()

        a = arange(24).reshape(2, 3, 4)
        raises(ValueError, "a.dot(a)")
        b = a[0, :, :].T
        #Superfluous shape test makes the intention of the test clearer
        assert a.shape == (2, 3, 4)
        assert b.shape == (4, 3)
        c = dot(a, b)
        assert (c == [[[14, 38, 62], [38, 126, 214], [62, 214, 366]],
                      [[86, 302, 518], [110, 390, 670], [134, 478, 822]]]).all()
        c = dot(a, b[:, 2])
        assert (c == [[62, 214, 366], [518, 670, 822]]).all()
        a = arange(3*2*6).reshape((3,2,6))
        b = arange(3*2*6)[::-1].reshape((2,6,3))
        assert dot(a, b)[2,0,1,2] == 1140
        assert (dot([[1,2],[3,4]],[5,6]) == [17, 39]).all()

    def test_dot_constant(self):
        from numpy import array, dot
        a = array(range(5))
        b = a.dot(2.5)
        for i in xrange(5):
            assert b[i] == 2.5 * a[i]
        c = dot(4, 3.0)
        assert c == 12.0
        c = array(3.0).dot(array(4))
        assert c == 12.0

    def test_dot_out(self):
        from numpy import arange, dot
        a = arange(12).reshape(3, 4)
        b = arange(12).reshape(4, 3)
        out = arange(9).reshape(3, 3)
        c = dot(a, b, out=out)
        assert (c == out).all()
        assert (c == [[42, 48, 54], [114, 136, 158], [186, 224, 262]]).all()
        out = arange(9, dtype=float).reshape(3, 3)
        exc = raises(ValueError, dot, a, b, out)
        assert exc.value[0] == ('output array is not acceptable (must have the '
                                'right type, nr dimensions, and be a C-Array)')

    def test_choose_basic(self):
        from numpy import array
        a, b, c = array([1, 2, 3]), array([4, 5, 6]), array([7, 8, 9])
        r = array([2, 1, 0]).choose([a, b, c])
        assert (r == [7, 5, 3]).all()

    def test_choose_broadcast(self):
        from numpy import array
        a, b, c = array([1, 2, 3]), [4, 5, 6], 13
        r = array([2, 1, 0]).choose([a, b, c])
        assert (r == [13, 5, 3]).all()

    def test_choose_out(self):
        from numpy import array
        a, b, c = array([1, 2, 3]), [4, 5, 6], 13
        r = array([2, 1, 0]).choose([a, b, c], out=None)
        assert (r == [13, 5, 3]).all()
        assert (a == [1, 2, 3]).all()
        r = array([2, 1, 0]).choose([a, b, c], out=a)
        assert (r == [13, 5, 3]).all()
        assert (a == [13, 5, 3]).all()

    def test_choose_modes(self):
        from numpy import array
        a, b, c = array([1, 2, 3]), [4, 5, 6], 13
        raises(ValueError, "array([3, 1, 0]).choose([a, b, c])")
        raises(ValueError, "array([3, 1, 0]).choose([a, b, c], mode='raises')")
        raises(ValueError, "array([3, 1, 0]).choose([])")
        raises(ValueError, "array([-1, -2, -3]).choose([a, b, c])")
        r = array([4, 1, 0]).choose([a, b, c], mode='clip')
        assert (r == [13, 5, 3]).all()
        r = array([4, 1, 0]).choose([a, b, c], mode='wrap')
        assert (r == [4, 5, 3]).all()

    def test_choose_dtype(self):
        from numpy import array
        a, b, c = array([1.2, 2, 3]), [4, 5, 6], 13
        r = array([2, 1, 0]).choose([a, b, c])
        assert r.dtype == float

    def test_choose_dtype_out(self):
        from numpy import array
        a, b, c = array([1, 2, 3]), [4, 5, 6], 13
        x = array([0, 0, 0], dtype='i2')
        r = array([2, 1, 0]).choose([a, b, c], out=x)
        assert r.dtype == 'i2'

    def test_put_basic(self):
        from numpy import arange, array
        a = arange(5)
        a.put([0, 2], [-44, -55])
        assert (a == array([-44, 1, -55, 3, 4])).all()
        a = arange(5)
        a.put([3, 4], 9)
        assert (a == array([0, 1, 2, 9, 9])).all()
        a = arange(5)
        a.put(1, [7, 8])
        assert (a == array([0, 7, 2, 3, 4])).all()

    def test_put_modes(self):
        from numpy import array, arange
        a = arange(5)
        a.put(22, -5, mode='clip')
        assert (a == array([0, 1, 2, 3, -5])).all()
        a = arange(5)
        a.put(22, -5, mode='wrap')
        assert (a == array([0, 1, -5, 3, 4])).all()
        raises(IndexError, "arange(5).put(22, -5, mode='raise')")
        raises(IndexError, "arange(5).put(22, -5, mode=2)")  # raise
        a.put(22, -10, mode='wrongmode_starts_with_w_so_wrap')
        assert (a == array([0, 1, -10, 3, 4])).all()
        a.put(22, -15, mode='cccccccc')
        assert (a == array([0, 1, -10, 3, -15])).all()
        a.put(23, -1, mode=1)  # wrap
        assert (a == array([0, 1, -10, -1, -15])).all()
        raises(TypeError, "arange(5).put(22, -5, mode='zzzz')")  # unrecognized mode
