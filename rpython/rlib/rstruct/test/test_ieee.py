import math
import py
import sys
import random
import struct

from rpython.rlib.mutbuffer import MutableStringBuffer
from rpython.rlib.rstruct import ieee
from rpython.rlib.rfloat import NAN, INFINITY
from rpython.translator.c.test.test_genc import compile


class TestFloatSpecific:
    def test_halffloat_exact(self):
        #testcases generated from numpy.float16(x).view('uint16')
        cases = [[0, 0], [10, 18688], [-10, 51456], [10e3, 28898],
                 [float('inf'), 31744], [-float('inf'), 64512]]
        for c, h in cases:
            hbit = ieee.float_pack(c, 2)
            assert hbit == h
            assert c == ieee.float_unpack(h, 2)

    def test_halffloat_inexact(self):
        #testcases generated from numpy.float16(x).view('uint16')
        cases = [[10.001, 18688, 10.], [-10.001, 51456, -10],
                 [0.027588, 10000, 0.027587890625],
                 [22001, 30047, 22000]]
        for c, h, f in cases:
            hbit = ieee.float_pack(c, 2)
            assert hbit == h
            assert f == ieee.float_unpack(h, 2)

    def test_halffloat_overunderflow(self):
        cases = [[670000, float('inf')], [-67000, -float('inf')],
                 [1e-08, 0], [-1e-8, -0.]]
        for f1, f2 in cases:
            try:
                f_out = ieee.float_unpack(ieee.float_pack(f1, 2), 2)
            except OverflowError:
                f_out = math.copysign(float('inf'), f1)
            assert f_out == f2
            assert math.copysign(1., f_out) == math.copysign(1., f2)

    def test_float80_exact(self):
        s = []
        ieee.pack_float80(s, -1., 16, False)
        assert repr(s[-1]) == repr('\x00\x00\x00\x00\x00\x00\x00\x80\xff\xbf\x00\x00\x00\x00\x00\x00')
        ieee.pack_float80(s, -1., 16, True)
        assert repr(s[-1]) == repr('\x00\x00\x00\x00\x00\x00\xbf\xff\x80\x00\x00\x00\x00\x00\x00\x00')
        ieee.pack_float80(s, -123.456, 16, False)
        assert repr(s[-1]) == repr('\x00\xb8\xf3\xfd\xd4x\xe9\xf6\x05\xc0\x00\x00\x00\x00\x00\x00')
        ieee.pack_float80(s, -123.456, 16, True)
        assert repr(s[-1]) == repr('\x00\x00\x00\x00\x00\x00\xc0\x05\xf6\xe9x\xd4\xfd\xf3\xb8\x00')

        x = ieee.unpack_float80('\x00\x00\x00\x00\x00\x00\x00\x80\xff?\xc8\x01\x00\x00\x00\x00', False)
        assert x == 1.0
        x = ieee.unpack_float80('\x00\x00\x7f\x83\xe1\x91?\xff\x80\x00\x00\x00\x00\x00\x00\x00', True)
        assert x == 1.0


class TestFloatPacking:

    def check_float(self, x):
        # check roundtrip
        for size in [10, 12, 16]:
            for be in [False, True]:
                Q = []
                ieee.pack_float80(Q, x, size, be)
                Q = Q[0]
                y = ieee.unpack_float80(Q, be)
                assert repr(x) == repr(y), '%r != %r, Q=%r' % (x, y, Q)

        for be in [False, True]:
            buf = MutableStringBuffer(8)
            ieee.pack_float(buf, 0, x, 8, be)
            Q = buf.finish()
            y = ieee.unpack_float(Q, be)
            assert repr(x) == repr(y), '%r != %r, Q=%r' % (x, y, Q)

        # check that packing agrees with the struct module
        struct_pack8 = struct.unpack('<Q', struct.pack('<d', x))[0]
        float_pack8 = ieee.float_pack(x, 8)
        assert struct_pack8 == float_pack8

        # check that packing agrees with the struct module
        try:
            struct_pack4 = struct.unpack('<L', struct.pack('<f', x))[0]
        except OverflowError:
            struct_pack4 = "overflow"
        try:
            float_pack4 = ieee.float_pack(x, 4)
        except OverflowError:
            float_pack4 = "overflow"
        assert struct_pack4 == float_pack4

        if float_pack4 == "overflow":
            return

        # if we didn't overflow, try round-tripping the binary32 value
        roundtrip = ieee.float_pack(ieee.float_unpack(float_pack4, 4), 4)
        assert float_pack4 == roundtrip

        try:
            float_pack2 = ieee.float_pack(x, 2)
        except OverflowError:
            return

        roundtrip = ieee.float_pack(ieee.float_unpack(float_pack2, 2), 2)
        assert (float_pack2, x) == (roundtrip, x)

    def test_infinities(self):
        self.check_float(float('inf'))
        self.check_float(float('-inf'))

    def test_zeros(self):
        self.check_float(0.0)
        self.check_float(-0.0)

    def test_nans(self):
        self.check_float(float('nan'))

    def test_simple(self):
        test_values = [1e-10, 0.00123, 0.5, 0.7, 1.0, 123.456, 1e10]
        for value in test_values:
            self.check_float(value)
            self.check_float(-value)

    def test_subnormal(self):
        # special boundaries
        self.check_float(2**-1074)
        self.check_float(2**-1022)
        self.check_float(2**-1021)
        self.check_float((2**53-1)*2**-1074)
        self.check_float((2**52-1)*2**-1074)
        self.check_float((2**52+1)*2**-1074)

        # other subnormals
        self.check_float(1e-309)
        self.check_float(1e-320)

    def test_powers_of_two(self):
        # exact powers of 2
        for k in range(-1074, 1024):
            self.check_float(2.**k)

        # and values near powers of 2
        for k in range(-1074, 1024):
            self.check_float((2 - 2**-52) * 2.**k)

    def test_float4_boundaries(self):
        # Exercise IEEE 754 binary32 boundary cases.
        self.check_float(2**128.)
        # largest representable finite binary32 value
        self.check_float((1 - 2.**-24) * 2**128.)
        # halfway case:  rounds up to an overflowing value
        self.check_float((1 - 2.**-25) * 2**128.)
        self.check_float(2**-125)
        # smallest normal
        self.check_float(2**-126)
        # smallest positive binary32 value (subnormal)
        self.check_float(2**-149)
        # 2**-150 should round down to 0
        self.check_float(2**-150)
        # but anything even a tiny bit larger should round up to 2**-149
        self.check_float((1 + 2**-52) * 2**-150)

    def test_random(self):
        # construct a Python float from random integer, using struct
        mantissa_mask = (1 << 53) - 1
        for _ in xrange(10000):
            Q = random.randrange(2**64)
            x = struct.unpack('<d', struct.pack('<Q', Q))[0]
            # nans are tricky:  we can't hope to reproduce the bit
            # pattern exactly, so check_float will fail for a nan
            # whose mantissa does not fit into float16's mantissa.
            if math.isnan(x) and (Q & mantissa_mask) >=  1 << 11:
                continue
            self.check_float(x)

    def test_various_nans(self):
        # check patterns that should preserve the mantissa across nan conversions
        maxmant64 = (1 << 52) - 1 # maximum double mantissa
        maxmant16 = (1 << 10) - 1 # maximum float16 mantissa
        assert maxmant64 >> 42 == maxmant16
        exp = 0xfff << 52
        for i in range(20):
            val_to_preserve = exp | ((maxmant16 - i) << 42)
            a = ieee.float_unpack(val_to_preserve, 8)
            assert math.isnan(a), 'i %d, maxmant %s' % (i, hex(val_to_preserve))
            b = ieee.float_pack(a, 8)
            assert b == val_to_preserve, 'i %d, val %s b %s' % (i, hex(val_to_preserve), hex(b)) 
            b = ieee.float_pack(a, 2)
            assert b == 0xffff - i, 'i %d, b%s' % (i, hex(b))

class TestCompiled:
    def test_pack_float(self):
        def pack(x, size):
            buf = MutableStringBuffer(size)
            ieee.pack_float(buf, 0, x, size, False)
            l = []
            for c in buf.finish():
                l.append(str(ord(c)))
            return ','.join(l)
        c_pack = compile(pack, [float, int])

        def unpack(s):
            l = s.split(',')
            s = ''.join([chr(int(x)) for x in l])
            return ieee.unpack_float(s, False)
        c_unpack = compile(unpack, [str])

        def check_roundtrip(x, size):
            s = c_pack(x, size)
            if not math.isnan(x):
                # pack uses copysign which is ambiguous for NAN
                assert s == pack(x, size)
                assert unpack(s) == x
                assert c_unpack(s) == x
            else:
                assert math.isnan(unpack(s))
                assert math.isnan(c_unpack(s))

        for size in [2, 4, 8]:
            check_roundtrip(123.4375, size)
            check_roundtrip(-123.4375, size)
            check_roundtrip(INFINITY, size)
            check_roundtrip(NAN, size)
