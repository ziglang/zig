

class AppTestMinimal:
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_newmemoryview(self):
        from __pypy__ import newmemoryview
        b = bytearray(12)
        # The format can be anything, we only verify shape, strides, and itemsize
        m = newmemoryview(memoryview(b), itemsize=2, format='T{<h:a}', shape=(2, 3))
        assert m.strides == (6, 2)
        m = newmemoryview(memoryview(b), 2, 'T{<h:a}', shape=(2, 3),
                          strides=(6, 2))
        assert m.strides == (6, 2)
        assert m.format == 'T{<h:a}'
        assert m.itemsize == 2

    def test_empty(self):
        from __pypy__ import newmemoryview
        b = bytearray(0)
        m = newmemoryview(memoryview(b), 0, 'B', (42,))
        assert m.tobytes() == b''
        assert m.shape == (42,)
        assert m.strides == (0,)
        with raises(ValueError):
            newmemoryview(memoryview(b), 0, 'B')

    def test_strided1d(self):
        from __pypy__ import newmemoryview
        b = bytearray(b'abcdefghijkl')
        m = newmemoryview(memoryview(b), itemsize=1, format='B', shape=[6], strides=[2])
        assert m.strides == (2,)
        assert m.shape == (6,)
        assert m.tobytes() == b'acegik'
        assert m.tolist() == [ord('a'), ord('c'), ord('e'),
                              ord('g'), ord('i'), ord('k')]

    def test_strided2d(self):
        from __pypy__ import newmemoryview
        b = bytearray(b'abcdefghijkl' * 2)
        m = newmemoryview(memoryview(b), itemsize=1, format='B', shape=[6, 2], strides=[4, 2])
        assert m.strides == (4, 2)
        assert m.shape == (6, 2)
        assert m.tobytes() == b'acegik' * 2
        assert m.tolist() == [[ord('a'), ord('c')], [ord('e'),
                              ord('g')], [ord('i'), ord('k')]] * 2

    def test_bufferable(self):
        from __pypy__ import bufferable, newmemoryview
        class B(bufferable.bufferable):
            def __init__(self):
                self.data = bytearray(b'abc')

            def __buffer__(self, flags):
                return newmemoryview(memoryview(self.data), 1, 'B')


        obj = B()
        buf = memoryview(obj)
        v = obj.data[2]
        assert buf[2] == v

    def test_nbytes(self):
        from __pypy__ import newmemoryview
        b = bytearray(b'abcdefgh')
        m = newmemoryview(memoryview(b), 8, '<d')
        print(m.nbytes)
        assert m.nbytes == 8
