"""
Tests for the struct module implemented at interp-level in pypy/module/struct.
"""

# spaceconfig = {"usemodules": ["struct", "array"]}
import struct
import sys

native_is_bigendian = sys.byteorder == 'big'

def test_error():
    """
    struct.error should be an exception class.
    """
    assert issubclass(struct.error, Exception)
    assert struct.error.__mro__ == (struct.error, Exception, BaseException, object)
    assert struct.error.__name__ == "error"
    assert struct.error.__module__ == "struct"

def test_calcsize_standard():
    """
    Check the standard size of the various format characters.
    """
    calcsize = struct.calcsize
    assert calcsize('=') == 0
    assert calcsize('<x') == 1
    assert calcsize('>c') == 1
    assert calcsize('!b') == 1
    assert calcsize('=B') == 1
    assert calcsize('<h') == 2
    assert calcsize('>H') == 2
    assert calcsize('!i') == 4
    assert calcsize('=I') == 4
    assert calcsize('<l') == 4
    assert calcsize('>L') == 4
    assert calcsize('!q') == 8
    assert calcsize('=Q') == 8
    assert calcsize('<f') == 4
    assert calcsize('>d') == 8
    assert calcsize('<e') == 2
    assert calcsize('!13s') == 13
    assert calcsize('=500p') == 500
    # test with some repetitions and multiple format characters
    assert calcsize('=bQ3i') == 1 + 8 + 3*4

def test_index():
    class X(object):
        def __index__(self):
            return 3
    assert struct.unpack("i", struct.pack("i", X()))[0] == 3

def test_pack_standard_little():
    """
    Check packing with the '<' format specifier.
    """
    pack = struct.pack
    assert pack("<i", 0x41424344) == b'DCBA'
    assert pack("<i", -3) == b'\xfd\xff\xff\xff'
    assert pack("<i", -2147483648) == b'\x00\x00\x00\x80'
    assert pack("<I", 0x81424344) == b'DCB\x81'
    assert pack("<q", 0x4142434445464748) == b'HGFEDCBA'
    assert pack("<q", -0x41B2B3B4B5B6B7B8) == b'HHIJKLM\xbe'
    assert pack("<Q", 0x8142434445464748) == b'HGFEDCB\x81'

def test_unpack_standard_little():
    """
    Check unpacking with the '<' format specifier.
    """
    unpack = struct.unpack
    assert unpack("<i", b'DCBA') == (0x41424344,)
    assert unpack("<i", b'\xfd\xff\xff\xff') == (-3,)
    assert unpack("<i", b'\x00\x00\x00\x80') == (-2147483648,)
    assert unpack("<I", b'DCB\x81') == (0x81424344,)
    assert unpack("<q", b'HGFEDCBA') == (0x4142434445464748,)
    assert unpack("<q", b'HHIJKLM\xbe') == (-0x41B2B3B4B5B6B7B8,)
    assert unpack("<Q", b'HGFEDCB\x81') == (0x8142434445464748,)

def test_pack_standard_big():
    """
    Check packing with the '>' format specifier.
    """
    pack = struct.pack
    assert pack(">i", 0x41424344) == b'ABCD'
    assert pack(">i", -3) == b'\xff\xff\xff\xfd'
    assert pack(">i", -2147483648) == b'\x80\x00\x00\x00'
    assert pack(">I", 0x81424344) == b'\x81BCD'
    assert pack(">q", 0x4142434445464748) == b'ABCDEFGH'
    assert pack(">q", -0x41B2B3B4B5B6B7B8) == b'\xbeMLKJIHH'
    assert pack(">Q", 0x8142434445464748) == b'\x81BCDEFGH'

def test_unpack_standard_big():
    """
    Check unpacking with the '>' format specifier.
    """
    unpack = struct.unpack
    assert unpack(">i", b'ABCD') == (0x41424344,)
    assert unpack(">i", b'\xff\xff\xff\xfd') == (-3,)
    assert unpack(">i", b'\x80\x00\x00\x00') == (-2147483648,)
    assert unpack(">I", b'\x81BCD') == (0x81424344,)
    assert unpack(">q", b'ABCDEFGH') == (0x4142434445464748,)
    assert unpack(">q", b'\xbeMLKJIHH') == (-0x41B2B3B4B5B6B7B8,)
    assert unpack(">Q", b'\x81BCDEFGH') == (0x8142434445464748,)

def test_calcsize_native():
    """
    Check that the size of the various format characters is reasonable.
    """
    calcsize = struct.calcsize
    assert calcsize('') == 0
    assert calcsize('x') == 1
    assert calcsize('c') == 1
    assert calcsize('b') == 1
    assert calcsize('B') == 1
    assert (2 <= calcsize('h') == calcsize('H')
              <  calcsize('i') == calcsize('I')
              <= calcsize('l') == calcsize('L')
              <= calcsize('q') == calcsize('Q'))
    assert 4 <= calcsize('f') <= 8 <= calcsize('d')
    assert calcsize('n') == calcsize('N') >= calcsize('P')
    assert calcsize('13s') == 13
    assert calcsize('500p') == 500
    assert 4 <= calcsize('P') <= 8
    # test with some repetitions and multiple format characters
    assert 4 + 8 + 3*4 <= calcsize('bQ3i') <= 8 + 8 + 3*8
    # test alignment
    assert calcsize('bi') == calcsize('ii') == 2 * calcsize('i')
    assert calcsize('bbi') == calcsize('ii') == 2 * calcsize('i')
    assert calcsize('hi') == calcsize('ii') == 2 * calcsize('i')
    # CPython adds no padding at the end, unlike a C compiler
    assert calcsize('ib') == calcsize('i') + calcsize('b')
    assert calcsize('ibb') == calcsize('i') + 2 * calcsize('b')
    assert calcsize('ih') == calcsize('i') + calcsize('h')

def test_pack_native():
    """
    Check packing with the native format.
    """
    calcsize = struct.calcsize
    pack = struct.pack
    sizeofi = calcsize("i")
    res = pack("bi", -2, 5)
    assert len(res) == 2 * sizeofi
    assert res[0] == 0xfe
    assert res[1:sizeofi] == b'\x00' * (sizeofi-1)    # padding
    if native_is_bigendian:
        assert res[sizeofi:] == b'\x00' * (sizeofi-1) + b'\x05'
    else:
        assert res[sizeofi:] == b'\x05' + b'\x00' * (sizeofi-1)
    assert pack("q", -1) == b'\xff' * calcsize("q")

def test_unpack_native():
    """
    Check unpacking with the native format.
    """
    calcsize = struct.calcsize
    pack = struct.pack
    unpack = struct.unpack
    assert unpack("bi", pack("bi", -2, 5)) == (-2, 5)
    assert unpack("q", b'\xff' * calcsize("q")) == (-1,)

def test_string_format():
    """
    Check the 's' format character.
    """
    pack = struct.pack
    unpack = struct.unpack
    assert pack("7s", b"hello") == b"hello\x00\x00"
    assert pack("5s", b"world") == b"world"
    assert pack("3s", b"spam") == b"spa"
    assert pack("0s", b"foo") == b""
    assert unpack("7s", b"hello\x00\x00") == (b"hello\x00\x00",)
    assert unpack("5s3s", b"worldspa") == (b"world", b"spa")
    assert unpack("0s", b"") == (b"",)

def test_pascal_format():
    """
    Check the 'p' format character.
    """
    pack = struct.pack
    unpack = struct.unpack
    longstring = bytes(range(135)) * 2    # this has 270 chars
    longpacked300 = b"\xff" + longstring + b"\x00" * (299-len(longstring))
    assert pack("8p", b"hello") == b"\x05hello\x00\x00"
    assert pack("6p", b"world") == b"\x05world"
    assert pack("4p", b"spam") == b"\x03spa"
    assert pack("1p", b"foo") == b"\x00"
    assert pack("10p", longstring) == b"\x09" + longstring[:9]
    assert pack("300p", longstring) == longpacked300
    assert unpack("8p", b"\x05helloxx") == (b"hello",)
    assert unpack("5p", b"\x80abcd") == (b"abcd",)
    assert unpack("1p", b"\x03") == (b"",)
    assert unpack("300p", longpacked300) == (longstring[:255],)

def test_char_format():
    """
    Check the 'c' format character.
    """
    pack = struct.pack
    unpack = struct.unpack
    assert pack("c", b"?") == b"?"
    assert pack("5c", b"a", b"\xc0", b"\x00", b"\n", b"-") == b"a\xc0\x00\n-"
    assert unpack("c", b"?") == (b"?",)
    assert unpack("5c", b"a\xc0\x00\n-") == (b"a", b"\xc0", b"\x00", b"\n", b"-")

def test_pad_format():
    """
    Check the 'x' format character.
    """
    pack = struct.pack
    unpack = struct.unpack
    assert pack("x") == b"\x00"
    assert pack("5x") == b"\x00" * 5
    assert unpack("x", b"?") == ()
    assert unpack("5x", b"hello") == ()

def test_native_floats():
    """
    Check the 'd' and 'f' format characters on native packing.
    """
    calcsize = struct.calcsize
    pack = struct.pack
    unpack = struct.unpack
    data = pack("d", 12.34)
    assert len(data) == calcsize("d")
    assert unpack("d", data) == (12.34,)     # no precision lost
    data = pack("f", 12.34)
    assert len(data) == calcsize("f")
    res, = unpack("f", data)
    assert res != 12.34                      # precision lost
    assert abs(res - 12.34) < 1E-6

def test_standard_floats():
    """
    Check the 'd' and 'f' format characters on standard packing.
    """
    pack = struct.pack
    unpack = struct.unpack
    assert pack("!d", 12.5) == b'@)\x00\x00\x00\x00\x00\x00'
    assert pack("<d", -12.5) == b'\x00\x00\x00\x00\x00\x00)\xc0'
    assert unpack("!d", b'\xc0)\x00\x00\x00\x00\x00\x00') == (-12.5,)
    assert unpack("<d", b'\x00\x00\x00\x00\x00\x00)@') == (12.5,)
    assert pack("!f", -12.5) == b'\xc1H\x00\x00'
    assert pack("<f", 12.5) == b'\x00\x00HA'
    assert unpack("!f", b'AH\x00\x00') == (12.5,)
    assert unpack("<f", b'\x00\x00H\xc1') == (-12.5,)
    raises(OverflowError, pack, "<f", 10e100)

def test_half_floats():
    import sys
    pack = struct.pack
    unpack = struct.unpack
    assert pack("<e", 65504.0) == b'\xff\x7b'
    assert pack(">e", 65504.0) == b'\x7b\xff'
    assert unpack(">e", b'\x7b\xff') == (65504.0,)
    raises(OverflowError, pack, "<e", 1e6)
    if sys.byteorder == 'little':
        assert pack("e", 65504.0) == b'\xff\x7b'
        assert unpack("e", b'\xff\x7b') == (65504.0,)
    else:
        assert pack("e", 65504.0) == b'\x7b\xff'
        assert unpack("e", b'\x7b\xff') == (65504.0,)

def test_bool():
    pack = struct.pack
    assert pack("!?", True) == b'\x01'
    assert pack(">?", True) == b'\x01'
    assert pack("!?", False) == b'\x00'
    assert pack(">?", False) == b'\x00'
    assert pack("@?", True) == b'\x01'
    assert pack("@?", False) == b'\x00'
    assert struct.unpack("?", b'X')[0] is True
    raises(TypeError, struct.unpack, "?", 'X')

def test_transitiveness():
    c = b'a'
    b = 1
    h = 255
    i = 65535
    l = 65536
    f = 3.1415
    d = 3.1415
    t = True

    for prefix in ('', '@', '<', '>', '=', '!'):
        for format in ('xcbhilfd?', 'xcBHILfd?'):
            format = prefix + format
            s = struct.pack(format, c, b, h, i, l, f, d, t)
            cp, bp, hp, ip, lp, fp, dp, tp = struct.unpack(format, s)
            assert cp == c
            assert bp == b
            assert hp == h
            assert ip == i
            assert lp == l
            assert int(100 * fp) == int(100 * f)
            assert int(100 * dp) == int(100 * d)
            assert tp == t

def test_struct_error():
    """
    Check the various ways to get a struct.error.  Note that CPython
    and PyPy might disagree on the specific exception raised in a
    specific situation, e.g. struct.error/TypeError/OverflowError.
    """
    import sys
    calcsize = struct.calcsize
    pack = struct.pack
    unpack = struct.unpack
    error = struct.error
    try:
        calcsize("12")              # incomplete struct format
    except error:                   # (but ignored on CPython)
        pass
    raises(error, calcsize, "[")    # bad char in struct format
    raises(error, calcsize, "!P")   # bad char in struct format
    raises(error, pack, "ii", 15)   # struct format requires more arguments
    raises(error, pack, "i", 3, 4)  # too many arguments for struct format
    raises(error, unpack, "ii", b"?")# unpack str size too short for format
    raises(error, unpack, "b", b"??")# unpack str size too long for format
    raises(error, pack, "c", b"foo") # expected a string of length 1
    try:
        pack("0p")                  # bad '0p' in struct format
    except error:                   # (but ignored on CPython)
        pass
    if '__pypy__' in sys.builtin_module_names:
        raises(error, unpack, "0p", b"")   # segfaults on CPython 2.5.2!
    raises(error, pack, "b", 150)   # argument out of range
    # XXX the accepted ranges still differs between PyPy and CPython
    exc = raises(error, pack, ">d", 'abc')
    assert str(exc.value) == "required argument is not a float"
    exc = raises(error, pack, ">l", 'abc')
    assert str(exc.value) == "required argument is not an integer"
    exc = raises(error, pack, ">H", 'abc')
    assert str(exc.value) == "required argument is not an integer"

def test_overflow_error():
    """
    Check OverflowError cases.
    """
    calcsize = struct.calcsize
    someerror = (OverflowError, struct.error)
    raises(someerror, calcsize, "%dc" % (sys.maxsize+1,))
    raises(someerror, calcsize, "999999999999999999999999999c")
    raises(someerror, calcsize, "%di" % (sys.maxsize,))
    raises(someerror, calcsize, "%dcc" % (sys.maxsize,))
    raises(someerror, calcsize, "c%dc" % (sys.maxsize,))
    raises(someerror, calcsize, "%dci" % (sys.maxsize,))

def test_unicode():
    """
    A PyPy extension: accepts the 'u' format character in native mode,
    just like the array module does.  (This is actually used in the
    implementation of our interp-level array module.)
    """
    import sys
    if '__pypy__' not in sys.builtin_module_names:
        skip("PyPy extension")
    data = struct.pack("uuu", 'X', 'Y', 'Z')
    # this assumes UCS4; adapt/extend the test on platforms where we use
    # another format
    assert data == b'X\x00\x00\x00Y\x00\x00\x00Z\x00\x00\x00'
    assert struct.unpack("uuu", data) == ('X', 'Y', 'Z')

def test_unpack_memoryview():
    """
    memoryview objects can be passed to struct.unpack().
    """
    b = memoryview(struct.pack("ii", 62, 12))
    assert struct.unpack("ii", b) == (62, 12)
    raises(struct.error, struct.unpack, "i", b)

def test_pack_buffer():
    import array, sys
    b = array.array('b', b'\x00' * 19)
    sz = struct.calcsize("ii")
    for offset in [2, -17]:
        struct.pack_into("ii", b, offset, 17, 42)
        assert bytes(memoryview(b)) == (b'\x00' * 2 +
                                        struct.pack("ii", 17, 42) +
                                        b'\x00' * (19-sz-2))
    b2 = array.array('b', b'\x00' * 19)
    struct.pack_into("ii", memoryview(b2), 0, 17, 42)
    assert bytes(b2) == struct.pack("ii", 17, 42) + (b'\x00' * 11)

    exc = raises(TypeError, struct.pack_into, "ii", b'test', 0, 17, 42)
    if '__pypy__' in sys.modules:
        assert str(exc.value) == "a read-write bytes-like object is required, not bytes"
    exc = raises(struct.error, struct.pack_into, "ii", b[0:1], 0, 17, 42)
    assert str(exc.value) == "pack_into requires a buffer of at least 8 bytes for packing 8 bytes at offset 0 (actual buffer size is 1)"
    exc = raises(struct.error, struct.pack_into, "ii", b, -3, 17, 42)
    assert str(exc.value) == "no space to pack 8 bytes at offset -3"
    exc = raises(struct.error, struct.pack_into, "ii", b[:8], -9, 17, 42)
    assert str(exc.value) == "offset -9 out of range for 8-byte buffer"

def test_unpack_buffer():
    import array
    b = array.array('b', b'\x00' * 19)
    for offset in [2, -17]:
        struct.pack_into("ii", b, offset, 17, 42)
    assert struct.unpack_from("ii", b, 2) == (17, 42)
    assert struct.unpack_from("ii", b, -17) == (17, 42)
    assert struct.unpack_from("ii", memoryview(b)[2:]) == (17, 42)
    assert struct.unpack_from("ii", memoryview(b), 2) == (17, 42)
    exc = raises(TypeError, struct.unpack_from, "ii", 123)
    assert str(exc.value) == "a bytes-like object is required, not int"
    exc = raises(TypeError, struct.unpack_from, "ii", None)
    assert str(exc.value) == "a bytes-like object is required, not None"
    exc = raises(struct.error, struct.unpack_from, "ii", b'')
    assert str(exc.value).startswith("unpack_from requires a buffer of at least 8 bytes")
    exc = raises(struct.error, struct.unpack_from, "ii", memoryview(b''))
    assert str(exc.value).startswith("unpack_from requires a buffer of at least 8 bytes")

def test_iter_unpack():
    import array
    b = array.array('b', b'\0' * 16)
    s = struct.Struct('ii')
    it = s.iter_unpack(b)
    assert it.__length_hint__() == 2
    assert list(it) == [(0, 0), (0, 0)]
    it = struct.iter_unpack('ii', b)
    assert list(it) == [(0, 0), (0, 0)]
    #
    it = s.iter_unpack(b)
    next(it)
    assert it.__length_hint__() == 1
    next(it)
    assert it.__length_hint__() == 0
    assert list(it) == []
    assert it.__length_hint__() == 0

def test_iter_unpack_bad_length():
    s = struct.Struct('!i')
    lst = list(s.iter_unpack(b'1234'))
    assert lst == [(0x31323334,)]
    lst = list(s.iter_unpack(b''))
    assert lst == []
    raises(struct.error, s.iter_unpack, b'12345')
    raises(struct.error, s.iter_unpack, b'123')
    raises(struct.error, struct.iter_unpack, 'h', b'12345')

def test_iter_unpack_empty_struct():
    s = struct.Struct('')
    raises(struct.error, s.iter_unpack, b'')
    raises(struct.error, s.iter_unpack, b'?')

def test___float__():
    class MyFloat(object):
        def __init__(self, x):
            self.x = x
        def __float__(self):
            return self.x

    obj = MyFloat(42.3)
    data = struct.pack('d', obj)
    obj2, = struct.unpack('d', data)
    assert type(obj2) is float
    assert obj2 == 42.3

def test_struct_object():
    s = struct.Struct('i')
    assert s.unpack(s.pack(42)) == (42,)
    assert s.unpack_from(memoryview(s.pack(42))) == (42,)

def test_struct_weakrefable():
    import weakref
    weakref.ref(struct.Struct('i'))

def test_struct_subclass():
    class S(struct.Struct):
        def __init__(self):
            assert self.size == -1
            super(S, self).__init__('b')
            assert self.size == 1
    assert S().unpack(b'a') == (ord(b'a'),)

def test_overflow():
    raises(struct.error, struct.pack, 'i', 1<<65)

def test_struct_object_attrib():
    s = struct.Struct('i')
    assert s.format == 'i'

def test_trailing_counter():
    import array
    store = array.array('b', b' '*100)

    # format lists containing only count spec should result in an error
    raises(struct.error, struct.pack, '12345')
    raises(struct.error, struct.unpack, '12345', b'')
    raises(struct.error, struct.pack_into, '12345', store, 0)
    raises(struct.error, struct.unpack_from, '12345', store, 0)

    # Format lists with trailing count spec should result in an error
    raises(struct.error, struct.pack, 'c12345', b'x')
    raises(struct.error, struct.unpack, 'c12345', b'x')
    raises(struct.error, struct.pack_into, 'c12345', store, 0, b'x')
    raises(struct.error, struct.unpack_from, 'c12345', store, 0)

    # Mixed format tests
    raises(struct.error, struct.pack, '14s42', b'spam and eggs')
    raises(struct.error, struct.unpack, '14s42', b'spam and eggs')
    raises(struct.error, struct.pack_into, '14s42', store, 0, b'spam and eggs')
    raises(struct.error, struct.unpack_from, '14s42', store, 0)

def test_1530559():
    # Native 'q' packing isn't available on systems that don't have the C
    # long long type.
    try:
        struct.pack('q', 5)
    except struct.error:
        HAVE_LONG_LONG = False
    else:
        HAVE_LONG_LONG = True
    integer_codes = ('b', 'B', 'h', 'H', 'i', 'I', 'l', 'L', 'q', 'Q')
    for byteorder in '', '@', '=', '<', '>', '!':
        for code in integer_codes:
            if (byteorder in ('', '@') and code in ('q', 'Q') and
                not HAVE_LONG_LONG):
                continue
            format = byteorder + code
            raises(struct.error, struct.pack, format, 1.0)
            raises(struct.error, struct.pack, format, 1.5)
    raises(struct.error, struct.pack, 'P', 1.0)
    raises(struct.error, struct.pack, 'P', 1.5)

def test_integers():
    # Native 'q' packing isn't available on systems that don't have the C
    # long long type.
    try:
        struct.pack('q', 5)
    except struct.error:
        HAVE_LONG_LONG = False
    else:
        HAVE_LONG_LONG = True

    integer_codes = ('b', 'B', 'h', 'H', 'i', 'I', 'l', 'L', 'q', 'Q')
    byteorders = '', '@', '=', '<', '>', '!'

    def run_not_int_test(format):
        class NotAnInt:
            def __int__(self):
                return 42
        raises((TypeError, struct.error),
                struct.pack, format,
                NotAnInt())

    for code in integer_codes:
        for byteorder in byteorders:
            if (byteorder in ('', '@') and code in ('q', 'Q') and
                not HAVE_LONG_LONG):
                continue
            format = byteorder+code
            t = run_not_int_test(format)

def test_struct_with_bytes_as_format_string():
    # why??
    assert struct.calcsize(b'!ii') == 8
    b = memoryview(bytearray(8))
    struct.iter_unpack(b'ii', b)
    struct.pack(b"ii", 45, 56)
    struct.pack_into(b"ii", b, 0, 45, 56)
    struct.unpack(b"ii", b"X" * 8)
    assert struct.unpack_from(b"ii", b) == (45, 56)
    struct.Struct(b"ii")

def test_boundary_error_message_with_large_offset():
    # Test overflows cause by large offset and value size (bpo-30245)
    expected = (
        'pack_into requires a buffer of at least ' + str(sys.maxsize + 4) +
        ' bytes for packing 4 bytes at offset ' + str(sys.maxsize) +
        ' (actual buffer size is 10)'
    )
    exc = raises(struct.error, struct.pack_into,
                 '<I', bytearray(10), sys.maxsize, 1)
    assert str(exc.value) == expected
