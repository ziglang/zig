from rpython.jit.backend.ppc.field import Field
from py.test import raises

import random

maxppcint = 0x7fffffff

class TestFields(object):
    def test_decode(self):
        # this test is crappy
        field = Field("test", 0, 31)
        for i in range(100):
            j = random.randrange(maxppcint)
            assert field.decode(j) == j
        field = Field("test", 0, 31-4)
        for i in range(100):
            j = random.randrange(maxppcint)
            assert field.decode(j) == j>>4
            assert field.decode(j) == j>>4
        field = Field("test", 3, 31-4)
        for i in range(100):
            j = random.randrange(maxppcint>>3)
            assert field.decode(j) == j>>4


    def test_decode_unsigned(self):
        field = Field("test", 16, 31)
        for i in range(1000):
            hi = long(random.randrange(0x10000)) << 16
            lo = long(random.randrange(0x10000))
            assert field.decode(hi|lo) == lo


    def test_decode_signed(self):
        field = Field("test", 16, 31, 'signed')
        for i in range(1000):
            hi = long(random.randrange(0x10000)) << 16
            lo = long(random.randrange(0x10000))
            word = hi|lo
            if lo & 0x8000:
                lo |= ~0xFFFF
            assert field.decode(word) == lo


    def test_error_checking_unsigned(self):
        for b in range(0, 17):
            field = Field("test", b, 15+b)
            assert field.decode(field.encode(0)) == 0
            assert field.decode(field.encode(32768)) == 32768
            assert field.decode(field.encode(65535)) == 65535
            raises(ValueError, field.encode, -32768)
            raises(ValueError, field.encode, -1)
            raises(ValueError, field.encode, 65536)


    def test_error_checking_signed(self):
        for b in range(0, 17):
            field = Field("test", b, 15+b, 'signed')
            assert field.decode(field.encode(0)) == 0
            assert field.decode(field.encode(-32768)) == -32768
            assert field.decode(field.encode(32767)) == 32767
            raises(ValueError, field.encode, 32768)
            raises(ValueError, field.encode, -32769)

