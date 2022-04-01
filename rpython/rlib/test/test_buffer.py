import pytest
import struct
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import r_singlefloat, long_typecode
from rpython.rlib.buffer import (
    StringBuffer, SubBuffer, Buffer, RawBuffer,
    LLBuffer, RawByteBuffer, ByteBuffer)
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.annotator.model import SomeInteger
from rpython.jit.metainterp.test.support import LLJitMixin


class MyRawBuffer(RawBuffer):

    def __init__(self, data, readonly=True):
        self.readonly = readonly
        self._n = len(data)
        self._buf = lltype.malloc(rffi.CCHARP.TO, self._n, flavor='raw')
        for i, ch in enumerate(data):
            self._buf[i] = ch

    def get_raw_address(self):
        return self._buf

    def as_str(self):
        return rffi.charpsize2str(self._buf, self._n)

    def setitem(self, i, char):
        assert not self.readonly
        self._buf[i] = char

    def __del__(self):
        lltype.free(self._buf, flavor='raw')
        self._buf = None


def test_string_buffer():
    buf = StringBuffer('hello world')
    assert buf.getitem(4) == 'o'
    assert buf.getitem(4) == buf[4]
    assert buf.getlength() == 11
    assert buf.getlength() == len(buf)
    assert buf.getslice(1, 1, 5) == 'ello '
    assert buf.getslice(1, 1, 5) == buf[1:6]
    assert buf.getslice(1, 2, 3) == 'el '
    assert buf.as_str() == 'hello world'


def test_len_nonneg():
    # This test needs a buffer subclass whose getlength() isn't guaranteed to
    # return a non-neg integer.
    class DummyBuffer(Buffer):
        def __init__(self, s):
            self.size = s

        def getlength(self):
            return self.size
    def func(n):
        buf = DummyBuffer(n)
        return len(buf)

    a = RPythonAnnotator()
    s = a.build_types(func, [int])
    assert s == SomeInteger(nonneg=True)


def test_repeated_subbuffer():
    buf = StringBuffer('x' * 10000)
    for i in range(9999, 9, -1):
        buf = SubBuffer(buf, 1, i)
    assert buf.getlength() == 10

def test_string_buffer_as_buffer():
    buf = StringBuffer(b'hello world')
    addr = buf.get_raw_address()
    assert addr[0] == b'h'
    assert addr[4] == b'o'
    assert addr[6] == b'w'

def test_setzeros():
    buf = MyRawBuffer('ABCDEFGH', readonly=False)
    buf.setzeros(2, 3)
    assert buf.as_str() == 'AB\x00\x00\x00FGH'


class BaseTypedReadTest:

    def test_signed(self):
        buf = struct.pack('@%s%s' % (long_typecode, long_typecode), 42, 43)
        size = struct.calcsize('@%s' % long_typecode)
        assert self.read(lltype.Signed, buf, 0) == 42
        assert self.read(lltype.Signed, buf, size) == 43

    def test_short(self):
        buf = struct.pack('@hh', 42, 43)
        size = struct.calcsize('@h')
        x = self.read(rffi.SHORT, buf, 0)
        assert int(x) == 42
        x = self.read(rffi.SHORT, buf, size)
        assert int(x) == 43

    def test_float(self):
        buf = struct.pack('@dd', 12.3, 45.6)
        size = struct.calcsize('@d')
        assert self.read(lltype.Float, buf, 0) == 12.3
        assert self.read(lltype.Float, buf, size) == 45.6

    def test_singlefloat(self):
        buf = struct.pack('@ff', 12.3, 45.6)
        size = struct.calcsize('@f')
        x = self.read(lltype.SingleFloat, buf, 0)
        assert x == r_singlefloat(12.3)
        x = self.read(lltype.SingleFloat, buf, size)
        assert x == r_singlefloat(45.6)

class TestTypedReadDirect(BaseTypedReadTest):

    def read(self, TYPE, data, offset):
        buf = StringBuffer(data)
        return buf.typed_read(TYPE, offset)


class TestSubBufferTypedReadDirect(BaseTypedReadTest):

    def read(self, TYPE, data, offset):
        buf = StringBuffer('x' * 16 + data)
        subbuf = SubBuffer(buf, 16, len(data))
        return subbuf.typed_read(TYPE, offset)


class TestRawBufferTypedReadDirect(BaseTypedReadTest):

    def read(self, TYPE, data, offset):
        buf = MyRawBuffer(data)
        return buf.typed_read(TYPE, offset)


class TestRawBufferTypedWrite(object):

    def test_typed_write(self):
        expected = struct.pack('=H', 0xABCD) + '\xff' * 6
        buf = MyRawBuffer('\xff' * 8, readonly=False)
        buf.typed_write(rffi.USHORT, 0, 0xABCD)
        assert buf.as_str() == expected
        assert buf.typed_read(rffi.USHORT, 0) == 0xABCD


class TestCompiled(BaseTypedReadTest):
    cache = {}

    def read(self, TYPE, data, offset):
        if TYPE not in self.cache:
            from rpython.translator.c.test.test_genc import compile

            assert isinstance(TYPE, lltype.Primitive)
            if TYPE in (lltype.Float, lltype.SingleFloat):
                TARGET_TYPE = lltype.Float
            else:
                TARGET_TYPE = lltype.Signed

            def llf(data, offset):
                buf = StringBuffer(data)
                x = buf.typed_read(TYPE, offset)
                return lltype.cast_primitive(TARGET_TYPE, x)

            fn = compile(llf, [str, int])
            self.cache[TYPE] = fn
        #
        fn = self.cache[TYPE]
        x = fn(data, offset)
        return lltype.cast_primitive(TYPE, x)

class _LLBuffer(LLBuffer):
    def __del__(self):
        lltype.free(self.raw_cdata, flavor='raw')

def make_LLBuffer(size):
    buf = lltype.malloc(rffi.CCHARP.TO, size, flavor='raw', zero=True)
    return _LLBuffer(buf, size)
    # _LLBuffer.__del__ frees buf


@pytest.fixture(params=[RawByteBuffer, ByteBuffer, make_LLBuffer])
def make_buffer(request):
    return request.param

def test_basic(make_buffer):
    buf = make_buffer(4)
    assert buf.getlength() == 4
    assert buf.getitem(2) == '\x00'
    buf.setitem(0, 'A')
    buf.setitem(3, 'Z')
    assert buf.as_str() == 'A\x00\x00Z'

def test_typed_write(make_buffer):
    buf = make_buffer(4)
    buf.typed_write(rffi.USHORT, 0, 0x1234)
    buf.typed_write(rffi.USHORT, 2, 0x5678)
    expected = struct.pack('HH', 0x1234, 0x5678)
    assert buf.as_str() == expected

def test_typed_read(make_buffer):
    data = struct.pack('HH', 0x1234, 0x5678)
    buf = make_buffer(4)
    buf.setslice(0, data)
    assert buf.typed_read(rffi.USHORT, 0) == 0x1234
    assert buf.typed_read(rffi.USHORT, 2) == 0x5678

def test_getslice_shortcut(make_buffer):
    buf = make_buffer(4)
    buf.setslice(0, b"data")
    buf.getitem = None
    assert buf.getslice(0, 1, 2) == b"da"  # no crash!

def test_getslice_slowpath(make_buffer):
    buf = make_buffer(4)
    buf.setslice(0, b"datu")
    assert buf.getslice(0, 2, 2) == b"dt"
    assert buf.getslice(1, 2, 2) == b"au"
    assert buf.getslice(2, -2, 2) == b"td"
    assert buf.getslice(3, -2, 2) == b"ua"

def test_getslice_clipped1(make_buffer):
    buf = make_buffer(4)
    buf.setslice(0, b"data")
    buf.getitem = None
    assert buf[0:8] == b"data"  # no crash!

def test_getslice_clipped2(make_buffer):
    buf = make_buffer(4)
    buf.setslice(0, b"data")
    buf.getitem = None
    assert buf[1:8] == b"ata"  # no crash!

def test_getslice_open(make_buffer):
    buf = make_buffer(4)
    buf.setslice(0, b"data")
    buf.getitem = None
    assert buf[:] == b"data"  # no crash!


class TestJIT(LLJitMixin):

    def test_GCBuffer_typed_read(self):
        from rpython.rlib import jit
        DATA = struct.pack('i', 0x12345678)

        @jit.dont_look_inside
        def make_buffer(flag):
            if flag:
                buf = ByteBuffer(len(DATA))
                buf.setslice(0, DATA)
            else:
                buf = StringBuffer(DATA)
            return buf

        def f(flag):
            buf = make_buffer(flag)
            return buf.typed_read(rffi.INT, 0)

        for flag in (0, 1):
            res = self.interp_operations(f, [0], supports_singlefloats=True)
            #
            self.check_operations_history({'call_r': 1,
                                           'guard_no_exception': 1,
                                           'guard_class': 1,
                                           'gc_load_indexed_i': 1,
                                           'finish': 1})
            assert res == 0x12345678
