"""
Tests for the struct module implemented at interp-level in pypy/module/struct.
"""

# spaceconfig = {"usemodules": ["struct", "__pypy__"]}
import struct
from __pypy__ import bytebuffer

def test_pack_into():
    b = bytebuffer(19)
    sz = struct.calcsize("ii")
    struct.pack_into("ii", b, 2, 17, 42)
    assert b[:] == (b'\x00' * 2 +
                    struct.pack("ii", 17, 42) +
                    b'\x00' * (19-sz-2))
    m = memoryview(b)
    struct.pack_into("ii", m, 2, 17, 42)

def test_unpack_from():
    b = bytebuffer(19)
    sz = struct.calcsize("ii")
    b[2:2+sz] = struct.pack("ii", 17, 42)
    assert struct.unpack_from("ii", b, 2) == (17, 42)
    b[:sz] = struct.pack("ii", 18, 43)
    assert struct.unpack_from("ii", b) == (18, 43)