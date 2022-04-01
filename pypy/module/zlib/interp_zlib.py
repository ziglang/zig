import sys
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.error import OperationError, oefmt
from rpython.rlib.rarithmetic import intmask, r_uint, r_uint32
from rpython.rlib.objectmodel import keepalive_until_here

from rpython.rlib import rzlib


@unwrap_spec(string='bufferstr', start='truncatedint_w')
def crc32(space, string, start = rzlib.CRC32_DEFAULT_START):
    """
    crc32(string[, start]) -- Compute a CRC-32 checksum of string.

    An optional starting value can be specified.  The returned checksum is
    an integer.
    """
    ustart = r_uint(r_uint32(start))
    checksum = rzlib.crc32(string, ustart)
    return space.newint(checksum)


@unwrap_spec(string='bufferstr', start='truncatedint_w')
def adler32(space, string, start=rzlib.ADLER32_DEFAULT_START):
    """
    adler32(string[, start]) -- Compute an Adler-32 checksum of string.

    An optional starting value can be specified.  The returned checksum is
    an integer.
    """
    ustart = r_uint(r_uint32(start))
    checksum = rzlib.adler32(string, ustart)
    return space.newint(checksum)


class Cache:
    def __init__(self, space):
        self.w_error = space.new_exception_class("zlib.error")

def zlib_error(space, msg):
    w_error = space.fromcache(Cache).w_error
    return OperationError(w_error, space.newtext(msg))


@unwrap_spec(data='bufferstr', level=int)
def compress(space, data, level=rzlib.Z_DEFAULT_COMPRESSION):
    """
    compress(data[, level]) -- Returned compressed string.

    Optional arg level is the compression level, in 1-9.
    """
    try:
        try:
            stream = rzlib.deflateInit(level)
        except ValueError:
            raise zlib_error(space, "Bad compression level")
        try:
            result = rzlib.compress(stream, data, rzlib.Z_FINISH)
        finally:
            rzlib.deflateEnd(stream)
    except rzlib.RZlibError as e:
        raise zlib_error(space, e.msg)
    return space.newbytes(result)


@unwrap_spec(string='bufferstr', wbits="c_int", bufsize=int)
def decompress(space, string, wbits=rzlib.MAX_WBITS, bufsize=0):
    """
    decompress(string[, wbits[, bufsize]]) -- Return decompressed string.

    Optional arg wbits is the window buffer size.  Optional arg bufsize is
    only for compatibility with CPython and is ignored.
    """
    try:
        try:
            stream = rzlib.inflateInit(wbits)
        except ValueError:
            raise zlib_error(space, "Bad window buffer size")
        try:
            result, _, _ = rzlib.decompress(stream, string, rzlib.Z_FINISH)
        finally:
            rzlib.inflateEnd(stream)
    except rzlib.RZlibError as e:
        raise zlib_error(space, e.msg)
    return space.newbytes(result)


class ZLibObject(W_Root):
    """
    Common base class for Compress and Decompress.
    """
    stream = rzlib.null_stream

    def __init__(self, space):
        self._lock = space.allocate_lock()

    def lock(self):
        """To call before using self.stream."""
        self._lock.acquire(True)

    def unlock(self):
        """To call after using self.stream."""
        self._lock.release()
        keepalive_until_here(self)
        # subtle: we have to make sure that 'self' is not garbage-collected
        # while we are still using 'self.stream' - hence the keepalive.


class Compress(ZLibObject):
    """
    Wrapper around zlib's z_stream structure which provides convenient
    compression functionality.
    """
    def __init__(self, space, stream):
        ZLibObject.__init__(self, space)
        self.stream = stream
        self.register_finalizer(space)

    def _finalize_(self):
        """Automatically free the resources used by the stream."""
        if self.stream:
            rzlib.deflateEnd(self.stream)
            self.stream = rzlib.null_stream

    @unwrap_spec(data='bufferstr')
    def compress(self, space, data):
        """
        compress(data) -- Return a string containing data compressed.

        After calling this function, some of the input data may still be stored
        in internal buffers for later processing.

        Call the flush() method to clear these buffers.
        """
        try:
            self.lock()
            try:
                if not self.stream:
                    raise zlib_error(space,
                                     "compressor object already flushed")
                result = rzlib.compress(self.stream, data)
            finally:
                self.unlock()
        except rzlib.RZlibError as e:
            raise zlib_error(space, e.msg)
        return space.newbytes(result)

    def copy(self, space):
        """
        copy() -- Return a copy of the compression object.
        """
        try:
            self.lock()
            try:
                if not self.stream:
                    raise oefmt(
                        space.w_ValueError,
                        "Compressor was already flushed",
                    )
                copied = rzlib.deflateCopy(self.stream)
            finally:
                self.unlock()
        except rzlib.RZlibError as e:
            raise zlib_error(space, e.msg)
        return Compress(space=space, stream=copied)

    @unwrap_spec(mode="c_int")
    def flush(self, space, mode=rzlib.Z_FINISH):
        """
        flush( [mode] ) -- Return a string containing any remaining compressed
        data.

        mode can be one of the constants Z_SYNC_FLUSH, Z_FULL_FLUSH, Z_FINISH;
        the default value used when mode is not specified is Z_FINISH.

        If mode == Z_FINISH, the compressor object can no longer be used after
        calling the flush() method.  Otherwise, more data can still be
        compressed.
        """
        try:
            self.lock()
            try:
                if not self.stream:
                    raise zlib_error(space,
                                     "compressor object already flushed")
                result = rzlib.compress(self.stream, '', mode)
                if mode == rzlib.Z_FINISH:    # release the data structures now
                    rzlib.deflateEnd(self.stream)
                    self.stream = rzlib.null_stream
                    self.may_unregister_rpython_finalizer(space)
            finally:
                self.unlock()
        except rzlib.RZlibError as e:
            raise zlib_error(space, e.msg)
        return space.newbytes(result)


@unwrap_spec(level=int, method=int, wbits=int, memLevel=int, strategy=int)
def Compress___new__(space, w_subtype, level=rzlib.Z_DEFAULT_COMPRESSION,
                     method=rzlib.Z_DEFLATED,             # \
                     wbits=rzlib.MAX_WBITS,               #  \   undocumented
                     memLevel=rzlib.DEF_MEM_LEVEL,        #  /    parameters
                     strategy=rzlib.Z_DEFAULT_STRATEGY,   # /
                     w_zdict=None):
    """
    Create a new z_stream and call its initializer.
    """
    if space.is_none(w_zdict):
        zdict = None
    else:
        zdict = space.charbuf_w(w_zdict)
    w_stream = space.allocate_instance(Compress, w_subtype)
    w_stream = space.interp_w(Compress, w_stream)
    try:
        stream = rzlib.deflateInit(level, method, wbits, memLevel, strategy,
                                   zdict=zdict)
    except rzlib.RZlibError as e:
        raise zlib_error(space, e.msg)
    except ValueError:
        raise oefmt(space.w_ValueError, "Invalid initialization option")
    Compress.__init__(w_stream, space, stream)
    return w_stream


Compress.typedef = TypeDef(
    'Compress',
    __new__ = interp2app(Compress___new__),
    copy = interp2app(Compress.copy),
    compress = interp2app(Compress.compress),
    flush = interp2app(Compress.flush),
    __doc__ = """compressobj([level]) -- Return a compressor object.

Optional arg level is the compression level, in 1-9.
""")


class Decompress(ZLibObject):
    """
    Wrapper around zlib's z_stream structure which provides convenient
    decompression functionality.
    """
    def __init__(self, space, stream, zdict, unused_data, unconsumed_tail):
        """
        Initialize a new decompression object.

        wbits is an integer between 8 and MAX_WBITS or -8 and -MAX_WBITS
        (inclusive) giving the number of "window bits" to use for compression
        and decompression.  See the documentation for deflateInit2 and
        inflateInit2.
        """
        ZLibObject.__init__(self, space)

        self.stream = stream
        self.zdict = zdict
        self.unused_data = unused_data
        self.unconsumed_tail = unconsumed_tail
        self.eof = False
        self.register_finalizer(space)

    def _finalize_(self):
        """Automatically free the resources used by the stream."""
        if self.stream:
            rzlib.inflateEnd(self.stream)
            self.stream = rzlib.null_stream

    def _save_unconsumed_input(self, data, finished, unused_len):
        unused_start = len(data) - unused_len
        assert unused_start >= 0
        tail = data[unused_start:]
        if finished:
            self.unconsumed_tail = ''
            self.unused_data += tail
        else:
            self.unconsumed_tail = tail

    @unwrap_spec(data='bufferstr', max_length=int)
    def decompress(self, space, data, max_length=0):
        """
        decompress(data[, max_length]) -- Return a string containing the
        decompressed version of the data.

        If the max_length parameter is specified then the return value will be
        no longer than max_length.  Unconsumed input data will be stored in the
        unconsumed_tail attribute.
        """
        if max_length == 0:
            max_length = sys.maxint
        elif max_length < 0:
            raise oefmt(space.w_ValueError,
                        "max_length must be greater than zero")
        try:
            self.lock()
            try:
                result = rzlib.decompress(self.stream, data,
                                          max_length=max_length,
                                          zdict=self.zdict)
            finally:
                self.unlock()
        except rzlib.RZlibError as e:
            raise zlib_error(space, e.msg)

        string, finished, unused_len = result
        self.eof = finished
        self._save_unconsumed_input(data, finished, unused_len)
        return space.newbytes(string)

    def copy(self, space):
        """
        copy() -- Return a copy of the decompression object.
        """
        try:
            self.lock()
            try:
                if not self.stream:
                    raise oefmt(
                        space.w_ValueError,
                        "Decompressor was already flushed",
                    )
                copied = rzlib.inflateCopy(self.stream)
            finally:
                self.unlock()
        except rzlib.RZlibError as e:
            raise zlib_error(space, e.msg)

        return Decompress(
            space=space,
            stream=copied,
            unused_data=self.unused_data,
            unconsumed_tail=self.unconsumed_tail,
            zdict=self.zdict,
        )

    def flush(self, space, w_length=None):
        """
        flush( [length] ) -- This is kept for backward compatibility,
        because each call to decompress() immediately returns as much
        data as possible.
        """
        if w_length is not None:
            length = space.int_w(w_length)
            if length <= 0:
                raise oefmt(space.w_ValueError,
                            "length must be greater than zero")
        if not self.stream:
            return space.newbytes('')
        data = self.unconsumed_tail
        try:
            self.lock()
            try:
                result = rzlib.decompress(self.stream, data, rzlib.Z_FINISH,
                                          zdict=self.zdict)
            finally:
                self.unlock()
        except rzlib.RZlibError:
            string = ""
        else:
            string, finished, unused_len = result
            self._save_unconsumed_input(data, finished, unused_len)
            if finished:
                rzlib.inflateEnd(self.stream)
                self.stream = rzlib.null_stream
        return space.newbytes(string)


@unwrap_spec(wbits=int)
def Decompress___new__(space, w_subtype, wbits=rzlib.MAX_WBITS, w_zdict=None):
    """
    Create a new Decompress and call its initializer.
    """
    if space.is_none(w_zdict):
        zdict = None
    else:
        zdict = space.charbuf_w(w_zdict)
    w_stream = space.allocate_instance(Decompress, w_subtype)
    w_stream = space.interp_w(Decompress, w_stream)
    try:
        stream = rzlib.inflateInit(wbits, zdict=zdict)
    except rzlib.RZlibError as e:
        raise zlib_error(space, e.msg)
    except ValueError:
        raise oefmt(space.w_ValueError, "Invalid initialization option")
    Decompress.__init__(w_stream, space, stream, zdict, '', '')
    return w_stream

def default_buffer_size(space):
    return space.newint(rzlib.OUTPUT_BUFFER_SIZE)

Decompress.typedef = TypeDef(
    'Decompress',
    __new__ = interp2app(Decompress___new__),
    copy = interp2app(Decompress.copy),
    decompress = interp2app(Decompress.decompress),
    flush = interp2app(Decompress.flush),
    unused_data = interp_attrproperty('unused_data', Decompress, wrapfn="newbytes"),
    unconsumed_tail = interp_attrproperty('unconsumed_tail', Decompress, wrapfn="newbytes"),
    eof = interp_attrproperty('eof', Decompress, wrapfn="newbool"),
    __doc__ = """decompressobj([wbits]) -- Return a decompressor object.

Optional arg wbits is the window buffer size.
""")
