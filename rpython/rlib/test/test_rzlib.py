
"""
Tests for the rzlib module.
"""

import py, sys
from rpython.rlib import rzlib
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib import clibffi # for side effect of testing lib_c_name on win32
import zlib

expanded = 'some bytes which will be compressed'
compressed = zlib.compress(expanded)


def test_crc32():
    """
    When called with a string, rzlib.crc32 should compute its CRC32 and
    return it as a unsigned 32 bit integer.
    """
    assert rzlib.crc32('') == r_uint(0)
    assert rzlib.crc32('\0') == r_uint(3523407757)
    assert rzlib.crc32('hello, world.') == r_uint(3358036098)


def test_crc32_start_value():
    """
    When called with a string and an integer, zlib.crc32 should compute the
    CRC32 of the string using the integer as the starting value.
    """
    assert rzlib.crc32('', 42) == r_uint(42)
    assert rzlib.crc32('\0', 42) == r_uint(163128923)
    assert rzlib.crc32('hello, world.', 42) == r_uint(1090960721)
    hello = 'hello, '
    hellocrc = rzlib.crc32(hello)
    world = 'world.'
    helloworldcrc = rzlib.crc32(world, hellocrc)
    assert helloworldcrc == rzlib.crc32(hello + world)


def test_adler32():
    """
    When called with a string, zlib.crc32 should compute its adler 32
    checksum and return it as an unsigned 32 bit integer.
    """
    assert rzlib.adler32('') == r_uint(1)
    assert rzlib.adler32('\0') == r_uint(65537)
    assert rzlib.adler32('hello, world.') == r_uint(571147447)
    assert rzlib.adler32('x' * 23) == r_uint(2172062409)


def test_adler32_start_value():
    """
    When called with a string and an integer, zlib.adler32 should compute
    the adler 32 checksum of the string using the integer as the starting
    value.
    """
    assert rzlib.adler32('', 42) == r_uint(42)
    assert rzlib.adler32('\0', 42) == r_uint(2752554)
    assert rzlib.adler32('hello, world.', 42) == r_uint(606078176)
    assert rzlib.adler32('x' * 23, 42) == r_uint(2233862898)
    hello = 'hello, '
    hellosum = rzlib.adler32(hello)
    world = 'world.'
    helloworldsum = rzlib.adler32(world, hellosum)
    assert helloworldsum == rzlib.adler32(hello + world)


def test_invalidLevel():
    """
    deflateInit() should raise ValueError when an out of bounds level is
    passed to it.
    """
    py.test.raises(ValueError, rzlib.deflateInit, -2)
    py.test.raises(ValueError, rzlib.deflateInit, 10)


def test_deflate_init_end():
    """
    deflateInit() followed by deflateEnd() should work and do nothing.
    """
    stream = rzlib.deflateInit()
    rzlib.deflateEnd(stream)


def test_deflate_set_dictionary():
    text = 'abcabc'
    zdict = 'abc'
    stream = rzlib.deflateInit()
    rzlib.deflateSetDictionary(stream, zdict)
    bytes = rzlib.compress(stream, text, rzlib.Z_FINISH)
    rzlib.deflateEnd(stream)
    
    stream2 = rzlib.inflateInit()

    from rpython.rtyper.lltypesystem import lltype, rffi, rstr
    from rpython.rtyper.annlowlevel import llstr
    from rpython.rlib.rstring import StringBuilder
    with lltype.scoped_alloc(rffi.CCHARP.TO, len(bytes)) as inbuf:
        rstr.copy_string_to_raw(llstr(bytes), inbuf, 0, len(bytes))
        stream2.c_next_in = rffi.cast(rzlib.Bytefp, inbuf)
        rffi.setintfield(stream2, 'c_avail_in', len(bytes))
        with lltype.scoped_alloc(rffi.CCHARP.TO, 100) as outbuf:
            stream2.c_next_out = rffi.cast(rzlib.Bytefp, outbuf)
            bufsize = 100
            rffi.setintfield(stream2, 'c_avail_out', bufsize)
            err = rzlib._inflate(stream2, rzlib.Z_SYNC_FLUSH)
            assert err == rzlib.Z_NEED_DICT
            rzlib.inflateSetDictionary(stream2, zdict)
            rzlib._inflate(stream2, rzlib.Z_SYNC_FLUSH)
            avail_out = rffi.cast(lltype.Signed, stream2.c_avail_out)
            result = StringBuilder()
            result.append_charpsize(outbuf, bufsize - avail_out)

    rzlib.inflateEnd(stream2)
    assert result.build() == text


def test_compression():
    """
    Once we have got a deflate stream, rzlib.compress() 
    should allow us to compress bytes.
    """
    stream = rzlib.deflateInit()
    bytes = rzlib.compress(stream, expanded)
    bytes += rzlib.compress(stream, "", rzlib.Z_FINISH)
    rzlib.deflateEnd(stream)
    assert bytes == compressed


def test_compression_lots_of_data():
    """
    Test compression of more data that fits in a single internal output buffer.
    """
    expanded = repr(range(20000))
    compressed = zlib.compress(expanded)
    print len(expanded), '=>', len(compressed)
    stream = rzlib.deflateInit()
    bytes = rzlib.compress(stream, expanded, rzlib.Z_FINISH)
    rzlib.deflateEnd(stream)
    assert bytes == compressed


def test_inflate_init_end():
    """
    inflateInit() followed by inflateEnd() should work and do nothing.
    """
    stream = rzlib.inflateInit()
    rzlib.inflateEnd(stream)


def test_decompression():
    """
    Once we have got a inflate stream, rzlib.decompress()
    should allow us to decompress bytes.
    """
    stream = rzlib.inflateInit()
    bytes1, finished1, unused1 = rzlib.decompress(stream, compressed)
    bytes2, finished2, unused2 = rzlib.decompress(stream, "", rzlib.Z_FINISH)
    rzlib.inflateEnd(stream)
    assert bytes1 + bytes2 == expanded
    assert finished1 is True
    assert finished2 is True
    assert unused1 == 0
    assert unused2 == 0


def test_decompression_lots_of_data():
    """
    Test compression of more data that fits in a single internal output buffer.
    """
    expanded = repr(range(20000))
    compressed = zlib.compress(expanded)
    print len(compressed), '=>', len(expanded)
    stream = rzlib.inflateInit()
    bytes, finished, unused = rzlib.decompress(stream, compressed,
                                               rzlib.Z_FINISH)
    rzlib.inflateEnd(stream)
    assert bytes == expanded
    assert finished is True
    assert unused == 0


def test_decompression_truncated_input():
    """
    Test that we can accept incomplete input when inflating, but also
    detect this situation when using Z_FINISH.
    """
    expanded = repr(range(20000))
    compressed = zlib.compress(expanded)
    print len(compressed), '=>', len(expanded)
    stream = rzlib.inflateInit()
    data, finished1, unused1 = rzlib.decompress(stream, compressed[:1000])
    assert expanded.startswith(data)
    assert finished1 is False
    assert unused1 == 0
    data2, finished2, unused2 = rzlib.decompress(stream, compressed[1000:2000])
    data += data2
    assert finished2 is False
    assert unused2 == 0
    assert expanded.startswith(data)
    exc = py.test.raises(
        rzlib.RZlibError,
        rzlib.decompress, stream, compressed[2000:-500], rzlib.Z_FINISH)
    msg = "Error -5 while decompressing data: incomplete or truncated stream"
    assert str(exc.value) == msg
    rzlib.inflateEnd(stream)


def test_decompression_too_much_input():
    """
    Check the case where we feed extra data to decompress().
    """
    stream = rzlib.inflateInit()
    data1, finished1, unused1 = rzlib.decompress(stream, compressed[:-5])
    assert finished1 is False
    assert unused1 == 0
    data2, finished2, unused2 = rzlib.decompress(stream,
                                                 compressed[-5:] + 'garbage')
    assert finished2 is True
    assert unused2 == len('garbage')
    assert data1 + data2 == expanded
    data3, finished3, unused3 = rzlib.decompress(stream, 'more_garbage')
    assert finished3 is True
    assert unused3 == len('more_garbage')
    assert data3 == ''

    rzlib.deflateEnd(stream)


def test_decompress_max_length():
    """
    Test the max_length argument of decompress().
    """
    stream = rzlib.inflateInit()
    data1, finished1, unused1 = rzlib.decompress(stream, compressed,
                                                 max_length = 17)
    assert data1 == expanded[:17]
    assert finished1 is False
    assert unused1 > 0
    data2, finished2, unused2 = rzlib.decompress(stream, compressed[-unused1:])
    assert data2 == expanded[17:]
    assert finished2 is True
    assert unused2 == 0

    rzlib.deflateEnd(stream)


def test_compress_copy():
    """
    inflateCopy produces an independent copy of a stream.
    """

    stream = rzlib.deflateInit()

    bytes1 = rzlib.compress(stream, expanded[:10])
    assert bytes1

    copied = rzlib.deflateCopy(stream)

    bytes_stream = rzlib.compress(
        stream,
        expanded[10:],
        rzlib.Z_FINISH,
    )
    assert bytes1 + bytes_stream == compressed
    rzlib.deflateEnd(stream)

    bytes_copy = rzlib.compress(
        copied,
        expanded[10:],
        rzlib.Z_FINISH,
    )
    rzlib.deflateEnd(copied)
    assert bytes1 + bytes_copy == compressed

@py.test.mark.skipif(rzlib.ZLIB_VERSION in ('1.2.3', '1.2.8', '1.2.7'), reason='does not error check')
def test_unsuccessful_compress_copy():
    """
    Errors during unsuccesful deflateCopy operations raise RZlibErrors.
    """
    stream = rzlib.deflateInit()

    # From zlib.h:
    #
    # "deflateCopy returns [...] Z_STREAM_ERROR if the source stream
    #  state was inconsistent (such as zalloc being Z_NULL)"
    from rpython.rtyper.lltypesystem import rffi, lltype
    stream.c_zalloc = rffi.cast(lltype.typeOf(stream.c_zalloc), rzlib.Z_NULL)

    exc = py.test.raises(rzlib.RZlibError, rzlib.deflateCopy, stream)
    msg = "Error -2 while copying compression object: inconsistent stream state"
    assert str(exc.value) == msg
    rzlib.deflateEnd(stream)


def test_decompress_copy():
    """
    inflateCopy produces an independent copy of a stream.
    """

    stream = rzlib.inflateInit()

    bytes1, finished1, unused1 = rzlib.decompress(stream, compressed[:10])
    assert bytes1
    assert finished1 is False

    copied = rzlib.inflateCopy(stream)

    bytes_stream, finished_stream, unused_stream = rzlib.decompress(
        stream,
        compressed[10:],
        rzlib.Z_FINISH,
    )
    assert bytes1 + bytes_stream == expanded
    assert finished_stream is True
    assert unused1 == 0
    assert unused_stream == 0
    rzlib.inflateEnd(stream)

    bytes_copy, finished_copy, unused_copy = rzlib.decompress(
        copied,
        compressed[10:],
        rzlib.Z_FINISH,
    )
    rzlib.inflateEnd(copied)
    assert bytes1 + bytes_copy == expanded
    assert finished_copy is True
    assert unused_copy == 0


def test_unsuccessful_decompress_copy():
    """
    Errors during unsuccesful inflateCopy operations raise RZlibErrors.
    """
    stream = rzlib.inflateInit()

    # From zlib.h:
    #
    # "inflateCopy returns [...] Z_STREAM_ERROR if the source stream
    #  state was inconsistent (such as zalloc being Z_NULL)"
    from rpython.rtyper.lltypesystem import rffi, lltype
    stream.c_zalloc = rffi.cast(lltype.typeOf(stream.c_zalloc), rzlib.Z_NULL)

    exc = py.test.raises(rzlib.RZlibError, rzlib.inflateCopy, stream)
    msg = "Error -2 while copying decompression object: inconsistent stream state"
    assert str(exc.value) == msg
    rzlib.inflateEnd(stream)


def test_cornercases():
    """
    Test degenerate arguments.
    """
    stream = rzlib.deflateInit()
    bytes = rzlib.compress(stream, "")
    bytes += rzlib.compress(stream, "")
    bytes += rzlib.compress(stream, "", rzlib.Z_FINISH)
    assert zlib.decompress(bytes) == ""
    rzlib.deflateEnd(stream)

    stream = rzlib.inflateInit()
    data, finished, unused = rzlib.decompress(stream, "")
    assert data == ""
    assert finished is False
    assert unused == 0
    buf = compressed
    for i in range(10):
        data, finished, unused = rzlib.decompress(stream, buf, max_length=0)
        assert data == ""
        assert finished is False
        assert unused > 0
        buf = buf[-unused:]
    rzlib.deflateEnd(stream)

def test_zlibVersion():
    runtime_version = rzlib.zlibVersion()
    assert runtime_version[0] == rzlib.ZLIB_VERSION[0]

def test_translate_and_large_input():
    from rpython.translator.c.test.test_genc import compile

    def f(i, check):
        bytes = "s" * i
        if check == 1:
            for j in range(3):
                stream = rzlib.deflateInit()
                bytes = rzlib.compress(stream, bytes, rzlib.Z_FINISH)
                rzlib.deflateEnd(stream)
            return bytes
        if check == 2:
            return str(rzlib.adler32(bytes))
        if check == 3:
            return str(rzlib.crc32(bytes))
        return '?'

    fc = compile(f, [int, int])

    test_list = [1, 2, 3, 5, 8, 87, 876, 8765, 87654, 876543, 8765432,
                 127329129]       # up to ~128MB
    if sys.maxint > 2**32:
        test_list.append(4305704715)    # 4.01GB
        # XXX should we have a way to say "I don't have enough RAM,
        # don't run this"?

    for a in test_list:
        print 'Testing compression of "s" * %d' % a
        z = zlib.compressobj()
        count = a
        pieces = []
        while count > 1024*1024:
            pieces.append(z.compress("s" * (1024*1024)))
            count -= 1024*1024
        pieces.append(z.compress("s" * count))
        pieces.append(z.flush(zlib.Z_FINISH))
        expected = ''.join(pieces)
        del pieces
        expected = zlib.compress(expected)
        expected = zlib.compress(expected)
        assert fc(a, 1) == expected

        print 'Testing adler32 and crc32 of "s" * %d' % a
        def compute(function, start):
            count = a
            while count > 0:
                count1 = min(count, 1024*1024)
                start = function("s" * count1, start)
                count -= count1
            return start
        expected_adler32 = compute(zlib.adler32, 1) & (2**32-1)
        expected_crc32 = compute(zlib.crc32, 0) & (2**32-1)
        assert fc(a, 2) == str(expected_adler32)
        assert fc(a, 3) == str(expected_crc32)
