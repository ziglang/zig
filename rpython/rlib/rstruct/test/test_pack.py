import pytest
from rpython.rlib.rarithmetic import r_uint, r_longlong, r_ulonglong
from rpython.rlib.rstruct import standardfmttable, nativefmttable
from rpython.rlib.rstruct.error import StructOverflowError
from rpython.rlib import buffer
from rpython.rlib.buffer import SubBuffer
from rpython.rlib.mutbuffer import MutableStringBuffer
from rpython.rlib import rawstorage
import struct

class FakeFormatIter(object):

    def __init__(self, bigendian, wbuf, value):
        self.value = value
        self.bigendian = bigendian
        self.wbuf = wbuf
        self.pos = 0

    def advance(self, count):
        self.pos += count

    def _accept_arg(self):
        return self.value

    def __getattr__(self, name):
        if name.startswith('accept_'):
            return self._accept_arg
        raise AttributeError(name)


class PackSupport(object):
    """
    These test tests only the various pack_* functions, individually.  There
    is no RPython interface to them, as for now they are used only to
    implement struct.pack in pypy/module/struct
    """

    bigendian = None
    fmt_prefix = None
    fmttable = None

    USE_FASTPATH = True
    ALLOW_SLOWPATH = True
    ALLOW_FASTPATH = True
    ALLOW_UNALIGNED_ACCESS = rawstorage.misaligned_is_fine
    
    def setup_method(self, meth):
        standardfmttable.USE_FASTPATH = self.USE_FASTPATH
        standardfmttable.ALLOW_SLOWPATH = self.ALLOW_SLOWPATH
        standardfmttable.ALLOW_FASTPATH = self.ALLOW_FASTPATH
        buffer.ALLOW_UNALIGNED_ACCESS = self.ALLOW_UNALIGNED_ACCESS

    def teardown_method(self, meth):
        standardfmttable.USE_FASTPATH = True
        standardfmttable.ALLOW_SLOWPATH = True
        standardfmttable.ALLOW_FASTPATH = True
        buffer.ALLOW_UNALIGNED_ACCESS = rawstorage.misaligned_is_fine

    def mypack(self, fmt, value):
        size = struct.calcsize(fmt)
        wbuf = MutableStringBuffer(size)
        fake_fmtiter = self.mypack_into(fmt, wbuf, value)
        # check that we called advance() the right number of times
        assert fake_fmtiter.pos == wbuf.getlength()
        return wbuf.finish()

    def mypack_into(self, fmt, wbuf, value, advance=None):
        fake_fmtiter = FakeFormatIter(self.bigendian, wbuf, value)
        if advance:
            fake_fmtiter.advance(advance)
        attrs = self.fmttable[fmt]
        pack = attrs['pack']
        pack(fake_fmtiter)
        return fake_fmtiter

    def mypack_fn(self, func, size, arg, value):
        wbuf = MutableStringBuffer(size)
        fake_fmtiter = FakeFormatIter(self.bigendian, wbuf, value)
        func(fake_fmtiter, arg)
        assert fake_fmtiter.pos == wbuf.getlength()
        return wbuf.finish()

    def check(self, fmt, value):
        expected = struct.pack(self.fmt_prefix+fmt, value)
        got = self.mypack(fmt, value)
        assert got == expected


class TestAllowSlowpath(PackSupport):
    ALLOW_SLOWPATH = False
    bigendian = not nativefmttable.native_is_bigendian
    fmttable = standardfmttable.standard_fmttable

    def test_slowpath_not_allowed(self):
        # we are using a non-native endianess and ALLOW_SLOWPATH is False, so
        # the following MUST raise
        pytest.raises(ValueError, "self.mypack('i', 42)")


class TestUseFastpath(PackSupport):
    ALLOW_SLOWPATH = False
    bigendian = nativefmttable.native_is_bigendian
    fmttable = standardfmttable.standard_fmttable

    def test_fastpath_taken(self):
        # we are using native endianess and slowpath is not allowed, so the
        # following MUST succeed
        expected = struct.pack('i', 42)
        assert self.mypack('i', 42) == expected

class TestAllowFastPath(PackSupport):
    ALLOW_FASTPATH = False
    bigendian = nativefmttable.native_is_bigendian
    fmttable = standardfmttable.standard_fmttable

    def test_fastpath_not_allowed(self):
        # we are using a native endianess but ALLOW_FASTPATH is False, so
        # the following MUST raise
        pytest.raises(ValueError, "self.mypack('i', 42)")


class BaseTestPack(PackSupport):

    def test_pack_int(self):
        self.check('b', 42)
        self.check('B', 242)
        self.check('h', 32767)
        self.check('H', 32768)
        self.check("i", 0x41424344)
        self.check("i", -3)
        self.check("i", -2147483648)
        self.check("I", r_uint(0x81424344))
        self.check("q", r_longlong(0x4142434445464748))
        self.check("q", r_longlong(-0x41B2B3B4B5B6B7B8))
        self.check("Q", r_ulonglong(0x8142434445464748))

    def test_pack_ieee(self):
        self.check('f', 123.456)
        self.check('d', 123.456789)

    def test_pack_halffloat(self):
        size = 2
        wbuf = MutableStringBuffer(size)
        self.mypack_into('e', wbuf, 6.5e+04)
        got = wbuf.finish()
        if self.bigendian:
            assert got == b'\x7b\xef'
        else:
            assert got == b'\xef\x7b'

    def test_float_overflow(self):
        if self.fmt_prefix == '@':
            # native packing, no overflow
            self.check('f', 10e100)
        else:
            # non-native packing, should raise
            pytest.raises(StructOverflowError, "self.mypack('f', 10e100)")

    def test_pack_char(self):
        self.check('c', 'a')

    def test_pack_bool(self):
        self.check('?', True)
        self.check('?', False)

    def test_pack_pad(self):
        s = self.mypack_fn(standardfmttable.pack_pad,
                           arg=4, value=None, size=4)
        assert s == '\x00'*4

    def test_pack_string(self):
        s = self.mypack_fn(standardfmttable.pack_string,
                           arg=8, value='hello', size=8)
        assert s == 'hello\x00\x00\x00'
        #
        s = self.mypack_fn(standardfmttable.pack_string,
                           arg=8, value='hello world', size=8)
        assert s == 'hello wo'

    def test_pack_pascal(self):
        s = self.mypack_fn(standardfmttable.pack_pascal,
                           arg=8, value='hello', size=8)
        assert s == '\x05hello\x00\x00'


class TestPackLittleEndian(BaseTestPack):
    bigendian = False
    fmt_prefix = '<'
    fmttable = standardfmttable.standard_fmttable

class TestPackLittleEndianSlowPath(TestPackLittleEndian):
    USE_FASTPATH = False

class TestPackBigEndian(BaseTestPack):
    bigendian = True
    fmt_prefix = '>'
    fmttable = standardfmttable.standard_fmttable

class TestPackBigEndianSlowPath(TestPackBigEndian):
    USE_FASTPATH = False


class TestNative(BaseTestPack):
    # native packing automatically use the proper endianess, so it should
    # always take the fast path
    ALLOW_SLOWPATH = False
    bigendian = nativefmttable.native_is_bigendian
    fmt_prefix = '@'
    fmttable = nativefmttable.native_fmttable

class TestNativeSlowPath(BaseTestPack):
    USE_FASTPATH = False
    bigendian = nativefmttable.native_is_bigendian
    fmt_prefix = '@'
    fmttable = nativefmttable.native_fmttable


class TestUnaligned(PackSupport):
    ALLOW_FASTPATH = False
    ALLOW_UNALIGNED_ACCESS = False
    bigendian = nativefmttable.native_is_bigendian
    fmttable = nativefmttable.native_fmttable

    def test_unaligned(self):
        # to force a non-aligned 'i'
        expected = struct.pack('=BBi', 0xAB, 0xCD, 0x1234)
        #
        wbuf = MutableStringBuffer(len(expected))
        wbuf.setitem(0, chr(0xAB))
        wbuf.setitem(1, chr(0xCD))
        fake_fmtiter = self.mypack_into('i', wbuf, 0x1234, advance=2)
        assert fake_fmtiter.pos == wbuf.getlength()
        got = wbuf.finish()
        assert got == expected

    def test_subbuffer(self):
        # to force a non-aligned 'i'
        expected = struct.pack('=BBi', 0xAB, 0xCD, 0x1234)
        size = len(expected)
        #
        wbuf = MutableStringBuffer(size)
        wsubbuf = SubBuffer(wbuf, 2, size-4)
        wbuf.setitem(0, chr(0xAB))
        wbuf.setitem(1, chr(0xCD))
        fake_fmtiter = self.mypack_into('i', wsubbuf, 0x1234)
        assert fake_fmtiter.pos == wbuf.getlength()-2 # -2 since it's a SubBuffer
        got = wbuf.finish()
        assert got == expected
