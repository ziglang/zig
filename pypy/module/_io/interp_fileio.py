from pypy.interpreter.typedef import TypeDef, interp_attrproperty, GetSetProperty
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.error import (
    OperationError, oefmt, wrap_oserror, wrap_oserror2)
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib.rarithmetic import r_longlong
from rpython.rlib.rposix import c_read, get_saved_errno
from rpython.rlib.rstring import StringBuilder
from rpython.rlib import rposix
from rpython.rlib import jit
from rpython.rlib.rposix_stat import STAT_FIELD_TYPES
from rpython.rlib.streamio import _setfd_binary
from rpython.rtyper.lltypesystem import lltype, rffi
from os import O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, O_TRUNC, O_EXCL
import sys, os, stat, errno
from pypy.module._io.interp_iobase import (
    W_RawIOBase, convert_size, DEFAULT_BUFFER_SIZE)

HAS_BLKSIZE = 'st_blksize' in STAT_FIELD_TYPES

def interp_member_w(name, cls, doc=None):
    "NOT_RPYTHON: initialization-time only"
    def fget(space, obj):
        w_value = getattr(obj, name)
        if w_value is None:
            raise OperationError(space.w_AttributeError, space.newtext(name))
        else:
            return w_value
    def fset(space, obj, w_value):
        setattr(obj, name, w_value)
    def fdel(space, obj):
        w_value = getattr(obj, name)
        if w_value is None:
            raise OperationError(space.w_AttributeError, space.newtext(name))
        setattr(obj, name, None)

    return GetSetProperty(fget, fset, fdel, cls=cls, doc=doc)


O_BINARY = getattr(os, "O_BINARY", 0)
O_APPEND = getattr(os, "O_APPEND", 0)
_open_inhcache = rposix.SetNonInheritableCache()

def _bad_mode(space):
    raise oefmt(space.w_ValueError,
                "Must have exactly one of read/write/create/append mode")

@jit.look_inside_iff(lambda space, mode: jit.isconstant(mode))
def decode_mode(space, mode):
    flags = 0
    rwa = False
    readable = False
    writable = False
    created = False
    append = False
    plus = False

    for s in mode:
        if s == 'r':
            if rwa:
                _bad_mode(space)
            rwa = True
            readable = True
        elif s == 'w':
            if rwa:
                _bad_mode(space)
            rwa = True
            writable = True
            flags |= O_CREAT | O_TRUNC
        elif s == 'x':
            if rwa:
                _bad_mode(space)
            rwa = True
            created = True
            writable = True
            flags |= O_EXCL | O_CREAT
        elif s == 'a':
            if rwa:
                _bad_mode(space)
            rwa = True
            writable = True
            append = True
            flags |= O_APPEND | O_CREAT
        elif s == 'b':
            pass
        elif s == '+':
            if plus:
                _bad_mode(space)
            readable = writable = True
            plus = True
        else:
            raise oefmt(space.w_ValueError, "invalid mode: %s", mode)

    if not rwa:
        _bad_mode(space)

    if readable and writable:
        flags |= O_RDWR
    elif readable:
        flags |= O_RDONLY
    else:
        flags |= O_WRONLY

    flags |= O_BINARY

    return readable, writable, created, append, flags

SMALLCHUNK = 8 * 1024
BIGCHUNK = 512 * 1024

def new_buffersize(fd, currentsize):
    try:
        st = os.fstat(fd)
        end = st.st_size
        pos = os.lseek(fd, 0, 1)
    except OSError:
        pass
    else:
        # Files claiming a size smaller than SMALLCHUNK may
        # actually be streaming pseudo-files. In this case, we
        # apply the more aggressive algorithm below.
        if end >= SMALLCHUNK and end >= pos:
            # Add 1 so if the file were to grow we'd notice.
            return currentsize + end - pos + 1

    if currentsize > SMALLCHUNK:
        # Keep doubling until we reach BIGCHUNK;
        # then keep adding BIGCHUNK.
        if currentsize <= BIGCHUNK:
            return currentsize + currentsize
        else:
            return currentsize + BIGCHUNK
    return currentsize + SMALLCHUNK

def _open_fd(space, w_name, flags):
    from pypy.module.posix.interp_posix import dispatch_filename, fspath
    w_path = fspath(space, w_name)
    while True:
        try:
            fd = dispatch_filename(rposix.open)(
                space, w_path, flags, 0666)
            fd_is_own = True
            break
        except OSError as e:
            wrap_oserror2(space, e, w_name,
                          w_exception_class=space.w_IOError,
                          eintr_retry=True)
    try:
         _open_inhcache.set_non_inheritable(fd)
    except OSError as e:
        raise wrap_oserror2(space, e, w_name,
                            eintr_retry=False)
    return fd

class W_FileIO(W_RawIOBase):
    def __init__(self, space):
        W_RawIOBase.__init__(self, space)
        self.fd = -1
        self.readable = False
        self.writable = False
        self.created = False
        self.appending = False
        self.seekable = -1
        self.closefd = True
        self.w_name = None

    def descr_new(space, w_subtype, __args__):
        self = space.allocate_instance(W_FileIO, w_subtype)
        W_FileIO.__init__(self, space)
        return self

    @unwrap_spec(mode='text', closefd=int)
    def descr_init(self, space, w_name, mode='r', closefd=True, w_opener=None):
        if self.fd >= 0:
            if self.closefd:
                self._close(space)
            else:
                self.fd = -1

        if space.isinstance_w(w_name, space.w_float):
            raise oefmt(space.w_TypeError,
                        "integer argument expected, got float")

        fd = -1
        try:
            fd = space.c_int_w(w_name)
        except OperationError as e:
            pass
        else:
            if fd < 0:
                raise oefmt(space.w_ValueError, "negative file descriptor")

        self.readable, self.writable, self.created, self.appending, flags = decode_mode(space, mode)
        if rposix.O_CLOEXEC is not None:
            flags |= rposix.O_CLOEXEC

        fd_is_own = False
        try:
            if fd >= 0:
                self.fd = fd
                self.closefd = bool(closefd)
                space.audit("open", [space.newint(fd), space.newtext(mode), space.newint(closefd)])
            else:
                space.audit("open", [w_name, space.newtext(mode), space.newint(1)])
                self.closefd = True
                if not closefd:
                    raise oefmt(space.w_ValueError,
                                "Cannot use closefd=False with file name")

                if space.is_none(w_opener):
                    self.fd = _open_fd(space, w_name, flags)
                    fd_is_own = True
                else:
                    w_fd = space.call_function(w_opener, w_name,
                                               space.newint(flags))
                    try:
                        self.fd = space.int_w(w_fd)
                        if self.fd < 0:
                            # The opener returned a negative result instead
                            # of raising an exception
                            raise oefmt(space.w_ValueError,
                                        "opener returned %d", self.fd)
                        fd_is_own = True
                    except OperationError as e:
                        if not e.match(space, space.w_TypeError):
                            raise
                        raise oefmt(space.w_TypeError,
                                    "expected integer from opener")
                    if not rposix._WIN32:
                        try:
                            rposix.set_inheritable(self.fd, False)
                        except OSError as e:
                            raise wrap_oserror2(space, e, w_name,
                                                eintr_retry=False)


            try:
                st = os.fstat(self.fd)
            except OSError as e:
                raise wrap_oserror(space, e, eintr_retry=False)
            # On Unix, fopen will succeed for directories.
            # In Python, there should be no file objects referring to
            # directories, so we need a check.
            if stat.S_ISDIR(st.st_mode):
                raise wrap_oserror2(space, OSError(errno.EISDIR, "fstat"),
                                    w_name, w_exception_class=space.w_IOError,
                                    eintr_retry=False)
            self.blksize = DEFAULT_BUFFER_SIZE
            if HAS_BLKSIZE and st.st_blksize > 1:
                self.blksize = st.st_blksize

            _setfd_binary(self.fd)

            space.setattr(self, space.newtext("name"), w_name)

            if self.appending:
                # For consistent behaviour, we explicitly seek to the end of file
                # (otherwise, it might be done only on the first write()).
                try:
                    os.lseek(self.fd, 0, os.SEEK_END)
                except OSError as e:
                    if e.errno != errno.ESPIPE:
                        raise wrap_oserror(space, e, w_exception_class=space.w_IOError,
                                           eintr_retry=False)
        except:
            if not fd_is_own:
                self.fd = -1
            self._close(space)
            raise

    def _mode(self):
        if self.created:
            if self.readable:
                return 'xb+'
            else:
                return 'xb'
        if self.appending:
            if self.readable:
                return 'ab+'
            else:
                return 'ab'
        elif self.readable:
            if self.writable:
                return 'rb+'
            else:
                return 'rb'
        else:
            return 'wb'

    def descr_get_mode(self, space):
        return space.newtext(self._mode())

    def get_blksize(self, space):
        return space.newint(self.blksize)

    def _closed(self, space):
        return self.fd < 0

    def _check_closed(self, space, message=None):
        if message is None:
            message = "I/O operation on closed file"
        if self.fd < 0:
            raise OperationError(space.w_ValueError, space.newtext(message))

    def _check_readable(self, space):
        if not self.readable:
            self._unsupportedoperation(space, "File not open for reading")

    def _check_writable(self, space):
        if not self.writable:
            self._unsupportedoperation(space, "File not open for writing")

    def _close(self, space):
        if self.fd < 0:
            return
        fd = self.fd
        self.fd = -1

        try:
            os.close(fd)
        except OSError as e:
            raise wrap_oserror(space, e,
                               w_exception_class=space.w_IOError,
                               eintr_retry=False)

    def close_w(self, space):
        try:
            W_RawIOBase.close_w(self, space)
        except OperationError:
            if not self.closefd:
                self.fd = -1
                raise
            self._close(space)
            raise
        if not self.closefd:
            self.fd = -1
            return
        self._close(space)

    def _dealloc_warn_w(self, space, w_source):
        if self.fd >= 0 and self.closefd:
            try:
                msg = ("unclosed file %s" %
                       space.text_w(space.repr(w_source)))
                space.warn(space.newtext(msg), space.w_ResourceWarning)
            except OperationError as e:
                # Spurious errors can appear at shutdown
                if e.match(space, space.w_Warning):
                    e.write_unraisable(space, '', self)

    @unwrap_spec(pos=r_longlong, whence=int)
    def seek_w(self, space, pos, whence=0):
        self._check_closed(space)
        try:
            pos = os.lseek(self.fd, pos, whence)
        except OSError as e:
            raise wrap_oserror(space, e,
                               w_exception_class=space.w_IOError,
                               eintr_retry=False)
        return space.newint(pos)

    def _raw_tell(self, space):
        self._check_closed(space)
        try:
            pos = os.lseek(self.fd, 0, 1)
        except OSError as e:
            raise wrap_oserror(space, e,
                               w_exception_class=space.w_IOError,
                               eintr_retry=False)
        return pos

    def tell_w(self, space):
        pos = self._raw_tell(space)
        return space.newint(pos)

    def readable_w(self, space):
        self._check_closed(space)
        return space.newbool(self.readable)

    def writable_w(self, space):
        self._check_closed(space)
        return space.newbool(self.writable)

    def seekable_w(self, space):
        self._check_closed(space)
        if self.seekable < 0:
            try:
                os.lseek(self.fd, 0, os.SEEK_CUR)
            except OSError:
                self.seekable = 0
            else:
                self.seekable = 1
        return space.newbool(self.seekable == 1)

    # ______________________________________________

    def fileno_w(self, space):
        self._check_closed(space)
        return space.newint(self.fd)

    def isatty_w(self, space):
        self._check_closed(space)
        try:
            res = os.isatty(self.fd)
        except OSError as e:
            raise wrap_oserror(space, e, w_exception_class=space.w_IOError,
                               eintr_retry=False)
        return space.newbool(res)

    def repr_w(self, space):
        if self.fd < 0:
            return space.newtext("<_io.FileIO [closed]>")

        closefd = "True" if self.closefd else "False"

        if self.w_name is None:
            return space.newtext(
                "<_io.FileIO fd=%d mode='%s' closefd=%s>" % (
                    self.fd, self._mode(), closefd))
        else:
            w_repr = space.repr(self.w_name)
            return space.newtext(
                "<_io.FileIO name=%s mode='%s' closefd=%s>" % (
                    space.text_w(w_repr), self._mode(), closefd))

    # ______________________________________________

    def write_w(self, space, w_data):
        self._check_closed(space)
        self._check_writable(space)
        data = space.charbuf_w(w_data)

        while True:
            try:
                n = os.write(self.fd, data)
                break
            except OSError as e:
                if e.errno == errno.EAGAIN:
                    return space.w_None
                wrap_oserror(space, e,
                             w_exception_class=space.w_IOError,
                             eintr_retry=True)

        return space.newint(n)

    def read_w(self, space, w_size=None):
        self._check_closed(space)
        self._check_readable(space)
        size = convert_size(space, w_size)

        if size < 0:
            return self.readall_w(space)

        while True:
            try:
                s = os.read(self.fd, size)
                break
            except OSError as e:
                if e.errno == errno.EAGAIN:
                    return space.w_None
                wrap_oserror(space, e,
                             w_exception_class=space.w_IOError,
                             eintr_retry=True)

        return space.newbytes(s)

    def readinto_w(self, space, w_buffer):
        self._check_closed(space)
        self._check_readable(space)
        rwbuffer = space.writebuf_w(w_buffer)
        length = rwbuffer.getlength()

        target_address = lltype.nullptr(rffi.CCHARP.TO)
        if length > 64:
            try:
                target_address = rwbuffer.get_raw_address()
            except ValueError:
                pass

        if not target_address:
            # unoptimized case
            while True:
                try:
                    buf = os.read(self.fd, length)
                    break
                except OSError as e:
                    if e.errno == errno.EAGAIN:
                        return space.w_None
                    wrap_oserror(space, e, w_exception_class=space.w_IOError,
                                 eintr_retry=True)
            self.output_slice(space, rwbuffer, 0, buf)
            return space.newint(len(buf))
        else:
            w_res = self._readinto_raw(space, target_address, length)
            keepalive_until_here(rwbuffer)
            return w_res

    def _readinto_raw(self, space, target_address, length):
        # optimized case: reading more than 64 bytes into a rwbuffer
        # with a valid raw address

        # caller is responsible for keeping the backing of target_address alive
        # until after the call
        while True:
            got = c_read(self.fd, target_address, length)
            got = rffi.cast(lltype.Signed, got)
            if got >= 0:
                return space.newint(got)
            else:
                err = get_saved_errno()
                if err == errno.EAGAIN:
                    return space.w_None
                e = OSError(err, "read failed")
                wrap_oserror(space, e, w_exception_class=space.w_IOError,
                             eintr_retry=True)

    def readall_w(self, space):
        self._check_closed(space)
        self._check_readable(space)
        total = 0

        builder = StringBuilder()
        while True:
            newsize = int(new_buffersize(self.fd, total))

            try:
                chunk = os.read(self.fd, newsize - total)
            except OSError as e:
                if e.errno == errno.EAGAIN:
                    if total > 0:
                        break   # return what we've got so far
                    return space.w_None
                wrap_oserror(space, e, w_exception_class=space.w_IOError,
                             eintr_retry=True)
                continue
            if not chunk:
                break
            builder.append(chunk)
            total += len(chunk)
        return space.newbytes(builder.build())

    if sys.platform == "win32":
        def _truncate(self, size):
            from rpython.rlib.streamio import ftruncate_win32
            ftruncate_win32(self.fd, size)
    else:
        def _truncate(self, size):
            os.ftruncate(self.fd, size)

    def truncate_w(self, space, w_size=None):
        self._check_closed(space)
        self._check_writable(space)
        if space.is_none(w_size):
            w_size = self.tell_w(space)

        try:
            self._truncate(space.r_longlong_w(w_size))
        except OSError as e:
            raise wrap_oserror(space, e, w_exception_class=space.w_IOError,
                               eintr_retry=False)

        return w_size

W_FileIO.typedef = TypeDef(
    '_io.FileIO', W_RawIOBase.typedef,
    __new__  = interp2app(W_FileIO.descr_new.im_func),
    __init__  = interp2app(W_FileIO.descr_init),
    __repr__ = interp2app(W_FileIO.repr_w),
    __getstate__ = interp2app(W_FileIO.getstate_w),

    seek = interp2app(W_FileIO.seek_w),
    tell = interp2app(W_FileIO.tell_w),
    write = interp2app(W_FileIO.write_w),
    read = interp2app(W_FileIO.read_w),
    readinto = interp2app(W_FileIO.readinto_w),
    readall = interp2app(W_FileIO.readall_w),
    truncate = interp2app(W_FileIO.truncate_w),
    close = interp2app(W_FileIO.close_w),

    readable = interp2app(W_FileIO.readable_w),
    writable = interp2app(W_FileIO.writable_w),
    seekable = interp2app(W_FileIO.seekable_w),
    fileno = interp2app(W_FileIO.fileno_w),
    isatty = interp2app(W_FileIO.isatty_w),
    _dealloc_warn = interp2app(W_FileIO._dealloc_warn_w),
    name = interp_member_w('w_name', cls=W_FileIO),
    closefd = interp_attrproperty(
        'closefd', cls=W_FileIO, wrapfn="newbool",
        doc="True if the file descriptor will be closed"),
    mode = GetSetProperty(W_FileIO.descr_get_mode,
                          doc="String giving the file mode"),
    _blksize = GetSetProperty(W_FileIO.get_blksize),
    )

