import pytest
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rlib.rstruct.runpack import runpack
from rpython.rlib.rstruct import standardfmttable
from rpython.rlib.rstruct.error import StructError
from rpython.rlib.rarithmetic import LONG_BIT, long_typecode
import struct

class TestRStruct(BaseRtypingTest):
    def test_unpack(self):
        import sys
        pad = '\x00' * (LONG_BIT//8-1)    # 3 or 7 null bytes
        fmt = 's' + long_typecode + long_typecode
        def fn():
            return runpack(fmt, 'a'+pad+'\x03'+pad+'\x04'+pad)[1]
        result = 3 if sys.byteorder == 'little' else 3 << (LONG_BIT-8)
        assert fn() == result
        assert self.interpret(fn, []) == result

    def test_unpack_2(self):
        data = struct.pack('iiii', 0, 1, 2, 4)
        def fn():
            a, b, c, d = runpack('iiii', data)
            return a * 1000 + b * 100 + c * 10 + d
        assert fn() == 124
        assert self.interpret(fn, []) == 124

    def test_unpack_error(self):
        data = '123' # 'i' expects 4 bytes, not 3
        def fn():
            try:
                runpack('i', data)
            except StructError:
                return True
            else:
                return False
        assert fn()
        assert self.interpret(fn, [])

    def test_unpack_single(self):
        data = struct.pack('i', 123)
        def fn():
            return runpack('i', data)
        assert fn() == 123
        assert self.interpret(fn, []) == 123

    def test_unpack_big_endian(self):
        def fn():
            return runpack(">i", "\x01\x02\x03\x04")
        assert fn() == 0x01020304
        assert self.interpret(fn, []) == 0x01020304

    def test_unpack_double_big_endian(self):
        def fn():
            return runpack(">d", "testtest")
        assert fn() == struct.unpack(">d", "testtest")[0]
        assert self.interpret(fn, []) == struct.unpack(">d", "testtest")[0]

    def test_native_floats(self):
        """
        Check the 'd' and 'f' format characters on native packing.
        """
        d_data = struct.pack("df", 12.34, 12.34)
        def fn():
            d, f = runpack("@df", d_data)
            return d, f
        #
        # direct test
        d, f = fn()
        assert d == 12.34     # no precision lost
        assert f != 12.34     # precision lost
        assert abs(f - 12.34) < 1E-6
        #
        # translated test
        res = self.interpret(fn, [])
        d = res.item0
        f = res.item1  # convert from r_singlefloat
        assert d == 12.34     # no precision lost
        assert f != 12.34     # precision lost
        assert abs(f - 12.34) < 1E-6

    def test_unpack_halffloat(self):
        assert runpack(">e", b"\x7b\xef") == 64992.0
        assert runpack("<e", b"\xef\x7b") == 64992.0

    def test_unpack_standard_little(self):
        def unpack(fmt, data):
            def fn():
                return runpack(fmt, data)
            return self.interpret(fn, [])
        #
        assert unpack("<i", 'DCBA') == 0x41424344
        assert unpack("<i", '\xfd\xff\xff\xff') == -3
        assert unpack("<i", '\x00\x00\x00\x80') == -2147483648
        assert unpack("<I", 'DCB\x81') == 0x81424344
        assert unpack("<q", 'HGFEDCBA') == 0x4142434445464748
        assert unpack("<q", 'HHIJKLM\xbe') == -0x41B2B3B4B5B6B7B8
        assert unpack("<Q", 'HGFEDCB\x81') == 0x8142434445464748

    def test_unpack_standard_big(self):
        def unpack(fmt, data):
            def fn():
                return runpack(fmt, data)
            return self.interpret(fn, [])
        #
        assert unpack(">i", 'ABCD') == 0x41424344
        assert unpack(">i", '\xff\xff\xff\xfd') == -3
        assert unpack(">i", '\x80\x00\x00\x00') == -2147483648
        assert unpack(">I", '\x81BCD') == 0x81424344
        assert unpack(">q", 'ABCDEFGH') == 0x4142434445464748
        assert unpack(">q", '\xbeMLKJIHH') == -0x41B2B3B4B5B6B7B8
        assert unpack(">Q", '\x81BCDEFGH') == 0x8142434445464748

    def test_align(self):
        data = struct.pack('BBhi', 1, 2, 3, 4)
        def fn():
            a, b, c, d = runpack('BBhi', data)
            return a + (b << 4) + (c << 8) + (d << 12)
        assert fn() == 0x4321
        assert self.interpret(fn, []) == 0x4321



class TestNoFastPath(TestRStruct):

    def setup_method(self, meth):
        standardfmttable.USE_FASTPATH = False

    def teardown_method(self, meth):
        standardfmttable.USE_FASTPATH = True
