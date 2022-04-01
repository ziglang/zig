import py
import pytest
import struct
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.buffer import BufferView
from pypy.conftest import option

class AppTestMemoryView(object):
    spaceconfig = dict(usemodules=['array', 'sys'])

    def test_basic(self):
        v = memoryview(b"abc")
        assert v.tobytes() == b"abc"
        assert len(v) == 3
        assert v[0] == ord('a')
        assert list(v) == [97, 98, 99]
        assert v.tolist() == [97, 98, 99]
        assert v[1] == ord("b")
        assert v[-1] == ord("c")
        exc = raises(TypeError, "v[1] = b'x'")
        assert str(exc.value) == "cannot modify read-only memory"
        assert v.readonly is True
        w = v[1:234]
        assert isinstance(w, memoryview)
        assert len(w) == 2
        exc = raises(TypeError, "memoryview('foobar')")

    def test_0d(self):
        v = memoryview(b'x').cast('B', ())
        assert len(v) == 1
        assert v.shape == ()
        assert v.strides == ()
        assert v.tobytes() == b'x'
        assert v.contiguous
        assert v.c_contiguous
        assert v.f_contiguous
        #assert v[()] == b'x'[0]

    def test_rw(self):
        data = bytearray(b'abcefg')
        v = memoryview(data)
        assert v.readonly is False
        v[0] = ord('z')
        assert data == bytearray(eval("b'zbcefg'"))
        v[1:4] = b'123'
        assert data == bytearray(eval("b'z123fg'"))
        v[0:3] = v[2:5]
        assert data == bytearray(eval("b'23f3fg'"))
        exc = raises(ValueError, "v[2:3] = b'spam'")
        #assert str(exc.value) == "cannot modify size of memoryview object"

    def test_extended_slice(self):
        data = bytearray(b'abcefg')
        v = memoryview(data)
        w = v[0:2:2]
        assert len(w) == 1
        assert list(w) == [97]
        v[::2] = b'ABC'
        assert data == bytearray(eval("b'AbBeCg'"))
        w = v[::2]
        assert not w.contiguous
        assert not w.c_contiguous
        assert not w.f_contiguous
        assert w.tobytes() == bytes(w) == b'ABC'
        w = v[::-2]
        assert w.tobytes() == bytes(w) == b'geb'

    def test_memoryview_attrs(self):
        b = b"a"*100
        v = memoryview(b)
        assert v.format == "B"
        assert v.itemsize == 1
        assert v.shape == (100,)
        assert v.ndim == 1
        assert v.strides == (1,)
        assert v.nbytes == 100
        assert v.obj is b

    def test_suboffsets(self):
        v = memoryview(b"a"*100)
        assert v.suboffsets == ()

    def test_compare(self):
        assert memoryview(b"abc") == b"abc"
        assert memoryview(b"abc") == bytearray(b"abc")
        assert memoryview(b"abc") != 3
        assert memoryview(b'ab') == b'ab'
        assert b'ab' == memoryview(b'ab')
        assert not (memoryview(b'ab') != b'ab')
        assert memoryview(b'ab') == memoryview(b'ab')
        assert not (memoryview(b'ab') != memoryview(b'ab'))
        assert memoryview(b'ab') != memoryview(b'abc')
        raises(TypeError, "memoryview(b'ab') <  memoryview(b'ab')")
        raises(TypeError, "memoryview(b'ab') <= memoryview(b'ab')")
        raises(TypeError, "memoryview(b'ab') >  memoryview(b'ab')")
        raises(TypeError, "memoryview(b'ab') >= memoryview(b'ab')")
        raises(TypeError, "memoryview(b'ab') <  memoryview(b'abc')")
        raises(TypeError, "memoryview(b'ab') <= memoryview(b'ab')")
        raises(TypeError, "memoryview(b'ab') >  memoryview(b'aa')")
        raises(TypeError, "memoryview(b'ab') >= memoryview(b'ab')")

    def test_array_buffer(self):
        import array
        b = memoryview(array.array("B", [1, 2, 3]))
        assert len(b) == 3
        assert b[0:3] == b"\x01\x02\x03"

    def test_nonzero(self):
        assert memoryview(b'\x00')
        assert not memoryview(b'')
        import array
        assert memoryview(array.array("B", [0]))
        assert not memoryview(array.array("B", []))

    def test_bytes(self):
        assert bytes(memoryview(b'hello')) == b'hello'

    def test_repr(self):
        assert repr(memoryview(b'hello')).startswith('<memory at 0x')

    def test_hash(self):
        assert hash(memoryview(b'hello')) == hash(b'hello')

    def test_weakref(self):
        import weakref
        m = memoryview(b'hello')
        weakref.ref(m)

    def test_getitem_only_ints(self):
        class MyInt(object):
          def __init__(self, x):
            self.x = x

          def __int__(self):
            return self.x

        buf = memoryview(b'hello world')
        raises(TypeError, "buf[MyInt(0)]")
        raises(TypeError, "buf[MyInt(0):MyInt(5)]")

    def test_release(self):
        v = memoryview(b"a"*100)
        v.release()
        raises(ValueError, len, v)
        raises(ValueError, v.tolist)
        raises(ValueError, v.tobytes)
        raises(ValueError, "v[0]")
        raises(ValueError, "v[0] = b'a'")
        raises(ValueError, "v.format")
        raises(ValueError, "v.nbytes")
        raises(ValueError, "v.itemsize")
        raises(ValueError, "v.ndim")
        raises(ValueError, "v.readonly")
        raises(ValueError, "v.shape")
        raises(ValueError, "v.strides")
        raises(ValueError, "v.suboffsets")
        raises(ValueError, "with v as cm: pass")
        raises(ValueError, "memoryview(v)")
        assert v == v
        assert v != memoryview(b"a"*100)
        assert v != b"a"*100
        assert "released memory" in repr(v)

    def test_context_manager(self):
        v = memoryview(b"a"*100)
        with v as cm:
            assert cm is v
        raises(ValueError, bytes, v)
        assert "released memory" in repr(v)

    def test_int_array_buffer(self):
        import array
        m = memoryview(array.array('i', list(range(10))))
        assert m.format == 'i'
        assert m.itemsize == 4
        assert len(m) == 10
        assert m.shape == (10,)
        assert len(m.tobytes()) == 40
        assert m.nbytes == 40
        assert m[0] == 0
        m[0] = 1
        assert m[0] == 1
        raises(NotImplementedError, m.__setitem__, (slice(0,1,1), slice(0,1,2)), 0)

    def test_int_array_slice(self):
        import array
        m = memoryview(array.array('i', list(range(10))))
        slice = m[2:8]
        assert slice.format == 'i'
        assert slice.itemsize == 4
        assert slice.ndim == 1
        assert slice.readonly is False
        assert slice.shape == (6,)
        assert slice.strides == (4,)
        assert slice.suboffsets == ()
        assert len(slice) == 6
        assert len(slice.tobytes()) == 24
        assert slice.nbytes == 24
        assert slice[0] == 2
        slice[0] = 1
        assert slice[0] == 1
        assert m[2] == 1

    def test_pypy_raw_address_base(self):
        import sys
        if '__pypy__' not in sys.modules:
            skip('PyPy-only test')
        a = memoryview(b"foobar")._pypy_raw_address()
        assert a != 0
        b = memoryview(bytearray(b"foobar"))._pypy_raw_address()
        assert b != 0

    def test_hex(self):
        assert memoryview(b"abc").hex() == u'616263'

    def test_hex_sep(self):
        res = memoryview(bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73])).hex('.')
        assert res == "73.61.6e.74.61.20.63.6c.61.75.73"
        with raises(ValueError):
            bytes([1, 2, 3]).hex("abc")
        assert memoryview(
                bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73])).hex('?', 4) == \
               "73616e?74612063?6c617573"

    def test_hex_long(self):
        x = b'01' * 100000
        m1 = memoryview(x)
        m2 = m1[::-1]
        assert m2.hex() == '3130' * 100000

    def test_hex_2(self):
        import array
        import sys
        m1 = memoryview(array.array('i', [1,2,3,4]))
        m2 = m1[::-1]
        if sys.byteorder == 'little':
            assert m2.hex() == "04000000030000000200000001000000"
        else:
            assert m2.hex() == "00000004000000030000000200000001"

    def test_memoryview_cast(self):
        m1 = memoryview(b'abcdefgh')
        m2 = m1.cast('I')
        m3 = m1.cast('h')
        assert list(m1) == [97, 98, 99, 100, 101, 102, 103, 104]
        assert list(m2) == [1684234849, 1751606885]
        assert list(m3) == [25185, 25699, 26213, 26727]
        assert m1[1] == 98
        assert m2[1] == 1751606885
        assert m3[1] == 25699
        assert list(m3[1:3]) == [25699, 26213]
        assert m3[1:3].tobytes() == b'cdef'
        assert len(m2) == 2
        assert len(m3) == 4
        assert (m2[-2], m2[-1]) == (1684234849, 1751606885)
        raises(IndexError, "m2[2]")
        raises(IndexError, "m2[-3]")
        assert list(m3[-99:3]) == [25185, 25699, 26213]
        assert list(m3[1:99]) == [25699, 26213, 26727]
        raises(IndexError, "m1[8]")
        raises(IndexError, "m1[-9]")
        assert m1[-8] == 97

    def test_memoryview_cast_extended_slicing(self):
        m1 = memoryview(b'abcdefgh')
        m3 = m1.cast('h')
        assert m3[1::2].tobytes() == b'cdgh'
        assert m3[::2].tobytes() == b'abef'
        assert m3[:2:2].tobytes() == b'ab'

    def test_memoryview_cast_setitem(self):
        data = bytearray(b'abcdefgh')
        m1 = memoryview(data)
        m2 = m1.cast('I')
        m3 = m1.cast('h')
        m1[2] = ord(b'C')
        assert m2[0] == 1682137697
        m3[1] = -9999
        assert data == bytearray(bytes([97, 98, 241, 216, 101, 102, 103, 104]))
        m3[1:3] = memoryview(b"pqrs").cast('h')
        assert data == bytearray(b'abpqrsgh')

    def test_memoryview_cast_setitem_extended_slicing(self):
        data = bytearray(b'abcdefghij')
        m3 = memoryview(data).cast('h')
        m3[1:5:2] = memoryview(b"xyXY").cast('h')
        assert data == bytearray(eval("b'abxyefXYij'"))

    def test_cast_and_slice(self):
        import array
        data = array.array('h', [1, 2])
        m = memoryview(memoryview(data).cast('B'))
        assert len(m[2:4:1]) == 2

    def test_cast_and_view(self):
        import array
        data = array.array('h', [1, 2])
        m1 = memoryview(data).cast('B')
        m2 = memoryview(m1)
        assert m2.strides == m1.strides
        assert m2.itemsize == m1.itemsize
        assert m2.shape == m1.shape

    def test_2d(self):
        import struct
        a = list(range(16))
        ba = bytearray(struct.pack("%di" % len(a), *a))
        m = memoryview(ba).cast("i", shape=(4, 4))
        assert m[2, 3] == 11
        m[2, 3] = -1
        assert m[2, 3] == -1
        raises(TypeError, m.__setitem__, (2, 3), 'a')
        # slices in 2d memoryviews are not supported at all
        raises(TypeError, m.__getitem__, (slice(None), 3))
        raises(TypeError, m.__setitem__, (slice(None), 3), 123)
        raises(NotImplementedError, m.__getitem__, (slice(0,1,1), slice(0,1,2)))
        raises(NotImplementedError, m.__setitem__, (slice(0,1,1), slice(0,1,2)), 123)

    def test_toreadonly(self):
        b = bytearray(b"abc")
        m = memoryview(b)
        m[0] = ord("c")
        m2 = m.toreadonly()
        assert m2.readonly
        with raises(TypeError):
            m2[0] = ord('x')
        assert m2.tolist() == m.tolist()
        m2.release()
        assert len(m.tolist()) == 3 # does not crash

    def test_toreadonly_slice_is_readonly(self):
        b = bytearray(b"abcdefghi")
        m = memoryview(b)
        m[0] = ord("c")
        m2 = m.toreadonly()
        m3 = m2[1:4]
        m3.readonly

class AppTestCtypes(object):
    spaceconfig = dict(usemodules=['sys', '_rawffi'])

    def test_cast_ctypes(self):
        import _rawffi, sys
        a = _rawffi.Array('i')(1)
        a[0] = 0x01234567
        m = memoryview(a).cast('B')
        if sys.byteorder == 'little':
            expected = 0x67, 0x45, 0x23, 0x01
        else:
            expected = 0x01, 0x23, 0x45, 0x67
        assert (m[0], m[1], m[2], m[3]) == expected
        a.free()

class MockBuffer(BufferView):
    def __init__(self, space, w_arr, w_dim, w_fmt, \
                 w_itemsize, w_strides, w_shape, w_obj=None):
        self.space = space
        self.w_obj = w_obj
        self.w_arr = w_arr
        self.arr = []
        self.ndim = space.int_w(w_dim)
        self.format = space.text_w(w_fmt)
        self.itemsize = space.int_w(w_itemsize)
        self.strides = []
        for w_i in w_strides.getitems_unroll():
            self.strides.append(space.int_w(w_i))
        self.shape = []
        for w_i in w_shape.getitems_unroll():
            self.shape.append(space.int_w(w_i))
        self.readonly = True
        self.shape.append(space.len_w(w_arr))
        self.data = []
        itemsize = 1
        worklist = [(1,w_arr)]
        while worklist:
            dim, w_work = worklist.pop()
            if space.isinstance_w(w_work, space.w_list):
                for j, w_obj in enumerate(w_work.getitems_unroll()):
                    worklist.insert(0, (dim+1, w_obj))
                continue
            byte = struct.pack(self.format, space.int_w(w_work))
            for c in byte:
                self.data.append(c)
        self.data = ''.join(self.data)

    def as_str(self):
        return self.data

    def getformat(self):
        return self.format

    def getbytes(self, start, size):
        return self.data[start:start + size]

    def getlength(self):
        return len(self.data)

    def getitemsize(self):
        return self.itemsize

    def getndim(self):
        return self.ndim

    def getstrides(self):
        return self.strides

    def getshape(self):
        return self.shape

    def is_contiguous(self, format):
        return format == 'C'

class W_MockArray(W_Root):
    def __init__(self, w_list, w_dim, w_fmt, w_size, w_strides, w_shape):
        self.w_list = w_list
        self.w_dim = w_dim
        self.w_fmt = w_fmt
        self.w_size = w_size
        self.w_strides = w_strides
        self.w_shape = w_shape

    @staticmethod
    def descr_new(space, w_type, w_list, w_dim, w_fmt, \
                         w_size, w_strides, w_shape):
        return W_MockArray(w_list, w_dim, w_fmt, w_size, w_strides, w_shape)

    def buffer_w(self, space, flags):
        return MockBuffer(space, self.w_list, self.w_dim, self.w_fmt, \
                          self.w_size, self.w_strides, self.w_shape,
                          w_obj=self)

W_MockArray.typedef = TypeDef("MockArray", None, None, "read-write",
    __new__ = interp2app(W_MockArray.descr_new),
)

class AppTestMemoryViewMockBuffer(object):
    spaceconfig = dict(usemodules=[])
    def setup_class(cls):
        if option.runappdirect:
            py.test.skip("Impossible to run on appdirect")
        cls.w_MockArray = cls.space.gettypefor(W_MockArray)

    def test_tuple_indexing(self):
        content = self.MockArray([[0,1,2,3], [4,5,6,7], [8,9,10,11]],
                                 dim=2, fmt='B', size=1,
                                 strides=[4,1], shape=[3,4])
        view = memoryview(content)
        assert view[0,0] == 0
        assert view[2,0] == 8
        assert view[2,3] == 11
        assert view[-1,-1] == 11
        assert view[-3,-4] == 0

        raises(IndexError, "view.__getitem__((2**31-1, 0))")
        raises(IndexError, "view.__getitem__((2**63+1, 0))")
        raises(TypeError, "view.__getitem__((0, 0, 0))")

    def test_tuple_indexing_int(self):
        content = self.MockArray([ [[1],[2],[3]], [[4],[5],[6]] ],
                                 dim=3, fmt='i', size=4,
                                 strides=[12,4,4], shape=[2,3,1])
        view = memoryview(content)
        assert view[0,0,0] == 1
        assert view[-1,2,0] == 6

    def test_cast_non_byte(self):
        empty = self.MockArray([], dim=1, fmt='i', size=4, strides=[1], shape=[1])
        view = memoryview(empty)
        raises(TypeError, "view.cast('l')")

    def test_cast_empty(self):
        empty = self.MockArray([], dim=1, fmt='b', size=1, strides=[1], shape=[1])
        view = memoryview(empty)
        cview = view.cast('i')
        assert cview.tobytes() == b''
        assert cview.tolist() == []
        assert view.format == 'b'
        assert cview.format == 'i'
        #
        a = cview.cast('b')
        b = a.cast('q')
        c = b.cast('b')
        assert c.tolist() == []
        #
        assert cview.format == 'i'
        raises(TypeError, "cview.cast('i')")

    def test_cast_with_shape(self):
        empty = self.MockArray([1,0,2,0,3,0],
                    dim=1, fmt='h', size=2,
                    strides=[2], shape=[6])
        view = memoryview(empty)
        byteview = view.cast('b')
        assert byteview.tolist() == [1,0,0,0,2,0,0,0,3,0,0,0]
        i32view = byteview.cast('i', shape=[1,3])
        assert i32view.format == 'i'
        assert i32view.itemsize == 4
        assert i32view.tolist() == [[1,2,3]]
        i32view = byteview.cast('i', shape=(1,3))
        assert i32view.tolist() == [[1,2,3]]

    def test_cast_bytes(self):
        bytes = b"\x02\x00\x03\x00\x04\x00" \
                b"\x05\x00\x06\x00\x07\x00"
        view = memoryview(bytes)
        v = view.cast('h', shape=(3,2))
        assert v.tolist() == [[2,3],[4,5],[6,7]]
        raises(TypeError, "view.cast('h', shape=(3,3))")

    def test_reversed(self):
        bytes = b"\x01\x01\x02\x02\x03\x03"
        view = memoryview(bytes)
        revlist = list(reversed(view.tolist()))
        assert view[::-1][0] == 3
        assert view[::-1][1] == 3
        assert view[::-1][2] == 2
        assert view[::-1][3] == 2
        assert view[::-1][4] == 1
        assert view[::-1][5] == 1
        assert view[::-1][-1] == 1
        assert view[::-1][-2] == 1
        assert list(reversed(view)) == revlist
        assert list(reversed(view)) == view[::-1].tolist()


class AppTestMemoryViewMockBuffer(object):
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_cast_with_byteorder(self):
        import sys
        if '__pypy__' not in sys.modules:
            skip('PyPy-only test')

        # create a memoryview with format '<B' (like ctypes does)
        from __pypy__ import bufferable, newmemoryview
        class B(bufferable.bufferable):
            def __init__(self):
                self.data = bytearray(b'abc')

            def __buffer__(self, flags):
                return newmemoryview(memoryview(self.data), 1, '<B')


        obj = B()
        buf = memoryview(obj)
        assert buf.format == '<B'
        # ensure we can cast this even though the format starts with '<'
        assert buf.cast('B')[0] == ord('a')


class AppTestMemoryViewReversed(object):
    spaceconfig = dict(usemodules=['array'])
    def test_reversed_non_bytes(self):
        import array
        items = [1,2,3,9,7,5]
        formats = ['h']
        for fmt in formats:
            bytes = array.array(fmt, items)
            view = memoryview(bytes)
            bview = view.cast('b')
            rview = bview.cast(fmt, shape=(2,3))
            raises(NotImplementedError, list, reversed(rview))
            assert rview.tolist() == [[1,2,3],[9,7,5]]
            assert rview[::-1].tolist() == [[9,7,5], [1,2,3]]
