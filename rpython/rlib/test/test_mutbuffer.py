import pytest
import struct
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.mutbuffer import MutableStringBuffer

class TestMutableStringBuffer(object):

    def test_finish(self):
        buf = MutableStringBuffer(4)
        buf.setzeros(0, 4)
        pytest.raises(ValueError, "buf.as_str()")
        s = buf.finish()
        assert s == '\x00' * 4
        pytest.raises(ValueError, "buf.finish()")

    def test_setitem(self):
        buf = MutableStringBuffer(4)
        buf.setitem(0, 'A')
        buf.setitem(1, 'B')
        buf.setitem(2, 'C')
        buf.setitem(3, 'D')
        assert buf.finish() == 'ABCD'

    def test_setslice(self):
        buf = MutableStringBuffer(6)
        buf.setzeros(0, 6)
        buf.setslice(2, 'ABCD')
        assert buf.finish() == '\x00\x00ABCD'

    def test_setzeros(self):
        buf = MutableStringBuffer(8)
        buf.setslice(0, 'ABCDEFGH')
        buf.setzeros(2, 3)
        assert buf.finish() == 'AB\x00\x00\x00FGH'

    def test_typed_write(self):
        expected = struct.pack('ifqd', 0x1234, 123.456, 0x12345678, 789.123)
        buf = MutableStringBuffer(24)
        buf.typed_write(rffi.INT, 0, 0x1234)
        buf.typed_write(rffi.FLOAT, 4, 123.456)
        buf.typed_write(rffi.LONGLONG, 8, 0x12345678)
        buf.typed_write(rffi.DOUBLE, 16, 789.123)
        s = buf.finish()
        assert s == expected
