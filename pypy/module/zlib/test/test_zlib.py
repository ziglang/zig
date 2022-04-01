"""
Tests for the zlib module.
"""

import pypy
import py

try:
    import zlib
except ImportError:
    py.test.skip("no zlib module on this host Python")

from pypy.interpreter.gateway import interp2app
try:
    from pypy.module.zlib import interp_zlib
    from rpython.rlib import rzlib
except ImportError:
    py.test.skip("no zlib C library on this machine")


class AppTestZlib(object):
    spaceconfig = dict(usemodules=['zlib'])

    def setup_class(cls):
        """
        Create a space with the zlib module and import it for use by the tests.
        Also create some compressed data with the bootstrap zlib module so that
        compression and decompression tests have a little real data to assert
        against.
        """
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

        cls.w_zlib = cls.space.getbuiltinmodule('zlib')
        expanded = b'some bytes which will be compressed'
        cls.w_expanded = cls.space.newbytes(expanded)
        cls.w_compressed = cls.space.newbytes(zlib.compress(expanded))
        cls.w_LICENSE = cls.space.newbytes(
            py.path.local(pypy.__file__).dirpath().dirpath()
            .join('LICENSE').read())

        def intentionally_break_a_z_stream(space, w_zobj):
            """
            Intentionally break the z_stream associated with a
            compressobj or decompressobj in a way that causes their copy
            methods to raise RZlibErrors.
            """
            from rpython.rtyper.lltypesystem import rffi, lltype
            w_zobj.stream.c_zalloc = rffi.cast(
                lltype.typeOf(w_zobj.stream.c_zalloc),
                rzlib.Z_NULL,
            )

        cls.w_intentionally_break_a_z_stream = cls.space.wrap(
            interp2app(intentionally_break_a_z_stream),
        )

    def test_def_buf_size(self):
        assert self.zlib.DEF_BUF_SIZE >= 0

    def test_error(self):
        """
        zlib.error should be an exception class.
        """
        assert issubclass(self.zlib.error, Exception)

    def test_crc32(self):
        """
        When called with a string, zlib.crc32 should compute its CRC32 and
        return it as an unsigned 32 bit integer.
        """
        assert self.zlib.crc32(b'') == 0
        assert self.zlib.crc32(b'\0') == 3523407757
        assert self.zlib.crc32(b'hello, world.') == 3358036098

    def test_crc32_start_value(self):
        """
        When called with a string and an integer, zlib.crc32 should compute the
        CRC32 of the string using the integer as the starting value.
        """
        assert self.zlib.crc32(b'', 42) == 42
        assert self.zlib.crc32(b'\0', 42) == 163128923
        assert self.zlib.crc32(b'hello, world.', 42) == 1090960721
        hello = b'hello, '
        hellocrc = self.zlib.crc32(hello)
        world = b'world.'
        helloworldcrc = self.zlib.crc32(world, hellocrc)
        assert helloworldcrc == self.zlib.crc32(hello + world)

    def test_crc32_negative_start(self):
        v = self.zlib.crc32(b'', -1)
        assert v == 4294967295

    def test_crc32_negative_long_start(self):
        v = self.zlib.crc32(b'', -1)
        assert v == 4294967295
        assert self.zlib.crc32(b'foo', -99999999999999999999999) == 1611238463

    def test_crc32_long_start(self):
        import sys
        v = self.zlib.crc32(b'', sys.maxsize*2)
        assert v == 4294967294
        assert self.zlib.crc32(b'foo', 99999999999999999999999) == 1635107045

    def test_adler32(self):
        """
        When called with a string, zlib.adler32() should compute its adler 32
        checksum and return it as an unsigned 32 bit integer.
        """
        assert self.zlib.adler32(b'') == 1
        assert self.zlib.adler32(b'\0') == 65537
        assert self.zlib.adler32(b'hello, world.') == 571147447
        assert self.zlib.adler32(b'x' * 23) == 2172062409

    def test_adler32_start_value(self):
        """
        When called with a string and an integer, zlib.adler32 should compute
        the adler 32 checksum of the string using the integer as the starting
        value.
        """
        assert self.zlib.adler32(b'', 42) == 42
        assert self.zlib.adler32(b'\0', 42) == 2752554
        assert self.zlib.adler32(b'hello, world.', 42) == 606078176
        assert self.zlib.adler32(b'x' * 23, 42) == 2233862898
        hello = b'hello, '
        hellosum = self.zlib.adler32(hello)
        world = b'world.'
        helloworldsum = self.zlib.adler32(world, hellosum)
        assert helloworldsum == self.zlib.adler32(hello + world)

        assert self.zlib.adler32(b'foo', -1) == 45547858
        assert self.zlib.adler32(b'foo', 99999999999999999999999) == 4180148562

    def test_invalidLevel(self):
        """
        zlib.compressobj should raise ValueError when an out of bounds level is
        passed to it.
        """
        raises(ValueError, self.zlib.compressobj, -2)
        raises(ValueError, self.zlib.compressobj, 10)

    def test_compression(self):
        """
        zlib.compressobj should return an object which can be used to compress
        bytes.
        """
        compressor = self.zlib.compressobj()
        bytes = compressor.compress(self.expanded)
        raises(OverflowError, compressor.flush, 2**31)
        bytes += compressor.flush()
        assert bytes == self.compressed

    def test_decompression(self):
        """
        zlib.decompressobj should return an object which can be used to
        decompress bytes.
        """
        import sys
        decompressor = self.zlib.decompressobj()
        bytes = decompressor.decompress(self.compressed)
        bytes += decompressor.flush()
        assert bytes == self.expanded

    def test_compress(self):
        """
        Test the zlib.compress() function.
        """
        bytes = self.zlib.compress(self.expanded)
        assert bytes == self.compressed

    def test_decompress(self):
        """
        Test the zlib.decompress() function.
        """
        bytes = self.zlib.decompress(self.compressed)
        assert bytes == self.expanded

    def test_decompress_invalid_input(self):
        """
        Try to feed garbage to zlib.decompress().
        """
        raises(self.zlib.error, self.zlib.decompress, self.compressed[:-2])
        raises(self.zlib.error, self.zlib.decompress, b'foobar')

    def test_bad_arguments(self):
        import zlib, sys
        BIG = sys.maxsize + 1
        raises(ValueError, zlib.decompressobj().flush, 0)
        raises(ValueError, zlib.decompressobj().flush, -1)
        raises(TypeError, zlib.decompressobj().flush, None)
        raises(ValueError, zlib.decompressobj().decompress, b'abc', -1)
        raises(TypeError, zlib.decompressobj().decompress, b'abc', None)
        raises(TypeError, self.zlib.decompress, self.compressed, None)
        raises(OverflowError, self.zlib.decompress, self.compressed, BIG)

    def test_empty_flush(self):
        import zlib
        co = zlib.compressobj(zlib.Z_BEST_COMPRESSION)
        assert co.flush()  # Returns a zlib header
        dco = zlib.decompressobj()
        assert dco.flush() == b""

    def test_decompress_eof(self):
        import zlib
        x = b'x\x9cK\xcb\xcf\x07\x00\x02\x82\x01E'  # 'foo'
        dco = zlib.decompressobj()
        assert dco.eof == False
        dco.decompress(x[:-5])
        assert dco.eof == False
        dco.decompress(x[-5:])
        assert dco.eof == True
        dco.flush()
        assert dco.eof == True

    def test_decompress_eof_incomplete_stream(self):
        import zlib
        x = b'x\x9cK\xcb\xcf\x07\x00\x02\x82\x01E'  # 'foo'
        dco = zlib.decompressobj()
        assert dco.eof == False
        dco.decompress(x[:-5])
        assert dco.eof == False
        dco.flush()
        assert dco.eof == False

    def test_decompress_incomplete_stream(self):
        import zlib
        # This is 'foo', deflated
        x = b'x\x9cK\xcb\xcf\x07\x00\x02\x82\x01E'
        # For the record
        assert zlib.decompress(x) == b'foo'
        raises(zlib.error, zlib.decompress, x[:-5])
        # Omitting the stream end works with decompressor objects
        # (see issue #8672).
        dco = zlib.decompressobj()
        y = dco.decompress(x[:-5])
        y += dco.flush()
        assert y == b'foo'

    def test_unused_data(self):
        """
        Try to feed too much data to zlib.decompress().
        It should show up in the unused_data attribute.
        """
        d = self.zlib.decompressobj()
        s = d.decompress(self.compressed + b'extrastuff', 0)
        assert s == self.expanded
        assert d.unused_data == b'extrastuff'
        assert d.flush() == b''
        assert d.unused_data == b'extrastuff'
        # try again with several decompression steps
        d = self.zlib.decompressobj()
        s1 = d.decompress(self.compressed[:10])
        assert d.unused_data == b''
        s2 = d.decompress(self.compressed[10:-3])
        assert d.unused_data == b''
        s3 = d.decompress(self.compressed[-3:] + b'spam' * 100)
        assert d.unused_data == b'spam' * 100
        assert s1 + s2 + s3 == self.expanded
        s4 = d.decompress(b'egg' * 50)
        assert d.unused_data == (b'spam' * 100) + (b'egg' * 50)
        assert s4 == b''

    def test_max_length(self):
        """
        Test the max_length argument of the decompress() method
        and the corresponding unconsumed_tail attribute.
        """
        d = self.zlib.decompressobj()
        data = self.compressed
        for i in range(0, 100, 10):
            s1 = d.decompress(data, 10)
            assert s1 == self.expanded[i:i+10]
            data = d.unconsumed_tail
        assert not data

    def test_max_length_large(self):
        import sys
        d = self.zlib.decompressobj()
        assert d.decompress(self.compressed, sys.maxsize) == self.expanded

    def test_buffer(self):
        """
        We should be able to pass buffer objects instead of strings.
        """
        assert self.zlib.crc32(memoryview(b'hello, world.')) == 3358036098
        assert self.zlib.adler32(memoryview(b'hello, world.')) == 571147447

        compressor = self.zlib.compressobj()
        bytes = compressor.compress(memoryview(self.expanded))
        bytes += compressor.flush()
        assert bytes == self.compressed

        decompressor = self.zlib.decompressobj()
        bytes = decompressor.decompress(memoryview(self.compressed))
        bytes += decompressor.flush()
        assert bytes == self.expanded

        bytes = self.zlib.compress(memoryview(self.expanded))
        assert bytes == self.compressed

        bytes = self.zlib.decompress(memoryview(self.compressed))
        assert bytes == self.expanded

    def test_flush_with_freed_input(self):
        # Issue #16411: decompressor accesses input to last decompress() call
        # in flush(), even if this object has been freed in the meanwhile.
        input1 = b'abcdefghijklmnopqrstuvwxyz'
        input2 = b'QWERTYUIOPASDFGHJKLZXCVBNM'
        data = self.zlib.compress(input1)
        dco = self.zlib.decompressobj()
        dco.decompress(data, 1)
        del data
        data = self.zlib.compress(input2)
        assert dco.flush(1) == input1[1:]
        assert dco.unused_data == b''
        assert dco.unconsumed_tail == b''

    def test_dictionary(self):
        l = self.LICENSE
        # Build a simulated dictionary out of the words in LICENSE.
        words = l.split()
        zdict = b''.join(set(words))
        # Use it to compress LICENSE.
        co = self.zlib.compressobj(zdict=zdict)
        cd = co.compress(l) + co.flush()
        # Verify that it will decompress with the dictionary.
        dco = self.zlib.decompressobj(zdict=zdict)
        assert dco.decompress(cd) + dco.flush() == l
        # Verify that it fails when not given the dictionary.
        dco = self.zlib.decompressobj()
        raises(self.zlib.error, dco.decompress, cd)

    def test_dictionary_streaming(self):
        # This simulates the reuse of a compressor object for compressing
        # several separate data streams.
        co = self.zlib.compressobj(zdict=self.LICENSE)
        do = self.zlib.decompressobj(zdict=self.LICENSE)
        piece = self.LICENSE[1000:1500]
        d0 = co.compress(piece) + co.flush(self.zlib.Z_SYNC_FLUSH)
        d1 = co.compress(piece[100:]) + co.flush(self.zlib.Z_SYNC_FLUSH)
        d2 = co.compress(piece[:-100]) + co.flush(self.zlib.Z_SYNC_FLUSH)
        assert do.decompress(d0) == piece
        do.decompress(d1) == piece[100:]
        do.decompress(d2) == piece[:-100]

    def test_version(self):
        zlib = self.zlib
        assert zlib.ZLIB_VERSION[0] == zlib.ZLIB_RUNTIME_VERSION[0]

    # CPython issue27164
    def test_decompress_raw_with_dictionary(self):
        zlib = self.zlib
        zdict = b'abcdefghijklmnopqrstuvwxyz'
        co = zlib.compressobj(wbits=-zlib.MAX_WBITS, zdict=zdict)
        comp = co.compress(zdict) + co.flush()
        dco = zlib.decompressobj(wbits=-zlib.MAX_WBITS, zdict=zdict)
        uncomp = dco.decompress(comp) + dco.flush()
        assert zdict == uncomp

    def test_decompress_copy(self):
        decompressor = self.zlib.decompressobj()
        d1 = decompressor.decompress(self.compressed[:10])
        assert d1

        copied = decompressor.copy()

        from_copy = copied.decompress(self.compressed[10:])
        from_decompressor = decompressor.decompress(self.compressed[10:])

        assert (d1 + from_copy) == (d1 + from_decompressor)

    def test_cannot_copy_decompressor_with_stream_in_inconsistent_state(self):
        if self.runappdirect: skip("can't run with -A")
        decompressor = self.zlib.decompressobj()
        self.intentionally_break_a_z_stream(zobj=decompressor)
        raises(self.zlib.error, decompressor.copy)

    def test_decompress_copy_carries_along_state(self):
        """
        Decompressor.unused_data and unconsumed_tail are carried along when a
        copy is done.
        """
        decompressor = self.zlib.decompressobj()
        decompressor.decompress(self.compressed, max_length=5)
        unconsumed_tail = decompressor.unconsumed_tail
        assert unconsumed_tail
        assert decompressor.copy().unconsumed_tail == unconsumed_tail

        decompressor.decompress(decompressor.unconsumed_tail)
        decompressor.decompress(b"xxx")
        unused_data = decompressor.unused_data
        assert unused_data
        assert decompressor.copy().unused_data == unused_data

    def test_compress_copy(self):
        compressor = self.zlib.compressobj()
        d1 = compressor.compress(self.expanded[:10])
        assert d1

        copied = compressor.copy()

        from_copy = copied.compress(self.expanded[10:])
        from_compressor = compressor.compress(self.expanded[10:])

        assert (d1 + from_copy) == (d1 + from_compressor)

    @py.test.mark.skipif(rzlib.ZLIB_VERSION in ('1.2.7', '1.2.8', '1.2.3'), reason='does not error check')
    def test_cannot_copy_compressor_with_stream_in_inconsistent_state(self):
        if self.runappdirect: skip("can't run with -A")
        compressor = self.zlib.compressobj()
        self.intentionally_break_a_z_stream(zobj=compressor)
        raises(self.zlib.error, compressor.copy)

    def test_cannot_copy_compressor_with_flushed_stream(self):
        compressor = self.zlib.compressobj()
        compressor.flush()
        raises(ValueError, compressor.copy)

    def test_double_flush(self):
        import zlib
        x = b'x\x9cK\xcb\xcf\x07\x00\x02\x82\x01E'  # 'foo'
        dco = zlib.decompressobj()
        dco.decompress(x)
        dco.flush()
        # multiple flush calls should not raise
        dco.flush()
