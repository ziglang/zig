# -*- encoding: utf-8 -*-

from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestArrayBroadcast(BaseNumpyAppTest):
    def test_broadcast_for_row_and_column(self):
        import numpy as np
        x = np.array([[1], [2], [3]])
        y = np.array([4, 5])
        b = list(np.broadcast(x, y))
        assert b == [(1, 4), (1, 5), (2, 4), (2, 5), (3, 4), (3, 5)]

    def test_broadcast_properties(self):
        import numpy as np
        x = np.array([[1], [2], [3]])
        y = np.array([4, 5])
        b = np.broadcast(x, y)

        assert b.shape == (3, 2)
        assert b.size == 6
        assert b.index == 0

        b.next()
        b.next()

        assert b.shape == (3, 2)
        assert b.size == 6
        assert b.index == 2

    def test_broadcast_from_doctest(self):
        """
        Test from numpy.broadcast doctest.
        """
        import numpy as np
        x = np.array([[1], [2], [3]])
        y = np.array([4, 5, 6])
        reference = np.array([[5., 6., 7.],
                              [6., 7., 8.],
                              [7., 8., 9.]])

        b = np.broadcast(x, y)
        out = np.empty(b.shape)
        out.flat = [u + v for (u, v) in b]

        assert (reference == out).all()
        assert out.dtype == reference.dtype
        assert b.shape == reference.shape

    def test_broadcast_linear(self):
        import numpy as np
        x = np.array([1, 2, 3])
        y = np.array([4, 5, 6])
        b = list(np.broadcast(x, y))
        assert b == [(1, 4), (2, 5), (3, 6)]
        assert b[0][0].dtype == x.dtype

    def test_broadcast_failures(self):
        import numpy as np
        import sys
        x = np.array([1, 2, 3])
        y = np.array([4, 5])
        raises(ValueError, np.broadcast, x, y)
        a = np.empty(2**16,dtype='int8')
        a = a.reshape(-1, 1, 1, 1)
        b = a.reshape(1, -1, 1, 1)
        c = a.reshape(1, 1, -1, 1)
        d = a.reshape(1, 1, 1, -1)
        exc = raises(ValueError, np.broadcast, a, b, c, d)
        assert exc.value[0] == ('broadcast dimensions too large.')

    def test_broadcast_3_args(self):
        import numpy as np
        x = np.array([[[1]], [[2]], [[3]]])
        y = np.array([[[40], [50]]])
        z = np.array([[[700, 800]]])

        b = list(np.broadcast(x, y, z))

        assert b == [(1, 40, 700), (1, 40, 800), (1, 50, 700), (1, 50, 800),
                     (2, 40, 700), (2, 40, 800), (2, 50, 700), (2, 50, 800),
                     (3, 40, 700), (3, 40, 800), (3, 50, 700), (3, 50, 800)]

    def test_number_of_arguments(self):
        """
        Test from numpy unit tests.
        """
        import numpy as np
        arr = np.empty((5,))
        for j in range(35):
            arrs = [arr] * j
            if j < 2 or j > 32:
                exc = raises(ValueError, np.broadcast, *arrs)
                assert exc.value[0] == ('Need at least two and fewer than (32) array objects.')
            else:
                mit = np.broadcast(*arrs)
                assert mit.numiter == j
