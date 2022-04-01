"""New standard I/O library.

Based on sio.py from Guido van Rossum.

- This module contains various stream classes which provide a subset of the
  classic Python I/O API: read(n), write(s), tell(), seek(offset, whence=0),
  readall(), readline(), truncate(size), flush(), close(), peek(),
  flushable(), try_to_find_file_descriptor().

- This is not for general usage:
  * read(n) may return less than n bytes, just like os.read().
  * some other methods also have no default parameters.
  * close() should be called exactly once and no further operations performed;
    there is no __del__() closing the stream for you.
  * some methods may raise MyNotImplementedError.
  * peek() returns some (or no) characters that have already been read ahead.
  * flushable() returns True/False if flushing that stream is useful/pointless.

- A 'basis stream' provides I/O using a low-level API, like the os, mmap or
  socket modules.

- A 'filtering stream' builds on top of another stream.  There are filtering
  streams for universal newline translation, for unicode translation, and
  for buffering.

You typically take a basis stream, place zero or more filtering
streams on top of it, and then top it off with an input-buffering and/or
an outout-buffering stream.
"""

# File offsets are all 'r_longlong', but a single read or write cannot
# transfer more data that fits in an RPython 'int' (because that would not
# fit in a single string anyway).  This module needs to be careful about
# where r_longlong values end up: as argument to seek() and truncate() and
# return value of tell(), but not as argument to read().

import os, sys, errno
from rpython.rlib.objectmodel import specialize, we_are_translated, not_rpython
from rpython.rlib.rarithmetic import r_longlong, intmask
from rpython.rlib import rposix, nonconst, _rsocket_rffi as _c
from rpython.rlib.rstring import StringBuilder

from os import O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, O_TRUNC, O_APPEND
O_BINARY = getattr(os, "O_BINARY", 0)

#          (basemode, plus)
OS_MODE = {('r', False): O_RDONLY,
           ('r', True):  O_RDWR,
           ('w', False): O_WRONLY | O_CREAT | O_TRUNC,
           ('w', True):  O_RDWR   | O_CREAT | O_TRUNC,
           ('a', False): O_WRONLY | O_CREAT | O_APPEND,
           ('a', True):  O_RDWR   | O_CREAT | O_APPEND,
           }

class MyNotImplementedError(Exception):
    """Catching NotImplementedError is not RPython, so we use this custom class
    instead of it
    """

# ____________________________________________________________

def replace_crlf_with_lf(s):
    substrings = s.split("\r")
    result = [substrings[0]]
    for substring in substrings[1:]:
        if not substring:
            result.append("")
        elif substring[0] == "\n":
            result.append(substring[1:])
        else:
            result.append(substring)
    return "\n".join(result)

def replace_char_with_str(string, c, s):
    return s.join(string.split(c))


@specialize.argtype(0)
def open_file_as_stream(path, mode="r", buffering=-1, signal_checker=None):
    os_flags, universal, reading, writing, basemode, binary = decode_mode(mode)
    stream = open_path_helper(path, os_flags, basemode == "a", signal_checker)
    return construct_stream_tower(stream, buffering, universal, reading,
                                  writing, binary)

def _setfd_binary(fd):
    pass

if hasattr(_c, 'fcntl'):
    def _check_fd_mode(fd, reading, writing):
        flags = intmask(_c.fcntl(fd, _c.F_GETFL, 0))
        if flags & _c.O_RDWR:
            return
        elif flags & _c.O_WRONLY:
            if not reading:
                return
        else:  # O_RDONLY
            if not writing:
                return
        raise OSError(22, "Invalid argument")
else:
    def _check_fd_mode(fd, reading, writing):
        # XXX
        pass

def fdopen_as_stream(fd, mode, buffering=-1, signal_checker=None):
    os_flags, universal, reading, writing, basemode, binary = decode_mode(mode)
    _check_fd_mode(fd, reading, writing)
    _setfd_binary(fd)
    stream = DiskFile(fd, signal_checker)
    return construct_stream_tower(stream, buffering, universal, reading,
                                  writing, binary)

@specialize.argtype(0)
def open_path_helper(path, os_flags, append, signal_checker=None):
    # XXX for now always return DiskFile
    fd = rposix.open(path, os_flags, 0666)
    if append:
        try:
            os.lseek(fd, 0, 2)
        except OSError:
            # XXX does this pass make sense?
            pass
    return DiskFile(fd, signal_checker)

def decode_mode(mode):
    if mode[0] == 'U':
        mode = 'r' + mode

    basemode  = mode[0]    # 'r', 'w' or 'a'
    plus      = False
    universal = False
    binary    = False

    for c in mode[1:]:
        if c == '+':
            plus = True
        elif c == 'U':
            universal = True
        elif c == 'b':
            binary = True
        else:
            break

    flag = OS_MODE[basemode, plus]
    flag |= O_BINARY

    reading = basemode == 'r' or plus
    writing = basemode != 'r' or plus

    return flag, universal, reading, writing, basemode, binary


def construct_stream_tower(stream, buffering, universal, reading, writing,
                           binary):
    if buffering == 0:   # no buffering
        pass
    elif buffering == 1:   # line-buffering
        if writing:
            stream = LineBufferingOutputStream(stream)
        if reading:
            stream = BufferingInputStream(stream)

    else:     # default or explicit buffer sizes
        if buffering is not None and buffering < 0:
            buffering = -1
        if writing:
            stream = BufferingOutputStream(stream, buffering)
        if reading:
            stream = BufferingInputStream(stream, buffering)

    if universal:     # Wants universal newlines
        if writing and os.linesep != '\n':
            stream = TextOutputFilter(stream)
        if reading:
            stream = TextInputFilter(stream)
    elif not binary and os.linesep == '\r\n':
        stream = TextCRLFFilter(stream)
    if nonconst.NonConstant(False):
        stream.flush_buffers()     # annotation workaround for untranslated tests
    return stream


class StreamError(Exception):
    def __init__(self, message):
        self.message = message

StreamErrors = (OSError, StreamError)     # errors that can generally be raised


if sys.platform == "win32":
    from rpython.rlib.rwin32 import BOOL, HANDLE, get_osfhandle
    from rpython.rlib.rwin32 import GetLastError_saved
    from rpython.translator.tool.cbuild import ExternalCompilationInfo
    from rpython.rtyper.lltypesystem import rffi

    _eci = ExternalCompilationInfo()
    _setmode = rffi.llexternal('_setmode', [rffi.INT, rffi.INT], rffi.INT,
                               compilation_info=_eci)
    SetEndOfFile = rffi.llexternal('SetEndOfFile', [HANDLE], BOOL,
                                   compilation_info=_eci,
                                   save_err=rffi.RFFI_SAVE_LASTERROR)

    def _setfd_binary(fd):
        # Allow this to succeed on invalid fd's
        with rposix.SuppressIPH():
            _setmode(fd, os.O_BINARY)

    def ftruncate_win32(fd, size):
        curpos = os.lseek(fd, 0, 1)
        try:
            # move to the position to be truncated
            os.lseek(fd, size, 0)
            # Truncate.  Note that this may grow the file!
            handle = get_osfhandle(fd)
            if not SetEndOfFile(handle):
                raise OSError(GetLastError_saved(),
                                   "Could not truncate file")
        finally:
            # we restore the file pointer position in any case
            os.lseek(fd, curpos, 0)


class Stream(object):
    """Base class for streams.  Provides a default implementation of
    some methods."""

    def read(self, n):
        raise MyNotImplementedError

    def write(self, data):
        raise MyNotImplementedError

    def tell(self):
        raise MyNotImplementedError

    def seek(self, offset, whence):
        raise MyNotImplementedError

    def readall(self):
        bufsize = 8192
        result = []
        while True:
            try:
                data = self.read(bufsize)
            except OSError:
                # like CPython < 3.4, partial results followed by an error
                # are returned as data
                if not result:
                    raise
                break
            if not data:
                break
            result.append(data)
            if bufsize < 4194304:    # 4 Megs
                bufsize <<= 1
        return ''.join(result)

    def readline(self):
        # very inefficient unless there is a peek()
        result = []
        while True:
            # "peeks" on the underlying stream to see how many characters
            # we can safely read without reading past an end-of-line
            startindex, peeked = self.peek()
            assert 0 <= startindex <= len(peeked)
            pn = peeked.find("\n", startindex)
            if pn < 0:
                pn = len(peeked)
            c = self.read(pn - startindex + 1)
            if not c:
                break
            result.append(c)
            if c.endswith('\n'):
                break
        return ''.join(result)

    def truncate(self, size):
        raise MyNotImplementedError

    def flush_buffers(self):
        pass

    def flush(self):
        pass

    def flushable(self):
        return False

    def close(self):
        self.close1(True)

    def close1(self, closefileno):
        pass

    def peek(self):
        return (0, '')

    def count_buffered_bytes(self):
        pos, buf = self.peek()
        return len(buf) - pos

    def try_to_find_file_descriptor(self):
        return -1

    def getnewlines(self):
        return 0


class DiskFile(Stream):
    """Standard I/O basis stream using os.open/close/read/write/lseek"""

    def __init__(self, fd, signal_checker=None):
        self.fd = fd
        self.signal_checker = signal_checker

    def seek(self, offset, whence):
        os.lseek(self.fd, offset, whence)

    def tell(self):
        result = os.lseek(self.fd, 0, 1)
        return r_longlong(result)

    def read(self, n):
        assert isinstance(n, int)
        while True:
            try:
                return os.read(self.fd, n)
            except OSError as e:
                if e.errno != errno.EINTR:
                    raise
                if self.signal_checker is not None:
                    self.signal_checker()
                # else try again

    def readline(self):
        # mostly inefficient, but not as laughably bad as with the default
        # readline() from Stream
        result = StringBuilder()
        while True:
            try:
                c = os.read(self.fd, 1)
            except OSError as e:
                if e.errno != errno.EINTR:
                    raise
                if self.signal_checker is not None:
                    self.signal_checker()
                continue   # try again
            if not c:
                break
            c = c[0]
            result.append(c)
            if c == '\n':
                break
        return result.build()

    def write(self, data):
        while data:
            try:
                n = os.write(self.fd, data)
            except OSError as e:
                if e.errno != errno.EINTR:
                    raise
                if self.signal_checker is not None:
                    self.signal_checker()
            else:
                data = data[n:]

    def close1(self, closefileno):
        if closefileno:
            os.close(self.fd)

    if sys.platform == "win32":
        def truncate(self, size):
            ftruncate_win32(self.fd, size)
    else:
        def truncate(self, size):
            # Note: for consistency, in translated programs a failing
            # os.ftruncate() raises OSError.  However, on top of
            # CPython, we get an IOError.  As it is (as far as I know)
            # the only place that have this behavior, we just convert it
            # to an OSError instead of adding IOError to StreamErrors.
            if we_are_translated():
                os.ftruncate(self.fd, size)
            else:
                try:
                    os.ftruncate(self.fd, size)
                except IOError as e:
                    raise OSError(*e.args)

    def try_to_find_file_descriptor(self):
        return self.fd

# next class is not RPython

class MMapFile(Stream):
    """Standard I/O basis stream using mmap."""

    @not_rpython
    def __init__(self, fd, mmapaccess):
        self.fd = fd
        self.access = mmapaccess
        self.pos = 0
        self.remapfile()

    def remapfile(self):
        import mmap
        size = os.fstat(self.fd).st_size
        self.mm = mmap.mmap(self.fd, size, access=self.access)

    def close1(self, closefileno):
        self.mm.close()
        if closefileno:
            os.close(self.fd)

    def tell(self):
        return self.pos

    def seek(self, offset, whence):
        if whence == 0:
            self.pos = max(0, offset)
        elif whence == 1:
            self.pos = max(0, self.pos + offset)
        elif whence == 2:
            self.pos = max(0, self.mm.size() + offset)
        else:
            raise StreamError("seek(): whence must be 0, 1 or 2")

    def readall(self):
        filesize = self.mm.size() # Actual file size, may be more than mapped
        n = filesize - self.pos
        data = self.mm[self.pos:]
        if len(data) < n:
            del data
            # File grew since opened; remap to get the new data
            self.remapfile()
            data = self.mm[self.pos:]
        self.pos += len(data)
        return data

    def read(self, n):
        assert isinstance(n, int)
        end = self.pos + n
        data = self.mm[self.pos:end]
        if not data:
            # is there more data to read?
            filesize = self.mm.size() #Actual file size, may be more than mapped
            if filesize > self.pos:
                # File grew since opened; remap to get the new data
                self.remapfile()
                data = self.mm[self.pos:end]
        self.pos += len(data)
        return data

    def readline(self):
        hit = self.mm.find("\n", self.pos) + 1
        if not hit:
            # is there more data to read?
            filesize = self.mm.size() #Actual file size, may be more than mapped
            if filesize > len(self.mm):
                # File grew since opened; remap to get the new data
                self.remapfile()
                hit = self.mm.find("\n", self.pos) + 1
        if hit:
            # Got a whole line
            data = self.mm[self.pos:hit]
            self.pos = hit
        else:
            # Read whatever we've got -- may be empty
            data = self.mm[self.pos:]
            self.pos += len(data)
        return data

    def write(self, data):
        end = self.pos + len(data)
        try:
            self.mm[self.pos:end] = data
            # This can raise IndexError on Windows, ValueError on Unix
        except (IndexError, ValueError):
            # XXX On Unix, this resize() call doesn't work
            self.mm.resize(end)
            self.mm[self.pos:end] = data
        self.pos = end

    def flush(self):
        self.mm.flush()

    def flushable(self):
        import mmap
        return self.access == mmap.ACCESS_WRITE

    def try_to_find_file_descriptor(self):
        return self.fd

# ____________________________________________________________

STREAM_METHODS = dict([
    ("read", [int]),
    ("write", [str]),
    ("tell", []),
    ("seek", [r_longlong, int]),
    ("readall", []),
    ("readline", []),
    ("truncate", [r_longlong]),
    ("flush", []),
    ("flushable", []),
    ("close1", [int]),
    ("peek", []),
    ("try_to_find_file_descriptor", []),
    ("getnewlines", []),
    ])

def PassThrough(meth_name, flush_buffers):
    if meth_name in STREAM_METHODS:
        signature = STREAM_METHODS[meth_name]
        args = ", ".join(["v%s" % (i, ) for i in range(len(signature))])
    else:
        assert 0, "not a good idea"
        args = "*args"
    if flush_buffers:
        code = """def %s(self, %s):
                      self.flush_buffers()
                      return self.base.%s(%s)
"""
    else:
        code = """def %s(self, %s):
                      return self.base.%s(%s)
"""
    d = {}
    exec(code % (meth_name, args, meth_name, args), d)
    return d[meth_name]


def offset2int(offset):
    intoffset = intmask(offset)
    if intoffset != offset:
        raise StreamError("seek() from a non-seekable source:"
                          " this would read and discard more"
                          " than sys.maxint bytes")
    return intoffset

class BufferingInputStream(Stream):
    """Standard buffering input stream.

    This, and BufferingOutputStream if needed, are typically at the top of
    the stack of streams.
    """

    bigsize = 2**19 # Half a Meg
    bufsize = 2**13 # 8 K

    def __init__(self, base, bufsize=-1):
        self.base = base
        self.do_read = base.read   # function to fill buffer some more
        self.do_tell = base.tell   # return a byte offset
        self.do_seek = base.seek   # seek to a byte offset
        if bufsize == -1:     # Get default from the class
            bufsize = self.bufsize
        self.bufsize = bufsize  # buffer size (hint only)
        self.buf = ""           # raw data
        self.pos = 0

    def flush_buffers(self):
        if self.buf:
            try:
                self.do_seek(self.pos - len(self.buf), 1)
            except (MyNotImplementedError, OSError):
                pass
            else:
                self.buf = ""
                self.pos = 0

    def tell(self):
        tellpos = self.do_tell()  # This may fail
        # Best-effort: to avoid extra system calls to tell() all the
        # time, and a more complicated logic in this class, we can
        # only assume that nobody changed the underlying file
        # descriptor position while we have buffered data.  If they
        # do, we might get bogus results here (and the following
        # read() will still return the data cached at the old
        # position).  Just make sure that we don't fail an assert.
        offset = len(self.buf) - self.pos
        if tellpos < offset:
            # bug!  someone changed the fd position under our feet,
            # and moved it at or very close to the beginning of the
            # file, so that we have more buffered data than the
            # current offset.
            self.buf = ""
            self.pos = 0
            offset = 0
        return tellpos - offset

    def seek(self, offset, whence):
        # This may fail on the do_seek() or on the tell() call.
        # But it won't depend on either on a relative forward seek.
        # Nor on a seek to the very end.
        if whence == 0 or whence == 1:
            if whence == 0:
                difpos = offset - self.tell()   # may clean up self.buf/self.pos
            else:
                difpos = offset
            currentsize = len(self.buf) - self.pos
            if -self.pos <= difpos <= currentsize:
                self.pos += intmask(difpos)
                return
            if whence == 1:
                offset -= currentsize
            try:
                self.do_seek(offset, whence)
            except MyNotImplementedError:
                self.buf = ""
                self.pos = 0
                if difpos < 0:
                    raise
                if whence == 0:
                    offset = difpos - currentsize
                intoffset = offset2int(offset)
                self.read(intoffset)
            else:
                self.buf = ""
                self.pos = 0
            return
        if whence == 2:
            try:
                self.do_seek(offset, 2)
            except MyNotImplementedError:
                pass
            else:
                self.pos = 0
                self.buf = ""
                return
            # Skip relative to EOF by reading and saving only just as
            # much as needed
            intoffset = offset2int(offset)
            pos = self.pos
            assert pos >= 0
            buffers = [self.buf[pos:]]
            total = len(buffers[0])
            self.buf = ""
            self.pos = 0
            while 1:
                data = self.do_read(self.bufsize)
                if not data:
                    break
                buffers.append(data)
                total += len(data)
                while buffers and total >= len(buffers[0]) - intoffset:
                    total -= len(buffers[0])
                    del buffers[0]
            cutoff = total + intoffset
            if cutoff < 0:
                raise StreamError("cannot seek back")
            if buffers:
                assert cutoff >= 0
                buffers[0] = buffers[0][cutoff:]
            self.buf = "".join(buffers)
            return

        raise StreamError("whence should be 0, 1 or 2")

    def readall(self):
        pos = self.pos
        assert pos >= 0
        builder = StringBuilder()
        if self.buf:
            builder.append_slice(self.buf, pos, len(self.buf))
        self.buf = ""
        self.pos = 0
        bufsize = self.bufsize
        while 1:
            try:
                data = self.do_read(bufsize)
            except OSError as o:
                # like CPython < 3.4, partial results followed by an error
                # are returned as data
                if not builder.getlength():
                    raise
                break
            if not data:
                break
            builder.append(data)
            bufsize = min(bufsize*2, self.bigsize)
        return builder.build()

    def read(self, n=-1):
        assert isinstance(n, int)
        if n < 0:
            return self.readall()
        currentsize = len(self.buf) - self.pos
        start = self.pos
        assert start >= 0
        if n <= currentsize:
            stop = start + n
            assert stop >= 0
            result = self.buf[start:stop]
            self.pos += n
            return result
        else:
            builder = StringBuilder(n)
            builder.append_slice(self.buf, start, len(self.buf))
            while 1:
                self.buf = self.do_read(self.bufsize)
                if not self.buf:
                    self.pos = 0
                    break
                currentsize += len(self.buf)
                if currentsize >= n:
                    self.pos = len(self.buf) - (currentsize - n)
                    stop = self.pos
                    assert stop >= 0
                    builder.append_slice(self.buf, 0, stop)
                    break
                buf = self.buf
                assert buf is not None
                builder.append(buf)
            return builder.build()

    def readline(self):
        pos = self.pos
        assert pos >= 0
        i = self.buf.find("\n", pos)
        start = self.pos
        assert start >= 0
        if i >= 0: # new line found
            i += 1
            result = self.buf[start:i]
            self.pos = i
            return result
        temp = self.buf[start:]
        # read one buffer and most of the time a new line will be found
        self.buf = self.do_read(self.bufsize)
        i = self.buf.find("\n")
        if i >= 0: # new line found
            i += 1
            result = temp + self.buf[:i]
            self.pos = i
            return result
        if not self.buf:
            self.pos = 0
            return temp
        # need to keep getting data until we find a new line
        builder = StringBuilder(len(temp) + len(self.buf)) # at least
        builder.append(temp)
        builder.append(self.buf)
        while 1:
            self.buf = self.do_read(self.bufsize)
            if not self.buf:
                self.pos = 0
                break
            i = self.buf.find("\n")
            if i >= 0:
                i += 1
                builder.append_slice(self.buf, 0, i)
                self.pos = i
                break
            builder.append(self.buf)
        return builder.build()

    def peek(self):
        return (self.pos, self.buf)

    write      = PassThrough("write",     flush_buffers=True)
    truncate   = PassThrough("truncate",  flush_buffers=True)
    flush      = PassThrough("flush",     flush_buffers=True)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)


class BufferingOutputStream(Stream):
    """Standard buffering output stream.

    This, and BufferingInputStream if needed, are typically at the top of
    the stack of streams.
    """

    bigsize = 2**19 # Half a Meg
    bufsize = 2**13 # 8 K

    def __init__(self, base, bufsize=-1):
        self.base = base
        self.do_tell  = base.tell   # return a byte offset
        if bufsize == -1:     # Get default from the class
            bufsize = self.bufsize
        self.bufsize = bufsize  # buffer size (hint only)
        self.buf = []
        self.buflen = 0
        self.error = False

    def do_write(self, data):
        try:
            self.base.write(data)
        except:
            self.error = True
            raise

    def flush_buffers(self):
        if self.buf and not self.error:
            self.do_write(''.join(self.buf))
            self.buf = []
            self.buflen = 0

    def tell(self):
        return self.do_tell() + self.buflen

    def write(self, data):
        self.error = False
        buflen = self.buflen
        datalen = len(data)
        if datalen + buflen < self.bufsize:
            self.buf.append(data)
            self.buflen += datalen
        elif buflen:
            self.buf.append(data)
            self.do_write(''.join(self.buf))
            self.buf = []
            self.buflen = 0
        else:
            self.do_write(data)

    read       = PassThrough("read",     flush_buffers=True)
    readall    = PassThrough("readall",  flush_buffers=True)
    readline   = PassThrough("readline", flush_buffers=True)
    seek       = PassThrough("seek",     flush_buffers=True)
    truncate   = PassThrough("truncate", flush_buffers=True)
    flush      = PassThrough("flush",    flush_buffers=True)
    close1     = PassThrough("close1",   flush_buffers=True)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)

    def flushable(self):
        return True


class LineBufferingOutputStream(BufferingOutputStream):
    """Line buffering output stream.

    This is typically the top of the stack.
    """

    def write(self, data):
        self.error = False
        p = data.rfind('\n') + 1
        assert p >= 0
        if self.buflen + len(data) < self.bufsize:
            if p == 0:
                self.buf.append(data)
                self.buflen += len(data)
            else:
                if self.buflen:
                    self.buf.append(data[:p])
                    self.do_write(''.join(self.buf))
                else:
                    self.do_write(data[:p])
                self.buf = [data[p:]]
                self.buflen = len(self.buf[0])
        else:
            if self.buflen + p < self.bufsize:
                p = self.bufsize - self.buflen
            if self.buflen:
                self.do_write(''.join(self.buf))
            assert p >= 0
            self.do_write(data[:p])
            self.buf = [data[p:]]
            self.buflen = len(self.buf[0])

# ____________________________________________________________

class CRLFFilter(Stream):
    """Filtering stream for universal newlines.

    TextInputFilter is more general, but this is faster when you don't
    need tell/seek.
    """

    def __init__(self, base):
        self.base = base
        self.do_read = base.read
        self.atcr = False

    def read(self, n):
        data = self.do_read(n)
        if self.atcr:
            if data.startswith("\n"):
                data = data[1:] # Very rare case: in the middle of "\r\n"
            self.atcr = False
        if "\r" in data:
            self.atcr = data.endswith("\r")     # Test this before removing \r
            data = replace_crlf_with_lf(data)
        return data

    flush    = PassThrough("flush", flush_buffers=False)
    flushable= PassThrough("flushable", flush_buffers=False)
    close1   = PassThrough("close1", flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)

class TextCRLFFilter(Stream):
    """Filtering stream for universal newlines.

    TextInputFilter is more general, but this is faster when you don't
    need tell/seek.
    """

    def __init__(self, base):
        self.base = base
        self.do_read = base.read
        self.do_write = base.write
        self.do_flush = base.flush_buffers
        self.readahead_count = 0   # either 0 or 1

    def read(self, n=-1):
        """If n >= 1, this should read between 1 and n bytes."""
        if n <= 0:
            if n < 0:
                return self.readall()
            else:
                return ""

        data = self.do_read(n - self.readahead_count)
        if self.readahead_count > 0:
            data = self.readahead_char + data
            self.readahead_count = 0

        if data.endswith("\r"):
            c = self.do_read(1)
            if len(c) >= 1:
                assert len(c) == 1
                if c[0] == '\n':
                    data = data + '\n'
                else:
                    self.readahead_char = c[0]
                    self.readahead_count = 1

        result = []
        offset = 0
        while True:
            newoffset = data.find('\r\n', offset)
            if newoffset < 0:
                result.append(data[offset:])
                break
            result.append(data[offset:newoffset])
            offset = newoffset + 2

        return '\n'.join(result)

    def readline(self):
        line = self.base.readline()
        limit = len(line) - 2
        if limit >= 0 and line[limit] == '\r' and line[limit + 1] == '\n':
            line = line[:limit] + '\n'
        return line

    def tell(self):
        pos = self.base.tell()
        return pos - self.readahead_count

    def seek(self, offset, whence):
        if whence == 1:
            offset -= self.readahead_count   # correct for already-read-ahead character
        self.base.seek(offset, whence)
        self.readahead_count = 0

    def flush_buffers(self):
        if self.readahead_count > 0:
            try:
                self.base.seek(-self.readahead_count, 1)
            except (MyNotImplementedError, OSError):
                return
            self.readahead_count = 0
        self.do_flush()

    def write(self, data):
        data = replace_char_with_str(data, '\n', '\r\n')
        self.flush_buffers()
        self.do_write(data)

    truncate = PassThrough("truncate", flush_buffers=True)
    flush    = PassThrough("flush", flush_buffers=False)
    flushable= PassThrough("flushable", flush_buffers=False)
    close1   = PassThrough("close1", flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)

class TextInputFilter(Stream):
    """Filtering input stream for universal newline translation."""

    def __init__(self, base):
        self.base = base   # must implement read, may implement tell, seek
        self.do_read = base.read
        self.atcr = False  # Set when last char read was \r
        self.buf = ""      # Optional one-character read-ahead buffer
        self.CR = False
        self.NL = False
        self.CRLF = False

    def getnewlines(self):
        return self.CR * 1 + self.NL * 2 + self.CRLF * 4

    def read(self, n):
        """Read up to n bytes."""
        if self.buf:
            assert not self.atcr
            data = self.buf
            self.buf = ""
        else:
            data = self.do_read(n)

        # The following whole ugly mess is because we need to keep track of
        # exactly which line separators we have seen for self.newlines,
        # grumble, grumble.  This has an interesting corner-case.
        #
        # Consider a file consisting of exactly one line ending with '\r'.
        # The first time you read(), you will not know whether it is a
        # CR separator or half of a CRLF separator.  Neither will be marked
        # as seen, since you are waiting for your next read to determine
        # what you have seen.  But there's no more to read ...

        if self.atcr:
            if data.startswith("\n"):
                data = data[1:]
                self.CRLF = True
                if not data:
                    data = self.do_read(n)
            else:
                self.CR = True
            self.atcr = False

        for i in range(len(data)):
            if data[i] == '\n':
                if i > 0 and data[i-1] == '\r':
                    self.CRLF = True
                else:
                    self.NL = True
            elif data[i] == '\r':
                if i < len(data)-1 and data[i+1] != '\n':
                    self.CR = True

        if "\r" in data:
            self.atcr = data.endswith("\r")
            data = replace_crlf_with_lf(data)

        return data

    def readline(self):
        result = []
        while True:
            # "peeks" on the underlying stream to see how many characters
            # we can safely read without reading past an end-of-line
            startindex, peeked = self.base.peek()
            assert 0 <= startindex <= len(peeked)
            cl_or_lf_pos = len(peeked)
            for i in range(startindex, len(peeked)):
                ch = peeked[i]
                if ch == '\n' or ch == '\r':
                    cl_or_lf_pos = i
                    break
            c = self.read(cl_or_lf_pos - startindex + 1)
            if not c:
                break
            result.append(c)
            if c.endswith('\n'):
                break
        return ''.join(result)

    def seek(self, offset, whence):
        """Seeks based on knowledge that does not come from a tell()
           may go to the wrong place, since the number of
           characters seen may not match the number of characters
           that are actually in the file (where \r\n is the
           line separator). Arithmetics on the result
           of a tell() that moves beyond a newline character may in the
           same way give the wrong result.
        """
        if whence == 1:
            offset -= len(self.buf)   # correct for already-read-ahead character
        self.base.seek(offset, whence)
        self.atcr = False
        self.buf = ""

    def tell(self):
        pos = self.base.tell()
        if self.atcr:
            # Must read the next byte to see if it's \n,
            # because then we must report the next position.
            assert not self.buf
            self.buf = self.do_read(1)
            pos += 1
            self.atcr = False
            if self.buf == "\n":
                self.CRLF = True
                self.buf = ""
        return pos - len(self.buf)

    def flush_buffers(self):
        if self.atcr:
            assert not self.buf
            self.buf = self.do_read(1)
            self.atcr = False
            if self.buf == "\n":
                self.buf = ""
        if self.buf:
            try:
                self.base.seek(-len(self.buf), 1)
            except (MyNotImplementedError, OSError):
                pass
            else:
                self.buf = ""

    def peek(self):
        return (0, self.buf)

    write      = PassThrough("write",     flush_buffers=True)
    truncate   = PassThrough("truncate",  flush_buffers=True)
    flush      = PassThrough("flush",     flush_buffers=True)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)


class TextOutputFilter(Stream):
    """Filtering output stream for universal newline translation."""

    def __init__(self, base, linesep=os.linesep):
        assert linesep in ["\n", "\r\n", "\r"]
        self.base = base    # must implement write, may implement seek, tell
        self.linesep = linesep

    def write(self, data):
        data = replace_char_with_str(data, "\n", self.linesep)
        self.base.write(data)

    tell       = PassThrough("tell",      flush_buffers=False)
    seek       = PassThrough("seek",      flush_buffers=False)
    read       = PassThrough("read",      flush_buffers=False)
    readall    = PassThrough("readall",   flush_buffers=False)
    readline   = PassThrough("readline",  flush_buffers=False)
    truncate   = PassThrough("truncate",  flush_buffers=False)
    flush      = PassThrough("flush",     flush_buffers=False)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)


class CallbackReadFilter(Stream):
    """Pseudo read filter that invokes a callback before blocking on a read.
    """

    def __init__(self, base, callback):
        self.base = base
        self.callback = callback

    def flush_buffers(self):
        self.callback()

    tell       = PassThrough("tell",      flush_buffers=False)
    seek       = PassThrough("seek",      flush_buffers=False)
    read       = PassThrough("read",      flush_buffers=True)
    readall    = PassThrough("readall",   flush_buffers=True)
    readline   = PassThrough("readline",  flush_buffers=True)
    peek       = PassThrough("peek",      flush_buffers=False)
    flush      = PassThrough("flush",     flush_buffers=False)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    write      = PassThrough("write",     flush_buffers=False)
    truncate   = PassThrough("truncate",  flush_buffers=False)
    getnewlines= PassThrough("getnewlines",flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)

# _________________________________________________
# The following functions are _not_ RPython!

class DecodingInputFilter(Stream):
    """Filtering input stream that decodes an encoded file."""

    @not_rpython
    def __init__(self, base, encoding="utf8", errors="strict"):
        self.base = base
        self.do_read = base.read
        self.encoding = encoding
        self.errors = errors

    def read(self, n):
        """Read *approximately* n bytes, then decode them.

        Under extreme circumstances,
        the return length could be longer than n!

        Always return a unicode string.

        This does *not* translate newlines;
        you can stack TextInputFilter.
        """
        data = self.do_read(n)
        try:
            return data.decode(self.encoding, self.errors)
        except ValueError:
            # XXX Sigh.  decode() doesn't handle incomplete strings well.
            # Use the retry strategy from codecs.StreamReader.
            for i in range(9):
                more = self.do_read(1)
                if not more:
                    raise
                data += more
                try:
                    return data.decode(self.encoding, self.errors)
                except ValueError:
                    pass
            raise

    write      = PassThrough("write",     flush_buffers=False)
    truncate   = PassThrough("truncate",  flush_buffers=False)
    flush      = PassThrough("flush",     flush_buffers=False)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)

class EncodingOutputFilter(Stream):
    """Filtering output stream that writes to an encoded file."""

    @not_rpython
    def __init__(self, base, encoding="utf8", errors="strict"):
        self.base = base
        self.do_write = base.write
        self.encoding = encoding
        self.errors = errors

    def write(self, chars):
        if isinstance(chars, str):
            chars = unicode(chars) # Fail if it's not ASCII
        self.do_write(chars.encode(self.encoding, self.errors))

    tell       = PassThrough("tell",      flush_buffers=False)
    seek       = PassThrough("seek",      flush_buffers=False)
    read       = PassThrough("read",      flush_buffers=False)
    readall    = PassThrough("readall",   flush_buffers=False)
    readline   = PassThrough("readline",  flush_buffers=False)
    truncate   = PassThrough("truncate",  flush_buffers=False)
    flush      = PassThrough("flush",     flush_buffers=False)
    flushable  = PassThrough("flushable", flush_buffers=False)
    close1     = PassThrough("close1",    flush_buffers=False)
    try_to_find_file_descriptor = PassThrough("try_to_find_file_descriptor",
                                              flush_buffers=False)
