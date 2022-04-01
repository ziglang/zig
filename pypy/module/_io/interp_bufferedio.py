from rpython.rlib.signature import signature
from rpython.rlib import types

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import (
    TypeDef, GetSetProperty, generic_new_descr, interp_attrproperty_w)
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.buffer import SimpleView

from rpython.rlib.buffer import ByteBuffer, RawByteBuffer, SubBuffer
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rarithmetic import r_longlong, intmask
from rpython.rlib import rposix
from rpython.tool.sourcetools import func_renamer
from rpython.rlib.objectmodel import import_from_mixin, try_inline, keepalive_until_here
from rpython.rtyper.lltypesystem import lltype, rffi

from pypy.module._io.interp_iobase import (
    W_IOBase, DEFAULT_BUFFER_SIZE, convert_size, trap_eintr,
    check_readable_w, check_writable_w, check_seekable_w)
from rpython.rlib import rthread

STATE_ZERO, STATE_OK, STATE_DETACHED = range(3)


def make_write_blocking_error(space, written):
    # XXX CPython reads 'errno' here.  I *think* it doesn't make sense,
    # because we might reach this point after calling a write() method
    # that may be overridden by the user, if that method returns None.
    # In that case what we get is a potentially nonsense errno.  But
    # we'll use get_saved_errno() anyway, and hope (like CPython does)
    # that we're getting a reasonable value at this point.
    w_value = space.call_function(
        space.w_BlockingIOError,
        space.newint(rposix.get_saved_errno()),
        space.newtext("write could not complete without blocking"),
        space.newint(written))
    return OperationError(space.w_BlockingIOError, w_value)


class TryLock(object):
    "A Lock that raises RuntimeError when acquired twice by the same thread"
    def __init__(self, space):
        ## XXX cannot free a Lock?
        ## if self.lock:
        ##     self.lock.free()
        self.lock = space.allocate_lock()
        self.owner = 0
        self.operr = oefmt(space.w_RuntimeError, "reentrant call")

    def __enter__(self):
        if not self.lock.acquire(False):
            if self.owner == rthread.get_ident():
                raise self.operr
            self.lock.acquire(True)
        self.owner = rthread.get_ident()

    def __exit__(self,*args):
        self.owner = 0
        self.lock.release()


class BlockingIOError(Exception):
    pass

class W_BufferedIOBase(W_IOBase):
    def _check_init(self, space):
        raise NotImplementedError

    def read_w(self, space, w_size=None):
        """Read and return up to n bytes.

If the argument is omitted, None, or negative, reads and
returns all data until EOF.

If the argument is positive, and the underlying raw stream is
not 'interactive', multiple raw reads may be issued to satisfy
the byte count (unless EOF is reached first).  But for
interactive raw streams (as well as sockets and pipes), at most
one raw read will be issued, and a short result does not imply
that EOF is imminent.

Returns an empty bytes object on EOF.

Returns None if the underlying raw stream was open in non-blocking
mode and no data is available at the moment."""
        self._unsupportedoperation(space, "read")

    def read1_w(self, space, w_size=None):
        """Read and return up to n bytes, with at most one read() call
to the underlying raw stream. A short result does not imply
that EOF is imminent.

Returns an empty bytes object on EOF."""
        self._unsupportedoperation(space, "read1")

    def write_w(self, space, w_data):
        """Write the given buffer to the IO stream.

Returns the number of bytes written, which is always the length of b
in bytes.

Raises BlockingIOError if the buffer is full and the
underlying raw stream cannot accept more data at the moment."""
        self._unsupportedoperation(space, "write")

    def detach_w(self, space):
        """Disconnect this buffer from its underlying raw stream and return it.

After the raw stream has been detached, the buffer is in an unusable
state."""
        self._unsupportedoperation(space, "detach")

    def readinto_w(self, space, w_buffer):
        return self._readinto(space, w_buffer, read_once=False)

    def readinto1_w(self, space, w_buffer):
        return self._readinto(space, w_buffer, read_once=True)

    def _readinto(self, space, w_buffer, read_once):
        rwbuffer = space.writebuf_w(w_buffer)
        length = rwbuffer.getlength()
        methodname = "read1" if read_once else "read"
        w_data = space.call_method(self, methodname, space.newint(length))

        if not space.isinstance_w(w_data, space.w_bytes):
            raise oefmt(space.w_TypeError, "%s() should return bytes",
                        methodname)
        data = space.bytes_w(w_data)
        if len(data) > length:
            raise oefmt(space.w_ValueError,
                        "%s() returned too much data: "
                        "%d bytes requested, %d returned",
                        methodname, length, len(data))
        self.output_slice(space, rwbuffer, 0, data)
        return space.newint(len(data))

W_BufferedIOBase.typedef = TypeDef(
    '_io._BufferedIOBase', W_IOBase.typedef,
    __doc__="""Base class for buffered IO objects.

The main difference with RawIOBase is that the read() method
supports omitting the size argument, and does not have a default
implementation that defers to readinto().

In addition, read(), readinto() and write() may raise
BlockingIOError if the underlying raw stream is in non-blocking
mode and not ready; unlike their raw counterparts, they will never
return None.

A typical implementation should not inherit from a RawIOBase
implementation, but wrap one.
""",
    __new__ = generic_new_descr(W_BufferedIOBase),
    read = interp2app(W_BufferedIOBase.read_w),
    read1 = interp2app(W_BufferedIOBase.read1_w),
    write = interp2app(W_BufferedIOBase.write_w),
    detach = interp2app(W_BufferedIOBase.detach_w),
    readinto = interp2app(W_BufferedIOBase.readinto_w),
    readinto1 = interp2app(W_BufferedIOBase.readinto1_w),
)

class BufferedMixin:
    def __init__(self, space):
        W_IOBase.__init__(self, space)
        self.state = STATE_ZERO

        self.buffer = None

        self.abs_pos = 0    # Absolute position inside the raw stream (-1 if
                            # unknown).
        self.pos = 0        # Current logical position in the buffer
        self.raw_pos = 0    # Position of the raw stream in the buffer.

        self.read_end = -1  # Just after the last buffered byte in the buffer,
                            # or -1 if the buffer isn't ready for reading

        self.write_pos = 0  # Just after the last byte actually written
        self.write_end = -1 # Just after the last byte waiting to be written,
                            # or -1 if the buffer isn't ready for writing.

        self.lock = None

        self.readable = False
        self.writable = False

        self._fast_closed_check = False

    def _reader_reset_buf(self):
        self.read_end = -1

    def _writer_reset_buf(self):
        self.write_pos = 0
        self.write_end = -1

    def _make_buffer(self, space, size):
        if space.config.translation.split_gc_address_space:
            # When using split GC address space, it is not possible to get the
            # raw address of a GC buffer. Therefore we use a buffer backed by
            # raw memory.
            return RawByteBuffer(size)
        else:
            # TODO: test whether using the raw buffer is faster
            return ByteBuffer(size)

    def _init(self, space):
        if self.buffer_size <= 0:
            raise oefmt(space.w_ValueError,
                        "buffer size must be strictly positive")

        self.buffer = self._make_buffer(space, self.buffer_size)

        self.lock = TryLock(space)

        try:
            self._raw_tell(space)
        except OperationError:
            pass

    def _check_init(self, space):
        if self.state == STATE_ZERO:
            raise oefmt(space.w_ValueError,
                        "I/O operation on uninitialized object")
        elif self.state == STATE_DETACHED:
            raise oefmt(space.w_ValueError, "raw stream has been detached")

    @try_inline
    def _check_closed(self, space, message=None):
        from pypy.module._io.interp_fileio import W_FileIO
        if self._fast_closed_check:
            w_raw = self.w_raw
            assert isinstance(w_raw, W_FileIO)
            if w_raw.fd >= 0:
                return
        self._check_init(space)
        W_IOBase._check_closed(self, space, message)

    def _raw_tell(self, space):
        from pypy.module._io.interp_fileio import W_FileIO
        if self._fast_closed_check:
            w_raw = self.w_raw
            assert isinstance(w_raw, W_FileIO)
            pos = r_longlong(w_raw._raw_tell(space))
        else:
            w_pos = space.call_method(self.w_raw, "tell")
            pos = space.r_longlong_w(w_pos)
        if pos < 0:
            raise oefmt(space.w_IOError,
                        "raw stream returned invalid position")

        self.abs_pos = pos
        return pos

    def closed_get_w(self, space):
        self._check_init(space)
        return space.getattr(self.w_raw, space.newtext("closed"))

    def name_get_w(self, space):
        self._check_init(space)
        return space.getattr(self.w_raw, space.newtext("name"))

    def mode_get_w(self, space):
        self._check_init(space)
        return space.getattr(self.w_raw, space.newtext("mode"))

    def readable_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "readable")

    def writable_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "writable")

    def seekable_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "seekable")

    def isatty_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "isatty")

    def repr_w(self, space):
        typename = space.type(self).name
        try:
            w_name = space.getattr(self, space.newtext("name"))
        except OperationError as e:
            if not e.match(space, space.w_Exception):
                raise
            return space.newtext("<%s>" % (typename,))
        else:
            name_repr = space.text_w(space.repr(w_name))
            return space.newtext("<%s name=%s>" % (typename, name_repr))

    # ______________________________________________

    @signature(types.any(), returns=types.int())
    def _readahead(self):
        if self.readable and self.read_end != -1:
            available = self.read_end - self.pos
            assert available >= 0
            return available
        return 0

    def _raw_offset(self):
        if self.raw_pos >= 0 and (
            (self.readable and self.read_end != -1) or
            (self.writable and self.write_end != -1)):
            return self.raw_pos - self.pos
        return 0

    def tell_w(self, space):
        self._check_init(space)
        pos = self._raw_tell(space) - self._raw_offset()
        return space.newint(pos)

    @unwrap_spec(pos=r_longlong, whence=int)
    def seek_w(self, space, pos, whence=0):
        self._check_closed(space, "seek of closed file")
        if whence not in (0, 1, 2):
            raise oefmt(space.w_ValueError,
                        "whence must be between 0 and 2, not %d", whence)
        check_seekable_w(space, self.w_raw)
        if whence != 2 and self.readable:
            # Check if seeking leaves us inside the current buffer, so as to
            # return quickly if possible. Also, we needn't take the lock in
            # this fast path.
            if self.abs_pos == -1:
                self._raw_tell(space)
            current = self.abs_pos
            available = self._readahead()
            if available > 0:
                if whence == 0:
                    offset = pos - (current - self._raw_offset())
                else:
                    offset = pos
                if -self.pos <= offset <= available:
                    newpos = self.pos + int(offset)
                    assert newpos >= 0
                    self.pos = newpos
                    return space.newint(current - available + offset)

        # Fallback: invoke raw seek() method and clear buffer
        with self.lock:
            if self.writable:
                self._writer_flush_unlocked(space)

            if whence == 1:
                pos -= self._raw_offset()
            n = self._raw_seek(space, pos, whence)
            self.raw_pos = -1
            if self.readable:
                self._reader_reset_buf()
            return space.newint(n)

    def _raw_seek(self, space, pos, whence):
        w_pos = space.call_method(self.w_raw, "seek",
                                  space.newint(pos), space.newint(whence))
        pos = space.r_longlong_w(w_pos)
        if pos < 0:
            raise oefmt(space.w_IOError,
                        "Raw stream returned invalid position")
        self.abs_pos = pos
        return pos

    def _closed(self, space):
        return space.is_true(space.getattr(self.w_raw, space.newtext("closed")))

    def close_w(self, space):
        self._check_init(space)
        with self.lock:
            if self._closed(space):
                return
        flush_operr = None
        try:
            space.call_method(self, "flush")
        except OperationError as e:
            flush_operr = e
            raise
        finally:
            with self.lock:
                try:
                    space.call_method(self.w_raw, "close")
                except OperationError as e:
                    if flush_operr:
                        e.chain_exceptions(space, flush_operr)
                    raise
        self.buffer = None # free buffer memory
        self.maybe_unregister_rpython_finalizer_io(space)

    def _dealloc_warn_w(self, space, w_source):
        space.call_method(self.w_raw, "_dealloc_warn", w_source)

    def simple_flush_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "flush")

    def _writer_flush_unlocked(self, space):
        if self.write_end == -1 or self.write_pos == self.write_end:
            self._writer_reset_buf()
            return
        # First, rewind
        rewind = self._raw_offset() + (self.pos - self.write_pos)
        if rewind != 0:
            self._raw_seek(space, -rewind, 1)
            self.raw_pos -= rewind

        written = 0
        while self.write_pos < self.write_end:
            try:
                n = self._raw_write(space, self.write_pos, self.write_end)
            except BlockingIOError:
                raise make_write_blocking_error(space, 0)
            self.write_pos += n
            self.raw_pos = self.write_pos
            written += n
            # Partial writes can return successfully when interrupted by a
            # signal (see write(2)).  We must run signal handlers before
            # blocking another time, possibly indefinitely.
            space.getexecutioncontext().checksignals()

        self._writer_reset_buf()

    def _write(self, space, data):
        w_data = space.newbytes(data)
        while True:
            try:
                w_written = space.call_method(self.w_raw, "write", w_data)
            except OperationError as e:
                if trap_eintr(space, e):
                    continue  # try again
                raise
            else:
                break

        if space.is_w(w_written, space.w_None):
            # Non-blocking stream would have blocked.
            raise BlockingIOError()

        written = space.getindex_w(w_written, space.w_IOError)
        if not 0 <= written <= len(data):
            raise oefmt(space.w_IOError, "raw write() returned invalid length")
        if self.abs_pos != -1:
            self.abs_pos += written
        return written

    def _raw_write(self, space, start, end):
        return self._write(space, self.buffer[start:end])

    def detach_w(self, space):
        self._check_init(space)
        space.call_method(self, "flush")
        w_raw = self.w_raw
        self.w_raw = None
        self.state = STATE_DETACHED
        self._fast_closed_check = False
        return w_raw

    def fileno_w(self, space):
        self._check_init(space)
        return space.call_method(self.w_raw, "fileno")

    @unwrap_spec(w_size = WrappedDefault(None))
    def truncate_w(self, space, w_size):
        self._check_init(space)
        self._check_closed(space, "truncate of closed file")
        with self.lock:
            if self.writable:
                self._flush_and_rewind_unlocked(space)
            # invalidate cached position
            self.abs_pos = -1

            return space.call_method(self.w_raw, "truncate", w_size)

    # ________________________________________________________________
    # Read methods

    def read_w(self, space, w_size=None):
        self._check_closed(space, "read of closed file")
        size = convert_size(space, w_size)

        if size == -1:
            # read until the end of stream
            with self.lock:
                return self._read_all(space)
        elif size >= 0:
            res = self._read_fast(size)
            if res is None:
                with self.lock:
                    res = self._read_generic(space, size)
        else:
            raise oefmt(space.w_ValueError,
                        "read length must be positive or -1")
        if res is None:
            return space.w_None
        return space.newbytes(res)

    @unwrap_spec(size=int)
    def peek_w(self, space, size=0):
        self._check_closed(space, "peek of closed file")
        with self.lock:
            if self.writable:
                self._flush_and_rewind_unlocked(space)
            # Constraints:
            # 1. we don't want to advance the file position.
            # 2. we don't want to lose block alignment, so we can't shift the
            #    buffer to make some place.
            # Therefore, we either return `have` bytes (if > 0), or a full
            # buffer.
            have = self._readahead()
            if have > 0:
                data = self.buffer[self.pos:self.pos+have]
                return space.newbytes(data)

            # Fill the buffer from the raw stream, and copy it to the result
            self._reader_reset_buf()
            try:
                size = self._fill_buffer(space)
            except BlockingIOError:
                size = 0
            self.pos = 0
            data = self.buffer[0:size]
            return space.newbytes(data)

    @unwrap_spec(size=int)
    def read1_w(self, space, size=-1):
        self._check_closed(space, "read of closed file")

        if size < 0:
            size = self.buffer_size
        if size == 0:
            return space.newbytes("")

        with self.lock:
            # Return up to n bytes.  If at least one byte is buffered, we only
            # return buffered bytes.  Otherwise, we do one raw read.

            # XXX: this mimicks the io.py implementation but is probably
            # wrong. If we need to read from the raw stream, then we could
            # actually read all `n` bytes asked by the caller (and possibly
            # more, so as to fill our buffer for the next reads).

            have = self._readahead()
            if have == 0:
                if self.writable:
                    self._flush_and_rewind_unlocked(space)

                # Fill the buffer from the raw stream
                self._reader_reset_buf()
                self.pos = 0
                try:
                    have = self._fill_buffer(space)
                except BlockingIOError:
                    have = 0
            if size > have:
                size = have
            endpos = self.pos + size
            data = self.buffer[self.pos:endpos]
            self.pos = endpos
            return space.newbytes(data)

    def _read_all(self, space):
        "Read all the file, don't update the cache"
        # Must run with the lock held!
        builder = StringBuilder()
        # First copy what we have in the current buffer
        current_size = self._readahead()
        data = None
        if current_size:
            data = self.buffer[self.pos:self.pos + current_size]
            builder.append(data)
            self.pos += current_size
        # We're going past the buffer's bounds, flush it
        if self.writable:
            self._flush_and_rewind_unlocked(space)
        self._reader_reset_buf()

        while True:
            # Read until EOF or until read() would block
            w_data = space.call_method(self.w_raw, "read")
            if space.is_w(w_data, space.w_None):
                if current_size == 0:
                    return w_data
                break
            data = space.bytes_w(w_data)
            size = len(data)
            if size == 0:
                break
            builder.append(data)
            current_size += size
            if self.abs_pos != -1:
                self.abs_pos += size
        return space.newbytes(builder.build())

    def _raw_read(self, space, buffer, start, length):
        from pypy.module._io.interp_fileio import W_FileIO
        assert buffer is not None

        length = intmask(length)
        start = intmask(start)
        w_raw = self.w_raw
        target_address = lltype.nullptr(rffi.CCHARP.TO)
        if type(w_raw) is W_FileIO:
            try:
                raw_address = buffer.get_raw_address()
            except ValueError:
                pass
            else:
                target_address = rffi.ptradd(raw_address, start)

        if target_address:
            assert type(w_raw) is W_FileIO
            w_size = w_raw._readinto_raw(space, target_address, length)
            keepalive_until_here(buffer)
        else:
            w_view = SimpleView(SubBuffer(buffer, start, length), w_obj=self).wrap(space)
            while True:
                try:
                    w_size = space.call_method(self.w_raw, "readinto", w_view)
                except OperationError as e:
                    if trap_eintr(space, e):
                        continue  # try again
                    raise
                else:
                    break

        if space.is_w(w_size, space.w_None):
            raise BlockingIOError()
        size = space.int_w(w_size)
        if size < 0 or size > length:
            raise oefmt(space.w_IOError,
                        "raw readinto() returned invalid length %d (should "
                        "have been between 0 and %d)", size, length)
        if self.abs_pos != -1:
            self.abs_pos += size
        return size

    def _fill_buffer(self, space):
        start = self.read_end
        if start == -1:
            start = 0
        length = self.buffer_size - start
        size = self._raw_read(space, self.buffer, start, length)
        if size > 0:
            self.read_end = self.raw_pos = start + size
        return size

    def _read_generic(self, space, n):
        """Generic read function: read from the stream until enough bytes are
           read, or until an EOF occurs or until read() would block."""
        # Must run with the lock held!
        current_size = self._readahead()
        if n <= current_size:
            return self._read_fast(n)

        result_buffer = self._make_buffer(space, n)
        remaining = n
        written = 0
        if current_size:
            self.output_slice(space, result_buffer,
                written, self.buffer[self.pos:self.pos + current_size])
            remaining -= current_size
            written += current_size
            self.pos += current_size

        # Flush the write buffer if necessary
        if self.writable:
            self._flush_and_rewind_unlocked(space)
        self._reader_reset_buf()

        # Read whole blocks, and don't buffer them
        while remaining > 0:
            r = self.buffer_size * (remaining // self.buffer_size)
            if r == 0:
                break
            try:
                size = self._raw_read(space, result_buffer, written, r)
            except BlockingIOError:
                if written == 0:
                    return None
                size = 0
            if size == 0:
                return result_buffer[0:written]
            remaining -= size
            written += size

        self.pos = 0
        self.raw_pos = 0
        self.read_end = 0

        while remaining > 0 and self.read_end < self.buffer_size:
            try:
                size = self._fill_buffer(space)
            except BlockingIOError:
                # EOF or read() would block
                if written == 0:
                    return None
                size = 0
            if size == 0:
                break

            if remaining > 0:
                if size > remaining:
                    size = remaining
                self.output_slice(space, result_buffer,
                    written, self.buffer[self.pos:self.pos + size])
                self.pos += size
                written += size
                remaining -= size

        return result_buffer[0:written]

    def _read_fast(self, n):
        """Read n bytes from the buffer if it can, otherwise return None.
           This function is simple enough that it can run unlocked."""
        current_size = self._readahead()
        if n <= current_size:
            endpos = self.pos + n
            res = self.buffer[self.pos:endpos]
            self.pos = endpos
            return res
        return None

    def readline_w(self, space, w_limit=None):
        self._check_closed(space, "readline of closed file")

        limit = convert_size(space, w_limit)

        # First, try to find a line in the buffer. This can run
        # unlocked because the calls to the C API are simple enough
        # that they can't trigger any thread switch.
        have = self._readahead()
        if limit >= 0 and have > limit:
            have = limit
        buffer = self.buffer
        if isinstance(buffer, ByteBuffer):
            # hack at the internals of self.buffer, otherwise this loop is
            # extremely slow
            for pos in range(self.pos, self.pos+have):
                if buffer.data[pos] == '\n':
                    break
            else:
                pos = -1
        else:
            for pos in range(self.pos, self.pos+have):
                if buffer[pos] == '\n':
                    break
            else:
                pos = -1
        if pos >= 0:
            w_res = space.newbytes(self.buffer[self.pos:pos+1])
            self.pos = pos + 1
            return w_res
        if have == limit:
            w_res = space.newbytes(self.buffer[self.pos:self.pos+have])
            self.pos += have
            return w_res

        written = 0
        with self.lock:
            # Now we try to get some more from the raw stream
            chunks = []
            if have > 0:
                chunks.append(self.buffer[self.pos:self.pos+have])
                written += have
                self.pos += have
                if limit >= 0:
                    limit -= have
            if self.writable:
                self._flush_and_rewind_unlocked(space)

            while True:
                self._reader_reset_buf()
                try:
                    have = self._fill_buffer(space)
                except BlockingIOError:
                    have = 0
                if have == 0:
                    break
                if limit >= 0 and have > limit:
                    have = limit
                pos = 0
                found = False
                while pos < have:
                    c = self.buffer.getitem(pos)
                    pos += 1
                    if c == '\n':
                        self.pos = pos
                        found = True
                        break
                chunks.append(self.buffer[0:pos])
                if found:
                    break
                if have == limit:
                    self.pos = have
                    break
                written += have
                if limit >= 0:
                    limit -= have
            return space.newbytes(''.join(chunks))

    # ____________________________________________________
    # Write methods

    def _adjust_position(self, new_pos):
        assert new_pos >= 0
        self.pos = new_pos
        if self.readable and self.read_end != -1 and self.read_end < new_pos:
            self.read_end = self.pos

    def write_w(self, space, w_data):
        self._check_init(space)
        data = space.charbuf_w(w_data)
        size = len(data)

        with self.lock:
            self._check_closed(space, "write to closed file")
            if (not (self.readable and self.read_end != -1) and
                not (self.writable and self.write_end != -1)):
                self.pos = 0
                self.raw_pos = 0
            available = self.buffer_size - self.pos
            # Fast path: the data to write can be fully buffered
            if size <= available:
                for i in range(size):
                    self.buffer[self.pos + i] = data[i]
                if self.write_end == -1 or self.write_pos > self.pos:
                    self.write_pos = self.pos
                self._adjust_position(self.pos + size)
                if self.pos > self.write_end:
                    self.write_end = self.pos
                return space.newint(size)

            # First write the current buffer
            try:
                self._writer_flush_unlocked(space)
            except OperationError as e:
                if not e.match(space, space.w_BlockingIOError):
                    raise
                if self.readable:
                    self._reader_reset_buf()
                # Make some place by shifting the buffer
                for i in range(self.write_pos, self.write_end):
                    self.buffer.setitem(i - self.write_pos, self.buffer.getitem(i))
                self.write_end -= self.write_pos
                self.raw_pos -= self.write_pos
                newpos = self.pos - self.write_pos
                assert newpos >= 0
                self.pos = newpos
                self.write_pos = 0
                available = self.buffer_size - self.write_end
                assert available >= 0
                if size <= available:
                    # Everything can be buffered
                    for i in range(size):
                        self.buffer[self.write_end + i] = data[i]
                    self.write_end += size
                    self.pos += size
                    return space.newint(size)
                # Buffer as much as possible
                for i in range(available):
                    self.buffer[self.write_end + i] = data[i]
                self.write_end += available
                self.pos += available
                # Modifying the existing exception will will change
                # e.characters_written but not e.args[2].  Therefore
                # we just replace with a new error.
                raise make_write_blocking_error(space, available)

            # Adjust the raw stream position if it is away from the logical
            # stream position. This happens if the read buffer has been filled
            # but not modified (and therefore _bufferedwriter_flush_unlocked()
            # didn't rewind the raw stream by itself).
            offset = self._raw_offset()
            if offset:
                self._raw_seek(space, -offset, 1)
                self.raw_pos -= offset

            # Then write buf itself. At this point the buffer has been emptied
            remaining = size
            written = 0
            while remaining > self.buffer_size:
                try:
                    n = self._write(space, data[written:])
                except BlockingIOError:
                    # Write failed because raw file is non-blocking
                    if remaining > self.buffer_size:
                        # Can't buffer everything, still buffer as much as
                        # possible
                        for i in range(self.buffer_size):
                            self.buffer[i] = data[written + i]
                        self.raw_pos = 0
                        self._adjust_position(self.buffer_size)
                        self.write_end = self.buffer_size
                        written += self.buffer_size
                        raise make_write_blocking_error(space, written)
                    break
                written += n
                remaining -= n
                # Partial writes can return successfully when interrupted by a
                # signal (see write(2)).  We must run signal handlers before
                # blocking another time, possibly indefinitely.
                space.getexecutioncontext().checksignals()

            if self.readable:
                self._reader_reset_buf()
            if remaining > 0:
                for i in range(remaining):
                    self.buffer[i] = data[written + i]
                written += remaining
            self.write_pos = 0
            self.write_end = remaining
            self._adjust_position(remaining)
            self.raw_pos = 0
        return space.newint(written)

    def flush_w(self, space):
        self._check_closed(space, "flush of closed file")
        with self.lock:
            self._flush_and_rewind_unlocked(space)

    def _flush_and_rewind_unlocked(self, space):
        self._writer_flush_unlocked(space)
        if self.readable:
            # Rewind the raw stream so that its position corresponds to
            # the current logical position.
            try:
                self._raw_seek(space, -self._raw_offset(), 1)
            finally:
                self._reader_reset_buf()

class BufferedReaderMixin(object):
    import_from_mixin(BufferedMixin)

    def readinto_w(self, space, w_buffer):
        return self._readinto(space, w_buffer, read_once=False)

    def readinto1_w(self, space, w_buffer):
        return self._readinto(space, w_buffer, read_once=True)

    def _readinto(self, space, w_buffer, read_once):
        self._check_init(space)
        self._check_closed(space, "readinto of closed file")
        rwbuffer = space.writebuf_w(w_buffer)
        length = rwbuffer.getlength()
        with self.lock:
            have = self._readahead()
            if have >= length:
                self.output_slice(space, rwbuffer,
                    0, self.buffer[self.pos:self.pos + length])
                self.pos += length
                return space.newint(length)
            written = 0
            if have > 0:
                self.output_slice(space, rwbuffer,
                    0, self.buffer[self.pos:self.read_end])
                written = have

            while written < length:
                if self.writable:
                    self._flush_and_rewind_unlocked(space)
                self._reader_reset_buf()
                self.pos = 0
                if written + len(self.buffer) < length:
                    try:
                        got = self._raw_read(
                            space, rwbuffer, written, length - written)
                        written += got
                    except BlockingIOError:
                        got = 0
                    if got == 0:
                        break
                elif read_once and written:
                    break
                else:
                    try:
                        have = self._fill_buffer(space)
                    except BlockingIOError:
                        have = 0
                    if have == 0:
                        break
                    endpos = min(have, length - written)
                    assert endpos >= 0
                    self.output_slice(space, rwbuffer,
                        written, self.buffer[0:endpos])
                    written += endpos
                    self.pos = endpos
                if read_once:
                    break
            return space.newint(written)


class W_BufferedReader(W_BufferedIOBase):
    import_from_mixin(BufferedReaderMixin)

    @unwrap_spec(buffer_size=int)
    def descr_init(self, space, w_raw, buffer_size=DEFAULT_BUFFER_SIZE):
        from pypy.module._io.interp_fileio import W_FileIO
        self.state = STATE_ZERO
        check_readable_w(space, w_raw)

        self.w_raw = w_raw
        self.buffer_size = buffer_size
        self.readable = True

        self._init(space)
        self._reader_reset_buf()
        self.state = STATE_OK
        self._fast_closed_check = (type(self) is W_BufferedReader and
                type(w_raw) is W_FileIO)


W_BufferedReader.typedef = TypeDef(
    '_io.BufferedReader', W_BufferedIOBase.typedef,
    __new__ = generic_new_descr(W_BufferedReader),
    __init__  = interp2app(W_BufferedReader.descr_init),
    __getstate__ = interp2app(W_BufferedReader.getstate_w),

    read = interp2app(W_BufferedReader.read_w),
    peek = interp2app(W_BufferedReader.peek_w),
    read1 = interp2app(W_BufferedReader.read1_w),
    readinto = interp2app(W_BufferedReader.readinto_w),
    readinto1 = interp2app(W_BufferedReader.readinto1_w),
    raw = interp_attrproperty_w("w_raw", cls=W_BufferedReader),
    readline = interp2app(W_BufferedReader.readline_w),

    # from the mixin class
    __repr__ = interp2app(W_BufferedReader.repr_w),
    readable = interp2app(W_BufferedReader.readable_w),
    seekable = interp2app(W_BufferedReader.seekable_w),
    seek = interp2app(W_BufferedReader.seek_w),
    tell = interp2app(W_BufferedReader.tell_w),
    close = interp2app(W_BufferedReader.close_w),
    flush = interp2app(W_BufferedReader.simple_flush_w), # Not flush_w!
    detach = interp2app(W_BufferedReader.detach_w),
    truncate = interp2app(W_BufferedReader.truncate_w),
    fileno = interp2app(W_BufferedReader.fileno_w),
    isatty = interp2app(W_BufferedReader.isatty_w),
    _dealloc_warn = interp2app(W_BufferedReader._dealloc_warn_w),
    closed = GetSetProperty(W_BufferedReader.closed_get_w),
    name = GetSetProperty(W_BufferedReader.name_get_w),
    mode = GetSetProperty(W_BufferedReader.mode_get_w),
)

class W_BufferedWriter(W_BufferedIOBase):
    import_from_mixin(BufferedMixin)

    @unwrap_spec(buffer_size=int)
    def descr_init(self, space, w_raw, buffer_size=DEFAULT_BUFFER_SIZE):
        from pypy.module._io.interp_fileio import W_FileIO
        self.state = STATE_ZERO
        check_writable_w(space, w_raw)

        self.w_raw = w_raw
        self.buffer_size = buffer_size
        self.writable = True

        self._init(space)
        self._writer_reset_buf()
        self.state = STATE_OK
        self._fast_closed_check = (type(self) is W_BufferedWriter and
                type(w_raw) is W_FileIO)

W_BufferedWriter.typedef = TypeDef(
    '_io.BufferedWriter', W_BufferedIOBase.typedef,
    __new__ = generic_new_descr(W_BufferedWriter),
    __init__  = interp2app(W_BufferedWriter.descr_init),
    __getstate__ = interp2app(W_BufferedWriter.getstate_w),

    write = interp2app(W_BufferedWriter.write_w),
    flush = interp2app(W_BufferedWriter.flush_w),
    raw = interp_attrproperty_w("w_raw", cls=W_BufferedWriter),

    # from the mixin class
    __repr__ = interp2app(W_BufferedWriter.repr_w),
    writable = interp2app(W_BufferedWriter.writable_w),
    seekable = interp2app(W_BufferedWriter.seekable_w),
    seek = interp2app(W_BufferedWriter.seek_w),
    tell = interp2app(W_BufferedWriter.tell_w),
    close = interp2app(W_BufferedWriter.close_w),
    fileno = interp2app(W_BufferedWriter.fileno_w),
    isatty = interp2app(W_BufferedWriter.isatty_w),
    detach = interp2app(W_BufferedWriter.detach_w),
    truncate = interp2app(W_BufferedWriter.truncate_w),
    _dealloc_warn = interp2app(W_BufferedWriter._dealloc_warn_w),
    closed = GetSetProperty(W_BufferedWriter.closed_get_w),
    name = GetSetProperty(W_BufferedWriter.name_get_w),
    mode = GetSetProperty(W_BufferedWriter.mode_get_w),
)

def make_forwarding_method(method, writer=False, reader=False):
    @func_renamer(method + '_w')
    def method_w(self, space, __args__):
        if writer:
            if self.w_writer is None:
                raise oefmt(space.w_ValueError,
                            "I/O operation on uninitialized object")
            w_meth = space.getattr(self.w_writer, space.newtext(method))
            w_result = space.call_args(w_meth, __args__)
        if reader:
            if self.w_reader is None:
                raise oefmt(space.w_ValueError,
                            "I/O operation on uninitialized object")
            w_meth = space.getattr(self.w_reader, space.newtext(method))
            w_result = space.call_args(w_meth, __args__)
        return w_result
    return method_w

class W_BufferedRWPair(W_BufferedIOBase):
    w_reader = None
    w_writer = None

    @unwrap_spec(buffer_size=int)
    def descr_init(self, space, w_reader, w_writer,
                   buffer_size=DEFAULT_BUFFER_SIZE):
        try:
            self.w_reader = W_BufferedReader(space)
            self.w_reader.descr_init(space, w_reader, buffer_size)
            self.w_writer = W_BufferedWriter(space)
            self.w_writer.descr_init(space, w_writer, buffer_size)
        except Exception:
            self.w_reader = None
            self.w_writer = None
            raise

    # forward to reader
    for method in ['read', 'peek', 'read1', 'readinto', 'readable']:
        locals()[method + '_w'] = make_forwarding_method(
            method, reader=True)

    # forward to writer
    for method in ['write', 'flush', 'writable']:
        locals()[method + '_w'] = make_forwarding_method(
            method, writer=True)

    # forward to both
    def close_w(self, space, __args__):
        if self.w_writer is None:
            raise oefmt(space.w_ValueError,
                        "I/O operation on uninitialized object")
        w_meth = space.getattr(self.w_writer, space.newtext("close"))
        try:
            space.call_args(w_meth, __args__)
        except OperationError as e:
            pass
        else:
            e = None

        if self.w_reader is None:
            raise oefmt(space.w_ValueError,
                        "I/O operation on uninitialized object")
        w_meth = space.getattr(self.w_reader, space.newtext("close"))
        try:
            space.call_args(w_meth, __args__)
        except OperationError as e2:
            if e:
                e2.chain_exceptions(space, e)
            e = e2

        if e:
            raise e

    def needs_finalizer(self):
        # self.w_writer and self.w_reader have their own finalizer
        return type(self) is not W_BufferedRWPair

    def isatty_w(self, space):
        if space.is_true(space.call_method(self.w_writer, "isatty")):
            return space.w_True
        return space.call_method(self.w_reader, "isatty")

    def closed_get_w(self, space):
        return space.getattr(self.w_writer, space.newtext("closed"))

methods = dict((method, interp2app(getattr(W_BufferedRWPair, method + '_w')))
               for method in ['read', 'peek', 'read1', 'readinto', 'readable',
                              'write', 'flush', 'writable',
                              'close',
                              'isatty'])

W_BufferedRWPair.typedef = TypeDef(
    '_io.BufferedRWPair', W_BufferedIOBase.typedef,
    __new__ = generic_new_descr(W_BufferedRWPair),
    __init__  = interp2app(W_BufferedRWPair.descr_init),
    __getstate__ = interp2app(W_BufferedRWPair.getstate_w),
    closed = GetSetProperty(W_BufferedRWPair.closed_get_w),
    **methods
)

class W_BufferedRandom(W_BufferedIOBase):
    import_from_mixin(BufferedReaderMixin)

    @unwrap_spec(buffer_size=int)
    def descr_init(self, space, w_raw, buffer_size=DEFAULT_BUFFER_SIZE):
        from pypy.module._io.interp_fileio import W_FileIO
        self.state = STATE_ZERO
        check_readable_w(space, w_raw)
        check_writable_w(space, w_raw)
        check_seekable_w(space, w_raw)

        self.w_raw = w_raw
        self.buffer_size = buffer_size
        self.readable = self.writable = True

        self._init(space)
        self._reader_reset_buf()
        self._writer_reset_buf()
        self.pos = 0
        self.state = STATE_OK
        self._fast_closed_check = (type(self) is W_BufferedWriter and
                type(w_raw) is W_FileIO)

W_BufferedRandom.typedef = TypeDef(
    '_io.BufferedRandom', W_BufferedIOBase.typedef,
    __new__ = generic_new_descr(W_BufferedRandom),
    __init__ = interp2app(W_BufferedRandom.descr_init),
    __getstate__ = interp2app(W_BufferedRandom.getstate_w),

    read = interp2app(W_BufferedRandom.read_w),
    peek = interp2app(W_BufferedRandom.peek_w),
    read1 = interp2app(W_BufferedRandom.read1_w),
    readline = interp2app(W_BufferedRandom.readline_w),
    readinto = interp2app(W_BufferedRandom.readinto_w),
    readinto1 = interp2app(W_BufferedRandom.readinto1_w),

    write = interp2app(W_BufferedRandom.write_w),
    flush = interp2app(W_BufferedRandom.flush_w),
    raw = interp_attrproperty_w("w_raw", cls=W_BufferedRandom),

    # from the mixin class
    __repr__ = interp2app(W_BufferedRandom.repr_w),
    readable = interp2app(W_BufferedRandom.readable_w),
    writable = interp2app(W_BufferedRandom.writable_w),
    seekable = interp2app(W_BufferedRandom.seekable_w),
    seek = interp2app(W_BufferedRandom.seek_w),
    tell = interp2app(W_BufferedRandom.tell_w),
    close = interp2app(W_BufferedRandom.close_w),
    detach = interp2app(W_BufferedRandom.detach_w),
    truncate = interp2app(W_BufferedRandom.truncate_w),
    fileno = interp2app(W_BufferedRandom.fileno_w),
    isatty = interp2app(W_BufferedRandom.isatty_w),
    _dealloc_warn = interp2app(W_BufferedRandom._dealloc_warn_w),
    closed = GetSetProperty(W_BufferedRandom.closed_get_w),
    name = GetSetProperty(W_BufferedRandom.name_get_w),
    mode = GetSetProperty(W_BufferedRandom.mode_get_w),
)
