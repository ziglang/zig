import sys
import pytest


class AppTestArray(object):
    spaceconfig = {'usemodules': ['array', 'struct', 'binascii']}

    def setup_class(cls):
        cls.w_array = cls.space.appexec([], """():
            import array
            return array.array
        """)
        cls.w_tempfile = cls.space.wrap(
            str(pytest.ensuretemp('array').join('tmpfile')))
        cls.w_maxint = cls.space.wrap(sys.maxint)

    def test_ctor(self):
        assert len(self.array('i')) == 0

        raises(TypeError, self.array, 'hi')
        raises(TypeError, self.array, 1)
        raises(ValueError, self.array, 'x')

        a = self.array('u')
        raises(TypeError, a.append, 7)
        raises(TypeError, a.append, 'hi')
        a.append('h')
        assert a[0] == 'h'
        assert type(a[0]) is str
        assert len(a) == 1

        a = self.array('i', (1, 2, 3))
        b = self.array('h', (1, 2, 3))
        assert a == b

        for tc in 'bhilBHILQqfd':
            assert self.array(tc).typecode == tc
            raises(TypeError, self.array, tc, None)

        a = self.array('i', (1, 2, 3))
        b = self.array('h', a)
        assert list(b) == [1, 2, 3]

    def test_value_range(self):
        import sys
        values = (-129, 128, -128, 127, 0, 255, -1, 256,
                  -32768, 32767, -32769, 32768, 65535, 65536,
                  -2147483647, -2147483648, 2147483647, 4294967295, 4294967296,
                  )
        for bb in (8, 16, 32, 64, 128, 256, 512, 1024):
            for b in (bb - 1, bb, bb + 1):
                values += (2 ** b, 2 ** b + 1, 2 ** b - 1,
                           -2 ** b, -2 ** b + 1, -2 ** b - 1)

        for tc, ok, pt in (('b', (  -128,    34,   127),  int),
                           ('B', (     0,    23,   255),  int),
                           ('h', (-32768, 30535, 32767),  int),
                           ('H', (     0, 56783, 65535),  int),
                           ('i', (-32768, 30535, 32767),  int),
                           ('I', (     0, 56783, 65535), int),
                           ('l', (-2 ** 32 // 2, 34, 2 ** 32 // 2 - 1),  int),
                           ('L', (0, 3523532, 2 ** 32 - 1), int),
                           ):
            a = self.array(tc, ok)
            assert len(a) == len(ok)
            for v in ok:
                a.append(v)
            for i, v in enumerate(ok * 2):
                assert a[i] == v
                assert type(a[i]) is pt or (
                    # A special case: we return ints in Array('I') on 64-bits,
                    # and in Array('L') on 64-bit Windows,
                    # whereas CPython returns longs.  The difference is
                    # probably acceptable.
                    (tc == 'I' or tc == 'L' and sys.platform == 'win32') and
                    sys.maxint > 2147483647 and type(a[i]) is int)
            for v in ok:
                a[1] = v
                assert a[0] == ok[0]
                assert a[1] == v
                assert a[2] == ok[2]
            assert len(a) == 2 * len(ok)
            for v in values:
                try:
                    a[1] = v
                    assert a[0] == ok[0]
                    assert a[1] == v
                    assert a[2] == ok[2]
                except OverflowError:
                    pass

        for tc in 'BHILQ':
            a = self.array(tc)
            itembits = a.itemsize * 8
            vals = [0, 2 ** itembits - 1]
            a.fromlist(vals)
            assert a.tolist() == vals

            a = self.array(tc.lower())
            vals = [-1 * (2 ** itembits) // 2,  (2 ** itembits) // 2 - 1]
            a.fromlist(vals)
            assert a.tolist() == vals

    def test_float(self):
        values = [0, 1, 2.5, -4.25]
        for tc in 'fd':
            a = self.array(tc, values)
            assert len(a) == len(values)
            for i, v in enumerate(values):
                assert a[i] == v
                assert type(a[i]) is float
            a[1] = 10.125
            assert a[0] == 0
            assert a[1] == 10.125
            assert a[2] == 2.5
            assert len(a) == len(values)

    def test_nan(self):
        for tc in 'fd':
            a = self.array(tc, [float('nan')])
            b = self.array(tc, [float('nan')])
            assert not a == b
            assert a != b
            assert not a > b
            assert not a >= b
            assert not a < b
            assert not a <= b
            assert a.count(float('nan')) == 0

    def test_itemsize(self):
        for t in 'bB':
            assert(self.array(t).itemsize >= 1)
        for t in 'uhHiI':
            assert(self.array(t).itemsize >= 2)
        for t in 'lLf':
            assert(self.array(t).itemsize >= 4)
        for t in 'd':
            assert(self.array(t).itemsize >= 8)
        for t in 'Qq':
            assert(self.array(t).itemsize >= 8)

        inttypes = 'bhil'
        for t in inttypes:
            a = self.array(t, [1, 2, 3])
            b = a.itemsize
            for v in (-2 ** (8 * b) // 2, 2 ** (8 * b) // 2 - 1):
                a[1] = v
                assert a[0] == 1 and a[1] == v and a[2] == 3
            raises(OverflowError, a.append, -2 ** (8 * b) // 2 - 1)
            raises(OverflowError, a.append, 2 ** (8 * b) // 2)

            a = self.array(t.upper(), [1, 2, 3])
            b = a.itemsize
            for v in (0, 2 ** (8 * b) - 1):
                a[1] = v
                assert a[0] == 1 and a[1] == v and a[2] == 3
            raises(OverflowError, a.append, -1)
            raises(OverflowError, a.append, 2 ** (8 * b))

    def test_errormessage(self):
        a = self.array("L", [1, 2, 3])
        excinfo = raises(TypeError, "a[0] = 'abc'")
        assert str(excinfo.value) == "array item must be integer"

    def test_fromstring(self):
        a = self.array('b')
        assert not hasattr("a", "fromstring")

    def test_frombytes(self):
        import sys
        for t in 'bBhHiIlLfd':
            a = self.array(t)
            a.frombytes(b'\x00' * a.itemsize * 2)
            assert len(a) == 2 and a[0] == 0 and a[1] == 0
            if a.itemsize > 1:
                raises(ValueError, a.frombytes, b'\x00' * (a.itemsize - 1))
                raises(ValueError, a.frombytes, b'\x00' * (a.itemsize + 1))
                raises(ValueError, a.frombytes, b'\x00' * (2 * a.itemsize - 1))
                raises(ValueError, a.frombytes, b'\x00' * (2 * a.itemsize + 1))
            b = self.array(t, b'\x00' * a.itemsize * 2)
            assert len(b) == 2 and b[0] == 0 and b[1] == 0
            if t in 'bB':
                old_items = a.tolist()
                try:
                    a.frombytes(a)
                except BufferError:
                    # CPython behavior:
                    # "cannot resize an array that is exporting buffers"
                    # This is the general error we get when we try to
                    # resize the array while a buffer to that array is
                    # alive.
                    assert a.tolist() == old_items
                else:
                    # PyPy behavior: we can't reasonably implement that.
                    # It's harder to crash PyPy in this case, but not
                    # impossible, because of get_raw_address().  Too
                    # bad I suppose.
                    assert a.tolist() == old_items * 2
            else:
                if '__pypy__' in sys.modules:
                    old_items = a.tolist()
                    a.frombytes(a)
                    assert a.tolist() == old_items * 2
                else:
                    raises(TypeError, a.frombytes, a)

    def test_fromfile(self):
        def myfile(c, s):
            f = open(self.tempfile, 'wb')
            f.write(c * s)
            f.close()
            return open(self.tempfile, 'rb')

        f = myfile(b'\x00', 100)
        for t in 'bBhHiIlLfd':
            a = self.array(t)
            a.fromfile(f, 2)
            assert len(a) == 2 and a[0] == 0 and a[1] == 0

        a = self.array('b')
        a.fromfile(myfile(b'\x01', 20), 2)
        assert len(a) == 2 and a[0] == 1 and a[1] == 1

        a = self.array('h')
        a.fromfile(myfile(b'\x01', 20), 2)
        assert len(a) == 2 and a[0] == 257 and a[1] == 257

        a = self.array('h')
        raises(EOFError, a.fromfile, myfile(b'\x01', 2), 2)
        assert len(a) == 1 and a[0] == 257

        a = self.array('h')
        raises(ValueError, a.fromfile, myfile(b'\x01', 3), 2)
        # ValueError: bytes length not a multiple of item size
        assert len(a) == 0

    def test_fromfile_no_warning(self):
        import warnings
        # check that fromfile defers to frombytes, not fromstring
        class FakeF(object):
            def read(self, n):
                return b"a" * n
        a = self.array('b')
        with warnings.catch_warnings(record=True) as w:
            # Cause all warnings to always be triggered.
            warnings.simplefilter("always")
            a.fromfile(FakeF(), 4)
            assert len(w) == 0

    def test_fromlist(self):
        a = self.array('b')
        raises(OverflowError, a.fromlist, [1, 2, 400])
        assert len(a) == 0

        raises(OverflowError, a.extend, [1, 2, 400])
        assert len(a) == 2 and a[0] == 1 and a[1] == 2

        raises(OverflowError, self.array, 'b', [1, 2, 400])

        a = self.array('b', [1, 2])
        assert len(a) == 2 and a[0] == 1 and a[1] == 2

        a = self.array('b')
        raises(TypeError, a.fromlist, (1, 2, 400))

        raises(OverflowError, a.extend, (1, 2, 400))
        assert len(a) == 2 and a[0] == 1 and a[1] == 2

        raises(TypeError, a.extend, self.array('i', (7, 8)))
        assert len(a) == 2 and a[0] == 1 and a[1] == 2

        def gen():
            for i in range(4):
                yield i + 10
        a = self.array('i', gen())
        assert len(a) == 4 and a[2] == 12

        raises(OverflowError, self.array, 'b', (1, 2, 400))

        a = self.array('b', (1, 2))
        assert len(a) == 2 and a[0] == 1 and a[1] == 2

        a.extend(a)
        assert repr(a) == "array('b', [1, 2, 1, 2])"

    def test_fromunicode(self):
        raises(ValueError, self.array('i').fromunicode, u'hi')
        a = self.array('u')
        a.fromunicode(u'hi')
        assert len(a) == 2 and a[0] == 'h' and a[1] == 'i'

        b = self.array('u', u'hi')
        assert len(b) == 2 and b[0] == 'h' and b[1] == 'i'

    def test_setslice_to_extend(self):
        a = self.array('i')
        a[0:1] = self.array('i', [9])
        a[1:5] = self.array('i', [99])
        assert list(a) == [9, 99]

    def test_sequence(self):
        a = self.array('i', [1, 2, 3, 4])
        assert len(a) == 4
        assert a[0] == 1 and a[1] == 2 and a[2] == 3 and a[3] == 4
        assert a[-4] == 1 and a[-3] == 2 and a[-2] == 3 and a[-1] == 4
        a[-2] = 5
        assert a[0] == 1 and a[1] == 2 and a[2] == 5 and a[3] == 4

        for i in (4, -5):
            raises(IndexError, a.__getitem__, i)

        b = a[0:2]
        assert len(b) == 2 and b[0] == 1 and b[1] == 2
        b[0] = 6
        assert len(b) == 2 and b[0] == 6 and b[1] == 2
        assert a[0] == 1 and a[1] == 2 and a[2] == 5 and a[3] == 4
        assert a.itemsize == b.itemsize

        b = a[0:100]
        assert len(b) == 4
        assert b[0] == 1 and b[1] == 2 and b[2] == 5 and b[3] == 4

        l1 = [2 * i + 1 for i in range(10)]
        a1 = self.array('i', l1)
        for start in range(10):
            for stop in range(start, 10):
                for step in range(1, 10):
                    l2 = l1[start:stop:step]
                    a2 = a1[start:stop:step]
                    assert len(l2) == len(a2)
                    for i in range(len(l2)):
                        assert l2[i] == a2[i]

        a = self.array('i', [1, 2, 3, 4])
        a[1:3] = self.array('i', [5, 6])
        assert len(a) == 4
        assert a[0] == 1 and a[1] == 5 and a[2] == 6 and a[3] == 4
        a[0:-1:2] = self.array('i', [7, 8])
        assert a[0] == 7 and a[1] == 5 and a[2] == 8 and a[3] == 4

        raises(ValueError, "a[1:2:4] = self.array('i', [5, 6, 7])")
        raises(TypeError, "a[1:3] = self.array('I', [5, 6])")
        raises(TypeError, "a[1:3] = [5, 6]")

    def test_resizingslice(self):
        a = self.array('i', [1, 2, 3])
        a[1:2] = self.array('i', [7, 8, 9])
        assert repr(a) == "array('i', [1, 7, 8, 9, 3])"
        a[1:2] = self.array('i', [10])
        assert repr(a) == "array('i', [1, 10, 8, 9, 3])"
        a[1:2] = self.array('i')
        assert repr(a) == "array('i', [1, 8, 9, 3])"

        a[1:3] = self.array('i', [11, 12, 13])
        assert repr(a) == "array('i', [1, 11, 12, 13, 3])"
        a[1:3] = self.array('i', [14])
        assert repr(a) == "array('i', [1, 14, 13, 3])"
        a[1:3] = self.array('i')
        assert repr(a) == "array('i', [1, 3])"

        a[1:1] = self.array('i', [15, 16, 17])
        assert repr(a) == "array('i', [1, 15, 16, 17, 3])"
        a[1:1] = self.array('i', [18])
        assert repr(a) == "array('i', [1, 18, 15, 16, 17, 3])"
        a[1:1] = self.array('i')
        assert repr(a) == "array('i', [1, 18, 15, 16, 17, 3])"

        a[:] = self.array('i', [20, 21, 22])
        assert repr(a) == "array('i', [20, 21, 22])"

    def test_reversingslice(self):
        a = self.array('i', [22, 21, 20])
        assert repr(a[::-1]) == "array('i', [20, 21, 22])"
        assert repr(a[2:1:-1]) == "array('i', [20])"
        assert repr(a[2:-1:-1]) == "array('i')"
        assert repr(a[-1:0:-1]) == "array('i', [20, 21])"
        del a

        for a in range(-4, 5):
            for b in range(-4, 5):
                for c in [-4, -3, -2, -1, 1, 2, 3, 4]:
                    lst = [1, 2, 3]
                    arr = self.array('i', lst)
                    assert repr(arr[a:b:c]) == \
                           repr(self.array('i', lst[a:b:c]))
                    for vals in ([4, 5], [6], []):
                        try:
                            ok = False
                            lst[a:b:c] = vals
                            ok = True
                            arr[a:b:c] = self.array('i', vals)
                            assert repr(arr) == repr(self.array('i', lst))
                        except ValueError:
                            assert not ok
                    del arr
        # make sure array.__del__ is called before the leak check
        import gc; gc.collect()

    def test_getslice_large_step(self):
        import sys
        a = self.array('b', [1, 2, 3])
        assert list(a[1::sys.maxsize]) == [2]

    def test_setslice_large_step(self):
        import sys
        a = self.array('b', [1, 2, 3])
        a[1::sys.maxsize] = self.array('b', [42])
        assert a.tolist() == [1, 42, 3]

    def test_toxxx(self):
        a = self.array('i', [1, 2, 3])
        l = a.tolist()
        assert type(l) is list and len(l) == 3
        assert a[0] == 1 and a[1] == 2 and a[2] == 3

        b = self.array('i', a.tobytes())
        assert len(b) == 3 and b[0] == 1 and b[1] == 2 and b[2] == 3

        a = self.array('i', [0, 0, 0])
        assert a.tobytes() == b'\x00' * 3 * a.itemsize
        s = self.array('i', [1, 2, 3]).tobytes()
        assert 0x00 in s
        assert 0x01 in s
        assert 0x02 in s
        assert 0x03 in s
        a = self.array('i', s)
        assert a[0] == 1 and a[1] == 2 and a[2] == 3

        from struct import unpack
        values = (-129, 128, -128, 127, 0, 255, -1, 256, -32760, 32760)
        s = self.array('i', values).tobytes()
        fmt = 'i' * len(values)
        a = unpack(fmt, s)
        assert a == values

        for tcodes, values in (('bhilfd', (-128, 127, 0, 1, 7, -10)),
                               ('BHILfd', (127, 0, 1, 7, 255, 169)),
                               ('hilHILfd', (32760, 30123, 3422, 23244))):
            for tc in tcodes:
                values += ((2 ** self.array(tc).itemsize) // 2 - 1, )
                s = self.array(tc, values).tobytes()
                a = unpack(tc * len(values), s)
                assert a == values

        f = open(self.tempfile, 'wb')
        self.array('b', (ord('h'), ord('i'))).tofile(f)
        f.close()
        assert open(self.tempfile, 'rb').readline() == b'hi'

        a = self.array('b')
        a.fromfile(open(self.tempfile, 'rb'), 2)
        assert repr(a) == "array('b', [104, 105])"

        raises(ValueError, self.array('i').tounicode)
        assert self.array('u', u'hello').tounicode() == u'hello'

    def test_empty_tostring(self):
        a = self.array('l')
        assert not hasattr(a, "tostring")

    def test_buffer(self):
        a = self.array('h', b'Hi')
        buf = memoryview(a)
        assert buf[0] == 26952
        raises(IndexError, 'buf[1]')
        assert buf.tobytes() == b'Hi'
        assert buf.tolist() == [26952]
        assert buf.format == 'h'
        assert buf.itemsize == 2
        assert buf.shape == (1,)
        assert buf.ndim == 1
        assert buf.strides == (2,)
        assert not buf.readonly

    def test_buffer_write(self):
        a = self.array('b', b'hello')
        buf = memoryview(a)
        try:
            buf[3] = b'L'
        except TypeError:
            skip("memoryview(array) returns a read-only buffer on CPython")
        assert a.tobytes() == b'helLo'

    def test_buffer_keepalive(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip("CPython: cannot resize an array that is exporting buffers")
        buf = memoryview(self.array('b', b'text'))
        assert buf[2] == ord('x')
        #
        a = self.array('b', b'foobarbaz')
        buf = memoryview(a)
        a.frombytes(b'some extra text')
        assert buf[:] == b'foobarbazsome extra text'

    def test_memview_multi_tobytes(self):
        a = self.array('i', list(b"abcdef"))
        m = memoryview(a)
        assert m.tobytes() == a.tobytes()

    def test_list_methods(self):
        assert repr(self.array('i')) == "array('i')"
        assert repr(self.array('i', [1, 2, 3])) == "array('i', [1, 2, 3])"
        assert repr(self.array('h')) == "array('h')"

        a = self.array('i', [1, 2, 3, 1, 2, 1])
        assert a.count(1) == 3
        assert a.count(2) == 2
        assert a.index(3) == 2
        assert a.index(2) == 1
        raises(ValueError, a.index, 10)

        a.reverse()
        assert repr(a) == "array('i', [1, 2, 1, 3, 2, 1])"

        b = self.array('i', [1, 2, 3, 1, 2])
        b.reverse()
        assert repr(b) == "array('i', [2, 1, 3, 2, 1])"

        a.remove(3)
        assert repr(a) == "array('i', [1, 2, 1, 2, 1])"
        a.remove(1)
        assert repr(a) == "array('i', [2, 1, 2, 1])"

        a.pop()
        assert repr(a) == "array('i', [2, 1, 2])"

        a.pop(1)
        assert repr(a) == "array('i', [2, 2])"

        a.pop(-2)
        assert repr(a) == "array('i', [2])"

        a.insert(1, 7)
        assert repr(a) == "array('i', [2, 7])"
        a.insert(0, 8)
        a.insert(-1, 9)
        assert repr(a) == "array('i', [8, 2, 9, 7])"

        a.insert(100, 10)
        assert repr(a) == "array('i', [8, 2, 9, 7, 10])"
        a.insert(-100, 20)
        assert repr(a) == "array('i', [20, 8, 2, 9, 7, 10])"

    def test_compare(self):
        class comparable(object):
            def __eq__(self, other):
                return True
        class incomparable(object):
            pass

        for v1, v2, tt in (([1, 2, 3], [1, 3, 2], 'bhilBHIL'),
                         ('abc', 'acb', 'u')):
            for t in tt:
                a = self.array(t, v1)
                b = self.array(t, v1)
                c = self.array(t, v2)

                assert (a == 7) is False
                assert (comparable() == a) is True
                assert (a == comparable()) is True
                assert (a == incomparable()) is False
                assert (incomparable() == a) is False

                assert (a == a) is True
                assert (a == b) is True
                assert (b == a) is True
                assert (a == c) is False
                assert (c == a) is False

                assert (a != a) is False
                assert (a != b) is False
                assert (b != a) is False
                assert (a != c) is True
                assert (c != a) is True

                assert (a < a) is False
                assert (a < b) is False
                assert (b < a) is False
                assert (a < c) is True
                assert (c < a) is False

                assert (a > a) is False
                assert (a > b) is False
                assert (b > a) is False
                assert (a > c) is False
                assert (c > a) is True

                assert (a <= a) is True
                assert (a <= b) is True
                assert (b <= a) is True
                assert (a <= c) is True
                assert (c <= a) is False

                assert (a >= a) is True
                assert (a >= b) is True
                assert (b >= a) is True
                assert (a >= c) is False
                assert (c >= a) is True

        a = self.array('i', [-1, 0, 1, 42, 0x7f])
        assert not a == 2*a
        assert a != 2*a
        assert a < 2*a
        assert a <= 2*a
        assert not a > 2*a
        assert not a >= 2*a

    def test_reduce(self):
        import pickle
        a = self.array('i', [1, 2, 3])
        s = pickle.dumps(a)
        b = pickle.loads(s)
        assert a == b

        a = self.array('l')
        s = pickle.dumps(a)
        b = pickle.loads(s)
        assert len(b) == 0 and b.typecode == 'l'

        a = self.array('i', [1, 2, 4])
        i = iter(a)
        #raises(TypeError, pickle.dumps, i)

    def test_copy_swap(self):
        a = self.array('i', [1, 2, 3])
        from copy import copy
        b = copy(a)
        a[1] = 7
        assert repr(b) == "array('i', [1, 2, 3])"

        for tc in 'bhilBHIL':
            a = self.array(tc, [1, 2, 3])
            a.byteswap()
            assert len(a) == 3
            assert a[0] == 1 * (256 ** (a.itemsize - 1))
            assert a[1] == 2 * (256 ** (a.itemsize - 1))
            assert a[2] == 3 * (256 ** (a.itemsize - 1))
            a.byteswap()
            assert len(a) == 3
            assert a[0] == 1
            assert a[1] == 2
            assert a[2] == 3

    def test_deepcopy(self):
        a = self.array('u', u'\x01\u263a\x00\ufeff')
        from copy import deepcopy
        b = deepcopy(a)
        assert a == b

    def test_addmul(self):
        a = self.array('i', [1, 2, 3])
        assert repr(a + a) == "array('i', [1, 2, 3, 1, 2, 3])"
        assert 2 * a == a + a
        assert a * 2 == a + a
        b = self.array('i', [4, 5, 6, 7])
        assert repr(a + b) == "array('i', [1, 2, 3, 4, 5, 6, 7])"
        assert repr(2 * self.array('i')) == "array('i')"
        assert repr(self.array('i') + self.array('i')) == "array('i')"

        a = self.array('i', [1, 2])
        assert type(a + a) is self.array
        assert type(a * 2) is self.array
        assert type(2 * a) is self.array
        b = a
        a += a
        assert repr(b) == "array('i', [1, 2, 1, 2])"
        b *= 3
        assert repr(a) == "array('i', [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2])"
        assert a == b
        a += self.array('i', (7,))
        assert repr(a) == "array('i', [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 7])"

        raises(MemoryError, "a * self.maxint")
        raises(MemoryError, "a *= self.maxint")

        raises(TypeError, "a = self.array('i') + 2")
        raises(TypeError, "self.array('i') + self.array('b')")
        a = self.array('i')
        raises(TypeError, "a += 7")

        # Calling __add__ directly raises TypeError in cpython but
        # returns NotImplemented in pypy if placed within a
        # try: except TypeError: construction.
        #
        #raises(TypeError, self.array('i').__add__, (2,))
        #raises(TypeError, self.array('i').__iadd__, (2,))
        #raises(TypeError, self.array('i').__add__, self.array('b'))

        class addable(object):
            def __add__(self, other):
                return "add"

            def __radd__(self, other):
                return "radd"

        assert addable() + self.array('i') == 'add'
        assert self.array('i') + addable() == 'radd'

        a = self.array('i')
        a += addable()
        assert a == 'radd'

        a = self.array('i', [1, 2])
        assert a * -1 == self.array('i')
        b = a
        a *= -1
        assert a == self.array('i')
        assert b == self.array('i')

        a = self.array('i')
        raises(TypeError, "a * 'hi'")
        raises(TypeError, "'hi' * a")
        raises(TypeError, "a *= 'hi'")

        class mulable(object):
            def __mul__(self, other):
                return "mul"

            def __rmul__(self, other):
                return "rmul"

        assert mulable() * self.array('i') == 'mul'
        assert self.array('i') * mulable() == 'rmul'

        a = self.array('i')
        a *= mulable()
        assert a == 'rmul'

    def test_delitem(self):
        a = self.array('i', [1, 2, 3])
        del a[1]
        assert repr(a) == "array('i', [1, 3])"

        a = self.array('i', [1, 2, 3, 4, 5])
        del a[1:3]
        assert repr(a) == "array('i', [1, 4, 5])"

        a = self.array('i', [1, 2, 3, 4, 5])
        del a[3:1]
        assert repr(a) == "array('i', [1, 2, 3, 4, 5])"

        del a[-100:1]
        assert repr(a) == "array('i', [2, 3, 4, 5])"

        del a[3:]
        assert repr(a) == "array('i', [2, 3, 4])"

        del a[-1:]
        assert repr(a) == "array('i', [2, 3])"

        del a[1:100]
        assert repr(a) == "array('i', [2])"

    def test_iter(self):
        a = self.array('i', [1, 2, 3])
        assert 1 in a
        b = self.array('i')
        for i in a:
            b.append(i)
        assert repr(b) == "array('i', [1, 2, 3])"
        assert hasattr(b, '__iter__')
        assert next(b.__iter__()) == 1

    def test_lying_iterable(self):
        class lier(object):
            def __init__(self, n):
                self.n = n

            def __len__(self):
                return 3

            def __next__(self):
                self.n -= 1
                if self.n < 0:
                    raise StopIteration
                return self.n

            def __iter__(self):
                return self

        assert len(lier(2)) == 3
        assert len(tuple(lier(2))) == 2
        a = self.array('i', lier(2))
        assert repr(a) == "array('i', [1, 0])"

        assert len(lier(5)) == 3
        assert len(tuple(lier(5))) == 5
        a = self.array('i', lier(5))
        assert repr(a) == "array('i', [4, 3, 2, 1, 0])"

    def test_type(self):
        for t in 'bBhHiIlLfduQq':
            assert type(self.array(t)) is self.array
            assert isinstance(self.array(t), self.array)

    def test_iterable(self):
        import collections
        for t in 'bBhHiIlLfduQq':
            assert isinstance(self.array(t), collections.Iterable)

    def test_subclass(self):
        assert len(self.array('b')) == 0

        a = self.array('i')
        a.append(7)
        assert len(a) == 1

        array = self.array

        class adder(array):
            def __getitem__(self, i):
                return array.__getitem__(self, i) + 1

        a = adder('i', (1, 2, 3))
        assert len(a) == 3
        assert a[0] == 2

    def test_subclass_new(self):
        array = self.array
        class Image(array):
            def __new__(cls, width, height, typecode='d'):
                self = array.__new__(cls, typecode, [0] * (width * height))
                self.width = width
                self.height = height
                return self

            def _index(self, x, y):
                x = min(max(x, 0), self.width-1)
                y = min(max(y, 0), self.height-1)
                return y * self.width + x

            def __getitem__(self, i):
                return array.__getitem__(self, self._index(*i))

            def __setitem__(self, i, val):
                return array.__setitem__(self, self._index(*i), val)

        img = Image(5, 10, 'B')
        for y in range(10):
            for x in range(5):
                img[x, y] = x * y
        for y in range(10):
            for x in range(5):
                assert img[x, y] == x * y

        assert img[3, 25] == 3 * 9

    def test_override_from(self):
        class mya(self.array):
            def fromlist(self, lst):
                self.append(7)

            def frombytes(self, lst):
                self.append(8)

            def fromunicode(self, lst):
                self.append('9')

            def extend(self, lst):
                self.append(10)

        assert repr(mya('u', 'hi')) == "mya('u', 'hi')"
        assert repr(mya('i', [1, 2, 3])) == "mya('i', [1, 2, 3])"
        assert repr(mya('i', (1, 2, 3))) == "mya('i', [1, 2, 3])"

        a = mya('i')
        a.fromlist([1, 2, 3])
        assert repr(a) == "mya('i', [7])"

        a = mya('b')
        a.frombytes(b'hi')
        assert repr(a) == "mya('b', [8])"

        a = mya('u')
        a.fromunicode('hi')
        assert repr(a) == "mya('u', '9')"

        a = mya('i')
        a.extend([1, 2, 3])
        assert repr(a) == "mya('i', [10])"

    def test_override_to(self):
        class mya(self.array):
            def tolist(self):
                return 'list'

            def tobytes(self):
                return 'str'

            def tounicode(self):
                return 'unicode'

        assert mya('i', [1, 2, 3]).tolist() == 'list'
        assert mya('u', 'hi').tobytes() == 'str'
        assert mya('u', 'hi').tounicode() == 'unicode'

        assert repr(mya('u', 'hi')) == "mya('u', 'hi')"
        assert repr(mya('i', [1, 2, 3])) == "mya('i', [1, 2, 3])"
        assert repr(mya('i', (1, 2, 3))) == "mya('i', [1, 2, 3])"

    def test_unicode_outofrange(self):
        input_unicode = u'\x01\u263a\x00\ufeff'
        a = self.array('u', input_unicode)
        b = self.array('u', input_unicode)
        b.byteswap()
        assert b[2] == u'\u0000'
        assert a != b
        if b.itemsize == 4:
            e = raises(ValueError, "b[0]")        # doesn't work
            assert str(e.value) == (
                "cannot operate on this array('u') because it contains"
                " character U+1000000 not in range [U+0000; U+10ffff]"
                " at index 0")
            assert str(b) == ("array('u', <character U+1000000 is not in"
                          " range [U+0000; U+10ffff]>)")
            raises(ValueError, b.tounicode)   # doesn't work
        elif b.itemsize == 2:
            assert b[0] == u'\u0100'
            byteswaped_unicode = u'\u0100\u3a26\x00\ufffe'
            assert str(b) == "array('u', %r)" % (byteswaped_unicode,)
            assert b.tounicode() == byteswaped_unicode
        assert str(a) == "array('u', %r)" % (input_unicode,)
        assert a.tounicode() == input_unicode

    def test_unicode_surrogate(self):
        a = self.array('u', u'\ud800')
        assert a[0] == u'\ud800'

    def test_weakref(self):
        import weakref
        a = self.array('u', 'Hi!')
        r = weakref.ref(a)
        assert r() is a

    def test_subclass_del(self):
        import array, gc, weakref
        l = []

        class A(array.array):
            pass

        a = A('d')
        a.append(3.0)
        r = weakref.ref(a, lambda a: l.append(a()))
        del a
        gc.collect(); gc.collect()   # XXX needs two of them right now...
        assert l
        assert l[0] is None or len(l[0]) == 0

    def test_assign_object_with_special_methods(self):
        from array import array

        class Num(object):
            def __float__(self):
                return 5.25

            def __int__(self):
                return 7

        class NotNum(object):
            pass

        class Silly(object):
            def __float__(self):
                return None

            def __int__(self):
                return None

        class OldNum:
            def __float__(self):
                return 6.25

            def __int__(self):
                return 8

        class OldNotNum:
            pass

        class OldSilly:
            def __float__(self):
                return None

            def __int__(self):
                return None

        for tc in 'bBhHiIlL':
            a = array(tc, [0])
            raises(TypeError, a.__setitem__, 0, 1.0)
            a[0] = 1
            a[0] = Num()
            assert a[0] == 7
            raises(TypeError, a.__setitem__, NotNum())
            a[0] = OldNum()
            assert a[0] == 8
            raises(TypeError, a.__setitem__, OldNotNum())
            raises(TypeError, a.__setitem__, Silly())
            raises(TypeError, a.__setitem__, OldSilly())

        for tc in 'fd':
            a = array(tc, [0])
            a[0] = 1.0
            a[0] = 1
            a[0] = Num()
            assert a[0] == 5.25
            raises(TypeError, a.__setitem__, NotNum())
            a[0] = OldNum()
            assert a[0] == 6.25
            raises(TypeError, a.__setitem__, OldNotNum())
            raises(TypeError, a.__setitem__, Silly())
            raises(TypeError, a.__setitem__, OldSilly())

        a = array('u', 'hi')
        a[0] = 'b'
        assert a[0] == 'b'

        a = array('u', u'hi')
        a[0] = u'b'
        assert a[0] == u'b'

    def test_bytearray(self):
        a = self.array('u', 'hi')
        b = self.array('u')
        b.frombytes(bytearray(a.tobytes()))
        assert a == b
        assert self.array('u', bytearray(a.tobytes())) == a

    def test_buffer_info(self):
        a = self.array('b', b'Hi!')
        bi = a.buffer_info()
        assert bi[0] != 0
        assert bi[1] == 3

    def test_array_reverse_slice_assign_self(self):
        a = self.array('b', range(4))
        a[::-1] = a
        assert a == self.array('b', [3, 2, 1, 0])

    def test_array_multiply(self):
        a = self.array('b', [0])
        b = a * 13
        assert b[12] == 0
        b = 13 * a
        assert b[12] == 0
        a *= 13
        assert a[12] == 0
        a = self.array('b', [1])
        b = a * 13
        assert b[12] == 1
        b = 13 * a
        assert b[12] == 1
        a *= 13
        assert a[12] == 1
        a = self.array('i', [0])
        b = a * 13
        assert b[12] == 0
        b = 13 * a
        assert b[12] == 0
        a *= 13
        assert a[12] == 0
        a = self.array('i', [1])
        b = a * 13
        assert b[12] == 1
        b = 13 * a
        assert b[12] == 1
        a *= 13
        assert a[12] == 1
        a = self.array('i', [0, 0])
        b = a * 13
        assert len(b) == 26
        assert b[22] == 0
        b = 13 * a
        assert len(b) == 26
        assert b[22] == 0
        a *= 13
        assert a[22] == 0
        assert len(a) == 26
        a = self.array('f', [-0.0])
        b = a * 13
        assert len(b) == 13
        assert str(b[12]) == "-0.0"
        a = self.array('d', [-0.0])
        b = a * 13
        assert len(b) == 13
        assert str(b[12]) == "-0.0"

    def test_getitem_only_ints(self):
        class MyInt(object):
            def __init__(self, x):
                self.x = x

            def __int__(self):
                return self.x

        a = self.array('i', [1, 2, 3, 4, 5, 6])
        raises(TypeError, "a[MyInt(0)]")
        raises(TypeError, "a[MyInt(0):MyInt(5)]")

    def test_fresh_array_buffer_bytes(self):
        assert bytes(memoryview(self.array('i'))) == b''

    def test_mview_slice_aswritebuf(self):
        import struct
        a = self.array('B', b'abcdef')
        view = memoryview(a)[1:5]
        struct.pack_into('>H', view, 1, 0x1234)
        assert a.tobytes() == b'ab\x12\x34ef'

    def test_subclass_repr(self):
        import array
        class subclass(self.array):
            pass
        assert repr(subclass('i')) == "subclass('i')"


class AppTestArrayReconstructor:
    spaceconfig = dict(usemodules=('array', 'struct'))

    def test_error(self):
        import array
        array_reconstructor = array._array_reconstructor
        UNKNOWN_FORMAT = -1
        raises(TypeError, array_reconstructor,
               "", "b", 0, b"")
        raises(TypeError, array_reconstructor,
               str, "b", 0, b"")
        raises(TypeError, array_reconstructor,
               array.array, "b", '', b"")
        raises(TypeError, array_reconstructor,
               array.array, "b", 0, "")
        raises(ValueError, array_reconstructor,
               array.array, "?", 0, b"")
        raises(ValueError, array_reconstructor,
               array.array, "b", UNKNOWN_FORMAT, b"")
        raises(ValueError, array_reconstructor,
               array.array, "b", 22, b"")
        raises(ValueError, array_reconstructor,
               array.array, "d", 16, b"a")

    def test_numbers(self):
        import array, struct
        array_reconstructor = array._array_reconstructor
        UNSIGNED_INT8 = 0
        SIGNED_INT8 = 1
        UNSIGNED_INT16_LE = 2
        UNSIGNED_INT16_BE = 3
        SIGNED_INT16_LE = 4
        SIGNED_INT16_BE = 5
        UNSIGNED_INT32_LE = 6
        UNSIGNED_INT32_BE = 7
        SIGNED_INT32_LE = 8
        SIGNED_INT32_BE = 9
        UNSIGNED_INT64_LE = 10
        UNSIGNED_INT64_BE = 11
        SIGNED_INT64_LE = 12
        SIGNED_INT64_BE = 13
        IEEE_754_FLOAT_LE = 14
        IEEE_754_FLOAT_BE = 15
        IEEE_754_DOUBLE_LE = 16
        IEEE_754_DOUBLE_BE = 17
        testcases = (
            (['B', 'H', 'I', 'L'], UNSIGNED_INT8, '=BBBB',
             [0x80, 0x7f, 0, 0xff]),
            (['b', 'h', 'i', 'l'], SIGNED_INT8, '=bbb',
             [-0x80, 0x7f, 0]),
            (['H', 'I', 'L'], UNSIGNED_INT16_LE, '<HHHH',
             [0x8000, 0x7fff, 0, 0xffff]),
            (['H', 'I', 'L'], UNSIGNED_INT16_BE, '>HHHH',
             [0x8000, 0x7fff, 0, 0xffff]),
            (['h', 'i', 'l'], SIGNED_INT16_LE, '<hhh',
             [-0x8000, 0x7fff, 0]),
            (['h', 'i', 'l'], SIGNED_INT16_BE, '>hhh',
             [-0x8000, 0x7fff, 0]),
            (['I', 'L'], UNSIGNED_INT32_LE, '<IIII',
             [1<<31, (1<<31)-1, 0, (1<<32)-1]),
            (['I', 'L'], UNSIGNED_INT32_BE, '>IIII',
             [1<<31, (1<<31)-1, 0, (1<<32)-1]),
            (['i', 'l'], SIGNED_INT32_LE, '<iii',
             [-1<<31, (1<<31)-1, 0]),
            (['i', 'l'], SIGNED_INT32_BE, '>iii',
             [-1<<31, (1<<31)-1, 0]),
            (['L'], UNSIGNED_INT64_LE, '<QQQQ',
             [1<<31, (1<<31)-1, 0, (1<<32)-1]),
            (['L'], UNSIGNED_INT64_BE, '>QQQQ',
             [1<<31, (1<<31)-1, 0, (1<<32)-1]),
            (['l'], SIGNED_INT64_LE, '<qqq',
             [-1<<31, (1<<31)-1, 0]),
            (['l'], SIGNED_INT64_BE, '>qqq',
             [-1<<31, (1<<31)-1, 0]),
            # The following tests for INT64 will raise an OverflowError
            # when run on a 32-bit machine. The tests are simply skipped
            # in that case.
            (['L'], UNSIGNED_INT64_LE, '<QQQQ',
             [1<<63, (1<<63)-1, 0, (1<<64)-1]),
            (['L'], UNSIGNED_INT64_BE, '>QQQQ',
             [1<<63, (1<<63)-1, 0, (1<<64)-1]),
            (['l'], SIGNED_INT64_LE, '<qqq',
             [-1<<63, (1<<63)-1, 0]),
            (['l'], SIGNED_INT64_BE, '>qqq',
             [-1<<63, (1<<63)-1, 0]),
            (['f'], IEEE_754_FLOAT_LE, '<ffff',
             [16711938.0, float('inf'), float('-inf'), -0.0]),
            (['f'], IEEE_754_FLOAT_BE, '>ffff',
             [16711938.0, float('inf'), float('-inf'), -0.0]),
            (['d'], IEEE_754_DOUBLE_LE, '<dddd',
             [9006104071832581.0, float('inf'), float('-inf'), -0.0]),
            (['d'], IEEE_754_DOUBLE_BE, '>dddd',
             [9006104071832581.0, float('inf'), float('-inf'), -0.0])
        )
        for testcase in testcases:
            valid_typecodes, mformat_code, struct_fmt, values = testcase
            arraystr = struct.pack(struct_fmt, *values)
            for typecode in valid_typecodes:
                try:
                    a = array.array(typecode, values)
                except OverflowError:
                    continue  # Skip this test case.
                b = array_reconstructor(
                    array.array, typecode, mformat_code, arraystr)
                assert a == b

    def test_unicode(self):
        import array
        array_reconstructor = array._array_reconstructor
        UTF16_LE = 18
        UTF16_BE = 19
        UTF32_LE = 20
        UTF32_BE = 21
        teststr = "Bonne Journ\xe9e \U0002030a\U00020347"
        testcases = (
            (UTF16_LE, "UTF-16-LE"),
            (UTF16_BE, "UTF-16-BE"),
            (UTF32_LE, "UTF-32-LE"),
            (UTF32_BE, "UTF-32-BE")
        )
        for testcase in testcases:
            mformat_code, encoding = testcase
            a = array.array('u', teststr)
            b = array_reconstructor(
                array.array, 'u', mformat_code, teststr.encode(encoding))
            assert a == b

    def test_iterate_iterator(self):
        import array
        it = iter(array.array('b'))
        assert list(it) == []
        assert list(iter(it)) == []

    def test_array_cannot_use_str(self):
        import array
        e = raises(TypeError, array.array, 'i', 'abcd')
        assert str(e.value) == ("cannot use a str to initialize an array"
                                " with typecode 'i'")
