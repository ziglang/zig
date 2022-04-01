import os
import sys
from math import modf
from errno import EOPNOTSUPP
try:
    from errno import ENOTSUP
except ImportError:
    # some Pythons don't have errno.ENOTSUP
    ENOTSUP = 0

from rpython.rlib import rposix, rposix_stat, rfile
from rpython.rlib import objectmodel, rurandom
from rpython.rlib.objectmodel import specialize, not_rpython
from rpython.rlib.rarithmetic import (
    r_longlong, intmask, r_uint, r_int, INT_MIN, INT_MAX)

from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.tool.sourcetools import func_with_new_name

from pypy.interpreter.buffer import BufferInterfaceNotFound
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault, Unwrapper
from pypy.interpreter.error import (
    OperationError, oefmt, wrap_oserror, wrap_oserror2, strerror as _strerror,
    exception_from_saved_errno)
from pypy.interpreter.executioncontext import ExecutionContext
from pypy.interpreter.baseobjspace import W_Root


_WIN32 = sys.platform == 'win32'
if _WIN32:
    from rpython.rlib import rwin32

c_int = "c_int"

# CPython 2.7 semantics used to be too messy, differing on 32-bit vs
# 64-bit, but this was cleaned up in recent 2.7.x.  Now, any function
# taking a uid_t or gid_t accepts numbers in range(-1, 2**32) as an
# r_uint, with -1 being equivalent to 2**32-1.  Any function that
# returns a uid_t or gid_t returns either an int or a long, depending
# on whether it fits or not, but always positive.
c_uid_t = 'c_uid_t'
c_gid_t = 'c_uid_t'

def wrap_uid(space, uid):
    if uid <= r_uint(sys.maxint):
        return space.newint(intmask(uid))
    else:
        return space.newint(uid)     # an unsigned number
wrap_gid = wrap_uid

class FileEncoder(object):
    is_unicode = True

    def __init__(self, space, w_obj):
        self.space = space
        self.w_obj = w_obj

    def as_bytes(self):
        return self.space.fsencode_w(self.w_obj)

    def as_unicode(self):
        ret = self.space.realunicode_w(self.w_obj)
        if u'\x00' in ret:
            raise oefmt(self.space.w_ValueError, "embedded null character")
        return ret

class FileDecoder(object):
    is_unicode = False

    def __init__(self, space, w_obj):
        self.space = space
        self.w_obj = w_obj

    def as_bytes(self):
        return self.space.fsencode_w(self.w_obj)

    def as_unicode(self):
        ret = self.space.fsdecode_w(self.w_obj).decode('utf-8')
        if u'\x00' in ret:
            raise oefmt(self.space.w_ValueError, "embedded null character")
        return ret

@specialize.memo()
def make_dispatch_function(func, tag, allow_fd_fn=None):
    def dispatch(space, w_fname, *args):
        if allow_fd_fn is not None:
            try:
                fd = space.c_int_w(w_fname)
            except OperationError:
                pass
            else:
                return allow_fd_fn(fd, *args)
        if space.isinstance_w(w_fname, space.w_unicode):
            fname = FileEncoder(space, w_fname)
            return func(fname, *args)
        else:
            fname = FileDecoder(space, w_fname)
            return func(fname, *args)
    return dispatch

@specialize.arg(0, 1)
def dispatch_filename(func, tag=0, allow_fd_fn=None):
    return make_dispatch_function(func, tag, allow_fd_fn)

@specialize.memo()
def dispatch_filename_2(func):
    def dispatch(space, w_fname1, w_fname2, *args):
        if space.isinstance_w(w_fname1, space.w_unicode):
            fname1 = FileEncoder(space, w_fname1)
            if space.isinstance_w(w_fname2, space.w_unicode):
                fname2 = FileEncoder(space, w_fname2)
                return func(fname1, fname2, *args)
            else:
                fname2 = FileDecoder(space, w_fname2)
                return func(fname1, fname2, *args)
        else:
            fname1 = FileDecoder(space, w_fname1)
            if space.isinstance_w(w_fname2, space.w_unicode):
                fname2 = FileEncoder(space, w_fname2)
                return func(fname1, fname2, *args)
            else:
                fname2 = FileDecoder(space, w_fname2)
                return func(fname1, fname2, *args)
    return dispatch

@specialize.arg(0)
def call_rposix(func, path, *args):
    """Call a function that takes a filesystem path as its first argument"""
    if path.as_unicode is not None:
        return func(path.as_unicode, *args)
    else:
        path_b = path.as_bytes
        assert path_b is not None
        return func(path_b, *args)


class Path(object):
    _immutable_fields_ = ['as_fd', 'as_bytes', 'as_unicode', 'w_path']

    def __init__(self, fd, bytes, unicode, w_path):
        self.as_fd = fd
        self.as_bytes = bytes
        self.as_unicode = unicode
        self.w_path = w_path

    def __repr__(self):
        # For debugging
        return ''.join(['Path(', str(self.as_fd), ', ', str(self.as_bytes),
                        ', ', str(self.as_unicode), ', [', str(self.w_path),
                        ', ', str(getattr(self.w_path, '_length', 'bytes')), '])'])

def _path_from_unicode(space, w_value):
    if _WIN32:
        path_u = FileEncoder(space, w_value).as_unicode()
        return Path(-1, None, path_u, w_value)
    else:
        path_b = space.bytes0_w(space.fsencode(w_value))
        return Path(-1, path_b, None, w_value)

def _path_from_bytes(space, w_value):
    path_b = space.bytes0_w(w_value)
    return Path(-1, path_b, None, w_value)

@specialize.arg(2, 3)
def _unwrap_path(space, w_value, allow_fd=True, nullable=False):
    # equivalent of posixmodule.c:path_converter() in CPython
    if nullable:
        if allow_fd:
            allowed_types = "string, bytes, os.PathLike, integer or None"
        else:
            allowed_types = "string, bytes, os.PathLike or None"
    else:
        if allow_fd:
            allowed_types = "string, bytes, os.PathLike or integer"
        else:
            allowed_types = "string, bytes or os.PathLike"
    if nullable and space.is_w(w_value, space.w_None):
        return Path(-1, '.', None, space.w_None)
    if space.isinstance_w(w_value, space.w_unicode):
        return _path_from_unicode(space, w_value)
    elif space.isinstance_w(w_value, space.w_bytes):
        return _path_from_bytes(space, w_value)

    # Bytes-like case
    try:
        space._try_buffer_w(w_value, space.BUF_FULL_RO)
    except BufferInterfaceNotFound:
        pass
    else:
        tp = space.type(w_value).name
        space.warn(space.newtext(
            "path should be %s, not %s" % (allowed_types, tp,)),
            space.w_DeprecationWarning)
        path_b = space.bytesbuf0_w(w_value)
        return Path(-1, path_b, None, w_value)

    # File descriptor case
    if allow_fd:
        try:
            space.index(w_value)
        except OperationError:
            pass
        else:
            fd = unwrap_fd(space, w_value, allowed_types)
            return Path(fd, None, None, w_value)

    # PathLike case
    # inline fspath() for better error messages
    w_fspath_method = space.lookup(w_value, '__fspath__')
    if w_fspath_method:
        w_result = space.get_and_call_function(w_fspath_method, w_value)
        if space.isinstance_w(w_result, space.w_unicode):
            return _path_from_unicode(space, w_result)
        elif space.isinstance_w(w_result, space.w_bytes):
            return _path_from_bytes(space, w_result)
        raise oefmt(space.w_TypeError,
                "expected %S.__fspath__() to return str or bytes, not %T",
                w_value, w_result)

        raise oefmt(space.w_TypeError,
            'expected %T.__fspath__() to return str or bytes, not %T',
            w_value,
            w_result
            )
    raise oefmt(
        space.w_TypeError, "path should be %s, not %T", allowed_types, w_value)

class _PathOrFd(Unwrapper):
    def unwrap(self, space, w_value):
        return _unwrap_path(space, w_value, allow_fd=True)

class _JustPath(Unwrapper):
    def unwrap(self, space, w_value):
        return _unwrap_path(space, w_value, allow_fd=False)

class _NullablePathOrFd(Unwrapper):
    def unwrap(self, space, w_value):
        return _unwrap_path(space, w_value, allow_fd=True, nullable=True)

class _NullablePath(Unwrapper):
    def unwrap(self, space, w_value):
        return _unwrap_path(space, w_value, allow_fd=False, nullable=True)


def path_or_fd(allow_fd=True, nullable=False):
    if nullable:
        return _NullablePathOrFd if allow_fd else _NullablePath
    else:
        return _PathOrFd if allow_fd else _JustPath

_HAVE_AT_FDCWD = getattr(rposix, 'AT_FDCWD', None) is not None
DEFAULT_DIR_FD = rposix.AT_FDCWD if _HAVE_AT_FDCWD else -100
DIR_FD_AVAILABLE = False

@specialize.arg(2)
def unwrap_fd(space, w_value, allowed_types='integer'):
    try:
        result = space.c_int_w(w_value)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise oefmt(space.w_TypeError,
                "argument should be %s, not %T", allowed_types, w_value)
        else:
            raise
    if result == -1:
        # -1 is used as sentinel value for not a fd
        raise oefmt(space.w_OSError, "invalid file descriptor: -1")
    return result

def _unwrap_dirfd(space, w_value):
    if space.is_none(w_value):
        return DEFAULT_DIR_FD
    else:
        return unwrap_fd(space, w_value, allowed_types="integer or None")

class _DirFD(Unwrapper):
    def unwrap(self, space, w_value):
        return _unwrap_dirfd(space, w_value)

class _DirFD_Unavailable(Unwrapper):
    def unwrap(self, space, w_value):
        dir_fd = _unwrap_dirfd(space, w_value)
        if dir_fd == DEFAULT_DIR_FD:
            return dir_fd
        raise oefmt(space.w_NotImplementedError,
                    "dir_fd unavailable on this platform")

def DirFD(available=False):
    return _DirFD if available else _DirFD_Unavailable

@specialize.arg(1, 2)
def argument_unavailable(space, funcname, arg):
    return oefmt(
            space.w_NotImplementedError,
            "%s: %s unavailable on this platform", funcname, arg)

_open_inhcache = rposix.SetNonInheritableCache()

def u2utf8(space, u_str):
    return space.newutf8(u_str.encode('utf-8'), len(u_str))

@unwrap_spec(flags=c_int, mode=c_int, dir_fd=DirFD(rposix.HAVE_OPENAT))
def open(space, w_path, flags, mode=0o777,
         __kwonly__=None, dir_fd=DEFAULT_DIR_FD):
    """open(path, flags, mode=0o777, *, dir_fd=None)

Open a file for low level IO.  Returns a file handle (integer).

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""

    if rposix.O_CLOEXEC is not None:
        flags |= rposix.O_CLOEXEC
    space.audit("open", [w_path, space.w_None, space.newint(flags)])
    while True:
        try:
            if rposix.HAVE_OPENAT and dir_fd != DEFAULT_DIR_FD:
                path = space.fsencode_w(w_path)
                fd = rposix.openat(path, flags, mode, dir_fd)
            else:
                fd = dispatch_filename(rposix.open)(space, w_path, flags, mode)
            break
        except OSError as e:
            wrap_oserror2(space, e, w_path, eintr_retry=True)
    try:
        _open_inhcache.set_non_inheritable(fd)
    except OSError as e:
        rposix.c_close(fd)
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)
    return space.newint(fd)

@unwrap_spec(fd=c_int, position=r_longlong, how=c_int)
def lseek(space, fd, position, how):
    """Set the current position of a file descriptor.  Return the new position.
If how == 0, 'position' is relative to the start of the file; if how == 1, to
the current position; if how == 2, to the end."""
    try:
        pos = os.lseek(fd, position, how)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        return space.newint(pos)

@unwrap_spec(fd=c_int)
def isatty(space, fd):
    """Return True if 'fd' is an open file descriptor connected to the
slave end of a terminal."""
    try:
        res = os.isatty(fd)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        return space.newbool(res)

@unwrap_spec(fd=c_int, length=int)
def read(space, fd, length):
    """Read data from a file descriptor."""
    while True:
        try:
            s = os.read(fd, length)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return space.newbytes(s)

@unwrap_spec(fd=c_int)
def write(space, fd, w_data):
    """Write a string to a file descriptor.  Return the number of bytes
actually written, which may be smaller than len(data)."""
    data = space.charbuf_w(w_data)
    while True:
        try:
            res = os.write(fd, data)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return space.newint(res)

@unwrap_spec(fd=c_int)
def close(space, fd):
    """Close a file descriptor (for low level IO)."""
    # PEP 475 note: os.close() must not retry upon EINTR.  Like in
    # previous versions of Python it raises OSError in this case.
    # The text of PEP 475 seems to suggest that EINTR is eaten and
    # hidden from app-level, but it is not the case in CPython 3.5.2.
    try:
        os.close(fd)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(fd_low=c_int, fd_high=c_int)
def closerange(fd_low, fd_high):
    """Closes all file descriptors in [fd_low, fd_high), ignoring errors."""
    rposix.closerange(fd_low, fd_high)

@unwrap_spec(fd=c_int, length=r_longlong)
def ftruncate(space, fd, length):
    """Truncate a file (by file descriptor) to a specified length."""
    while True:
        try:
            rposix.ftruncate(fd, length)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

def truncate(space, w_path, w_length):
    """Truncate a file to a specified length."""
    allocated_fd = False
    fd = -1
    try:
        if space.isinstance_w(w_path, space.w_int):
            w_fd = w_path
        else:
            w_fd = open(space, w_path, os.O_WRONLY)
            allocated_fd = True

        fd = space.c_filedescriptor_w(w_fd)
        length = space.int_w(w_length)
        return ftruncate(space, fd, length)

    finally:
        if allocated_fd and fd != -1:
            close(space, fd)

def fsync(space, w_fd):
    """Force write of file with filedescriptor to disk."""
    fd = space.c_filedescriptor_w(w_fd)
    while True:
        try:
            os.fsync(fd)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

def fdatasync(space, w_fd):
    """Force write of file with filedescriptor to disk.
Does not force update of metadata."""
    fd = space.c_filedescriptor_w(w_fd)
    while True:
        try:
            os.fdatasync(fd)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

def sync(space):
    """Force write of everything to disk."""
    rposix.sync()

def fchdir(space, w_fd):
    """Change to the directory of the given file descriptor.  fildes must be
opened on a directory, not a file."""
    fd = space.c_filedescriptor_w(w_fd)
    while True:
        try:
            os.fchdir(fd)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

@unwrap_spec(fd=c_int, length=int, offset=r_longlong)
def pread(space, fd, length, offset):
    """Read a string to a file descriptor at a given offset.
    """
    while True:
        try:
            s = rposix.pread(fd, length, offset)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
           return space.newbytes(s)

@unwrap_spec(fd=c_int, offset=r_longlong)
def pwrite(space, fd, w_data, offset):
    """Write a string to a file descriptor at a given offset.
    """
    data = space.charbuf_w(w_data)
    while True:
        try:
            res = rposix.pwrite(fd, data, offset)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return space.newint(res)

@unwrap_spec(fd=c_int, length=r_longlong, offset=r_longlong)
def posix_fallocate(space, fd, offset, length):
    """allocate file space .
    """
    while True:
        try:
            s = rposix.posix_fallocate(fd, offset, length)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
           return space.newint(s)

@unwrap_spec(fd=c_int, offset=r_longlong, length=r_longlong, advice=int)
def posix_fadvise(space, fd, offset, length, advice):
    """predeclare an access pattern for file data .
    """
    while True:
        try:
            rposix.posix_fadvise(fd, offset, length, advice)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return

# ____________________________________________________________

STAT_FIELDS = unrolling_iterable(enumerate(rposix_stat.STAT_FIELDS))

STATVFS_FIELDS = unrolling_iterable(enumerate(rposix_stat.STATVFS_FIELDS))

def build_stat_result(space, st):
    FIELDS = STAT_FIELDS    # also when not translating at all
    lst = [None] * rposix_stat.N_INDEXABLE_FIELDS
    w_keywords = space.newdict()
    stat_float_times = space.fromcache(StatState).stat_float_times
    for i, (name, TYPE) in FIELDS:
        if i < rposix_stat.N_INDEXABLE_FIELDS:
            # get the first 10 items by indexing; this gives us
            # 'st_Xtime' as an integer, too
            w_value = space.newint(st[i])
            lst[i] = w_value
        else:
            try:
                value = getattr(st, name)
            except AttributeError:
                # untranslated, there is no nsec_Xtime attribute
                assert name.startswith('nsec_')
                value = rposix_stat.get_stat_ns_as_bigint(st, name[5:])
                value = value.tolong() % 1000000000
            w_value = space.newint(value)
            space.setitem(w_keywords, space.newtext(name), w_value)

    # Note: 'w_keywords' contains the three attributes 'nsec_Xtime'.
    # We have an app-level property in app_posix.stat_result to
    # compute the full 'st_Xtime_ns' value.

    # non-rounded values for name-based access
    if stat_float_times:
        space.setitem(w_keywords,
                      space.newtext('st_atime'), space.newfloat(st.st_atime))
        space.setitem(w_keywords,
                      space.newtext('st_mtime'), space.newfloat(st.st_mtime))
        space.setitem(w_keywords,
                      space.newtext('st_ctime'), space.newfloat(st.st_ctime))
    #else:
    #   filled by the __init__ method

    w_tuple = space.newtuple(lst)
    w_stat_result = space.getattr(space.getbuiltinmodule(os.name),
                                  space.newtext('stat_result'))
    return space.call_function(w_stat_result, w_tuple, w_keywords)


def build_statvfs_result(space, st):
    vals_w = [None] * len(rposix_stat.STATVFS_FIELDS)
    for i, (name, _) in STATVFS_FIELDS:
        vals_w[i] = space.newint(getattr(st, name))
    w_tuple = space.newtuple(vals_w)
    w_statvfs_result = space.getattr(
        space.getbuiltinmodule(os.name), space.newtext('statvfs_result'))
    return space.call_function(w_statvfs_result, w_tuple)


@unwrap_spec(fd=c_int)
def fstat(space, fd):
    """Perform a stat system call on the file referenced to by an open
file descriptor."""
    while True:
        try:
            st = rposix_stat.fstat(fd)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return build_stat_result(space, st)

@unwrap_spec(
    path=path_or_fd(allow_fd=True),
    dir_fd=DirFD(rposix.HAVE_FSTATAT),
    follow_symlinks=bool)
def stat(space, path, __kwonly__, dir_fd=DEFAULT_DIR_FD, follow_symlinks=True):
    """stat(path, *, dir_fd=None, follow_symlinks=True) -> stat result

Perform a stat system call on the given path.

path may be specified as either a string or as an open file descriptor.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
  dir_fd may not be supported on your platform; if it is unavailable, using
  it will raise a NotImplementedError.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, stat will examine the symbolic link itself instead of the file the
  link points to.
It is an error to use dir_fd or follow_symlinks when specifying path as
  an open file descriptor."""
    return do_stat(space, "stat", path, dir_fd, follow_symlinks)

@specialize.arg(1)
def do_stat(space, funcname, path, dir_fd, follow_symlinks):
    """Common implementation for stat() and lstat()"""
    try:
        if path.as_fd != -1:
            if dir_fd != DEFAULT_DIR_FD:
                raise oefmt(space.w_ValueError,
                    "%s: can't specify both dir_fd and fd", funcname)
            if not follow_symlinks:
                raise oefmt(space.w_ValueError,
                    "%s: cannot use fd and follow_symlinks together", funcname)
            st = rposix_stat.fstat(path.as_fd)
        elif follow_symlinks and dir_fd == DEFAULT_DIR_FD:
            st = call_rposix(rposix_stat.stat3, path)
        elif not follow_symlinks and dir_fd == DEFAULT_DIR_FD:
            st = call_rposix(rposix_stat.lstat3, path)
        elif rposix.HAVE_FSTATAT:
            st = call_rposix(rposix_stat.fstatat, path, dir_fd, follow_symlinks)
        else:
            raise oefmt(space.w_NotImplementedError,
                "%s: unsupported argument combination", funcname)
    except OSError as e:
        raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)
    else:
        return build_stat_result(space, st)

@unwrap_spec(
    path=path_or_fd(allow_fd=False),
    dir_fd=DirFD(rposix.HAVE_FSTATAT))
def lstat(space, path, __kwonly__, dir_fd=DEFAULT_DIR_FD):
    """lstat(path, *, dir_fd=None) -> stat result

Like stat(), but do not follow symbolic links.
Equivalent to stat(path, follow_symlinks=False)."""
    return do_stat(space, "lstat", path, dir_fd, False)

class StatState(object):
    def __init__(self, space):
        self.stat_float_times = True

@unwrap_spec(newval=int)
def stat_float_times(space, newval=-1):
    """stat_float_times([newval]) -> oldval

Determine whether os.[lf]stat represents time stamps as float objects.
If newval is True, future calls to stat() return floats, if it is False,
future calls return ints.
If newval is omitted, return the current setting.
"""
    space.warn(space.newtext("stat_float_times() is deprecated"),
               space.w_DeprecationWarning)
    state = space.fromcache(StatState)

    if newval == -1:
        return space.newbool(state.stat_float_times)
    else:
        state.stat_float_times = (newval != 0)


@unwrap_spec(fd=c_int)
def fstatvfs(space, fd):
    while True:
        try:
            st = rposix_stat.fstatvfs(fd)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return build_statvfs_result(space, st)


def statvfs(space, w_path):
    """statvfs(path)

Perform a statvfs system call on the given path.

path may always be specified as a string.
On some platforms, path may also be specified as an open file descriptor.
  If this functionality is unavailable, using it raises an exception."""
    try:
        st = dispatch_filename(
            rposix_stat.statvfs,
            allow_fd_fn=rposix_stat.fstatvfs)(space, w_path)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)
    else:
        return build_statvfs_result(space, st)


@unwrap_spec(fd=c_int)
def dup(space, fd):
    """Create a copy of the file descriptor.  Return the new file
descriptor."""
    try:
        newfd = rposix.dup(fd, inheritable=False)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        return space.newint(newfd)

@unwrap_spec(fd=c_int, fd2=c_int, inheritable=bool)
def dup2(space, fd, fd2, inheritable=1):
    """Duplicate a file descriptor."""
    # like os.close(), this can still raise EINTR to app-level in
    # CPython 3.5.2
    try:
        rposix.dup2(fd, fd2, inheritable)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(fd2)

@unwrap_spec(mode=c_int,
    dir_fd=DirFD(rposix.HAVE_FACCESSAT), effective_ids=bool,
    follow_symlinks=bool)
def access(space, w_path, mode, __kwonly__,
        dir_fd=DEFAULT_DIR_FD, effective_ids=False, follow_symlinks=True):
    """\
access(path, mode, *, dir_fd=None, effective_ids=False, follow_symlinks=True)

Use the real uid/gid to test for access to a path.  Returns True if granted,
False otherwise.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
If effective_ids is True, access will use the effective uid/gid instead of
  the real uid/gid.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, access will examine the symbolic link itself instead of the file the
  link points to.
dir_fd, effective_ids, and follow_symlinks may not be implemented
  on your platform.  If they are unavailable, using them will raise a
  NotImplementedError.

Note that most operations will use the effective uid/gid, therefore this
  routine can be used in a suid/sgid environment to test if the invoking user
  has the specified access to the path.
The mode argument can be F_OK to test existence, or the inclusive-OR
  of R_OK, W_OK, and X_OK."""
    if not rposix.HAVE_FACCESSAT:
        if not follow_symlinks:
            raise argument_unavailable(space, "access", "follow_symlinks")
        if effective_ids:
            raise argument_unavailable(space, "access", "effective_ids")

    try:
        if (rposix.HAVE_FACCESSAT and
            (dir_fd != DEFAULT_DIR_FD or not follow_symlinks or
             effective_ids)):
            path = space.fsencode_w(w_path)
            ok = rposix.faccessat(path, mode,
                dir_fd, effective_ids, follow_symlinks)
        else:
            ok = dispatch_filename(rposix.access)(space, w_path, mode)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)
    else:
        return space.newbool(ok)


def times(space):
    """
    times() -> (utime, stime, cutime, cstime, elapsed_time)

    Return a tuple of floating point numbers indicating process times.
    """
    try:
        times = os.times()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        w_keywords = space.newdict()
        w_tuple = space.newtuple([space.newfloat(times[0]),
                                  space.newfloat(times[1]),
                                  space.newfloat(times[2]),
                                  space.newfloat(times[3]),
                                  space.newfloat(times[4])])

        w_times_result = space.getattr(space.getbuiltinmodule(os.name),
                                       space.newtext('times_result'))
        return space.call_function(w_times_result, w_tuple, w_keywords)


@unwrap_spec(command='fsencode')
def system(space, command):
    """Execute the command (a string) in a subshell."""
    try:
        rc = os.system(command)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        return space.newint(rc)

@unwrap_spec(path=path_or_fd(allow_fd=False),
             dir_fd=DirFD(rposix.HAVE_UNLINKAT))
def unlink(space, path, __kwonly__, dir_fd=DEFAULT_DIR_FD):
    """unlink(path, *, dir_fd=None)

Remove a file (same as remove()).

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    try:
        if rposix.HAVE_UNLINKAT and dir_fd != DEFAULT_DIR_FD:
            rposix.unlinkat(space.fsencode_w(path.w_path),
                            dir_fd, removedir=False)
        else:
            call_rposix(rposix.unlink, path)
    except OSError as e:
        raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)

@unwrap_spec(path=path_or_fd(allow_fd=False),
             dir_fd=DirFD(rposix.HAVE_UNLINKAT))
def remove(space, path, __kwonly__, dir_fd=DEFAULT_DIR_FD):
    """remove(path, *, dir_fd=None)

Remove a file (same as unlink()).

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    try:
        if rposix.HAVE_UNLINKAT and dir_fd != DEFAULT_DIR_FD:
            rposix.unlinkat(space.fsencode_w(path.w_path),
                            dir_fd, removedir=False)
        else:
            call_rposix(rposix.unlink, path)
    except OSError as e:
        raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)

if _WIN32:
    @unwrap_spec(path=path_or_fd(allow_fd=False, nullable=False))
    def _getfullpathname(space, path):
        """helper for ntpath.abspath """
        try:
            if path.as_unicode is not None:
                result = rposix.getfullpathname(path.as_unicode)
                return u2utf8(space, result)
            else:
                result = rposix.getfullpathname(path.as_bytes)
                return space.newbytes(result)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)


def getcwdb(space):
    """Return the current working directory."""
    try:
        cur = os.getcwd()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    else:
        return space.newbytes(cur)

if _WIN32:
    def getcwd(space):
        """Return the current working directory as a string."""
        try:
            cur = os.getcwdu()
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
        else:
            return u2utf8(space, cur)
else:
    def getcwd(space):
        """Return the current working directory as a string."""
        return space.fsdecode(getcwdb(space))

def chdir(space, w_path):
    """Change the current working directory to the specified path."""
    try:
        if rposix.HAVE_FCHDIR:
            dispatch_filename(rposix.chdir,
                              allow_fd_fn=os.fchdir)(space, w_path)
        else:
            dispatch_filename(rposix.chdir)(space, w_path)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)

@unwrap_spec(mode=c_int, dir_fd=DirFD(rposix.HAVE_MKDIRAT))
def mkdir(space, w_path, mode=0o777, __kwonly__=None, dir_fd=DEFAULT_DIR_FD):
    """mkdir(path, mode=0o777, *, dir_fd=None)

Create a directory.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError.

The mode argument is ignored on Windows."""
    try:
        if rposix.HAVE_MKDIRAT and dir_fd != DEFAULT_DIR_FD:
            path = space.fsencode_w(w_path)
            rposix.mkdirat(path, mode, dir_fd)
        else:
            dispatch_filename(rposix.mkdir)(space, w_path, mode)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)

@unwrap_spec(dir_fd=DirFD(rposix.HAVE_UNLINKAT))
def rmdir(space, w_path, __kwonly__, dir_fd=DEFAULT_DIR_FD):
    """rmdir(path, *, dir_fd=None)

Remove a directory.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    try:
        if rposix.HAVE_UNLINKAT and dir_fd != DEFAULT_DIR_FD:
            path = space.fsencode_w(w_path)
            rposix.unlinkat(path, dir_fd, removedir=True)
        else:
            dispatch_filename(rposix.rmdir)(space, w_path)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)

@unwrap_spec(code=c_int)
def strerror(space, code):
    """Translate an error code to a message string."""
    try:
        # _strerror returns utf8, lgt
        return space.newtext(*_strerror(code))
    except ValueError:
        raise oefmt(space.w_ValueError, "strerror() argument out of range")

def getlogin(space):
    """Return the currently logged in user."""
    try:
        cur = os.getlogin()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newfilename(cur)

# ____________________________________________________________

def getstatfields(space):
    # for app_posix.py: export the list of 'st_xxx' names that we know
    # about at RPython level
    return space.newlist([space.newtext(name) for _, (name, _) in STAT_FIELDS])


class State:
    def __init__(self, space):
        self.space = space
        self.w_environ = space.newdict()
        self.random_context = rurandom.init_urandom()

    def startup(self, space):
        space.call_method(self.w_environ, 'clear')
        _convertenviron(space, self.w_environ)

    def _freeze_(self):
        # don't capture the environment in the translated pypy
        self.space.call_method(self.w_environ, 'clear')
        # also reset random_context to a fresh new context (empty so far,
        # to be filled at run-time by rurandom.urandom())
        self.random_context = rurandom.init_urandom()
        return True

def get(space):
    return space.fromcache(State)

if _WIN32:
    def _convertenviron(space, w_env):
        # _wenviron must be initialized in this way if the program is
        # started through main() instead of wmain()
        rwin32._wgetenv(u"")
        for key, value in rwin32._wenviron_items():
            space.setitem(w_env, space.newtext(key.encode("utf-8"), len(key)),
                    space.newtext(value.encode("utf-8"), len(value)))

    @unwrap_spec(name=unicode, value=unicode)
    def putenv(space, name, value):
        """Change or add an environment variable."""
        # Search from index 1 because on Windows starting '=' is allowed for
        # defining hidden environment variables.
        if len(name) == 0 or u'=' in name[1:]:
            raise oefmt(space.w_ValueError, "illegal environment variable name")

        # len includes space for '=' and a trailing NUL
        if len(name) + len(value) + 2 > rwin32._MAX_ENV:
            raise oefmt(space.w_ValueError,
                        "the environment variable is longer than %d "
                        "characters", rwin32._MAX_ENV)

        if u'\x00' in name or u'\x00' in value:
            raise oefmt(space.w_ValueError, "embedded null character")

        try:
            rwin32._wputenv(name, value)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)

    @unwrap_spec(name=unicode)
    def unsetenv(space, name):
        """Change or add an environment variable."""
        # Search from index 1 because on Windows starting '=' is allowed for
        # defining hidden environment variables.
        if len(name) == 0 or u'=' in name[1:]:
            raise oefmt(space.w_ValueError, "illegal environment variable name")

        # len includes space for '=' and a trailing NUL
        if len(name) + 1 > rwin32._MAX_ENV:
            raise oefmt(space.w_ValueError,
                        "the environment variable is longer than %d "
                        "characters", rwin32._MAX_ENV)

        try:
            rwin32.SetEnvironmentVariableW(name, None)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)

else:
    def _convertenviron(space, w_env):
        for key, value in os.environ.items():
            space.setitem(w_env, space.newbytes(key), space.newbytes(value))

    def putenv(space, w_name, w_value):
        """Change or add an environment variable."""
        try:
            dispatch_filename_2(putenv_impl)(space, w_name, w_value)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
        except ValueError:
            raise oefmt(space.w_ValueError,
                    "illegal environment variable name")

    @specialize.argtype(0, 1)
    def putenv_impl(name, value):
        from rpython.rlib.rposix import _as_bytes
        name = _as_bytes(name)
        value = _as_bytes(value)
        if len(name) == 0 or "=" in name:
            raise ValueError
        return rposix.putenv(name, value)

    def unsetenv(space, w_name):
        """Delete an environment variable."""
        try:
            dispatch_filename(rposix.unsetenv)(space, w_name)
        except KeyError:
            pass
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)


@unwrap_spec(path=path_or_fd(allow_fd=rposix.HAVE_FDOPENDIR, nullable=True))
def listdir(space, path=None):
    """\
Return a list containing the names of the files in the directory.

path can be specified as either str, bytes, or a path-like object.  If path is bytes,
  the filenames returned will also be bytes; in all other circumstances
  the filenames returned will be str.
If path is None, uses the path='.'.
On some platforms, path may also be specified as an open file descriptor;\
  the file descriptor must refer to a directory.
  If this functionality is unavailable, using it raises NotImplementedError.

The list is in arbitrary order.  It does not include the special
entries '.' and '..' even if they are present in the directory."""

    try:
        space._try_buffer_w(path.w_path, space.BUF_FULL_RO)
    except BufferInterfaceNotFound:
        as_bytes = False
    else:
        as_bytes = True
    if path.as_fd != -1:
        if not rposix.HAVE_FDOPENDIR:
            # needed for translation, in practice this is dead code
            raise oefmt(space.w_TypeError,
                "listdir: illegal type for path argument")
        try:
            result = rposix.fdlistdir(rposix.dup(path.as_fd, inheritable=False))
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
        return space.newlist([space.newfilename(f) for f in result])
    elif as_bytes:
        try:
            result = rposix.listdir(path.as_bytes)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)
        return space.newlist_bytes(result)
    else:
        # The annotator needs result_u and result to be different
        u = path.as_unicode
        result_u = []
        result = []
        try:
            if u:
                result_u = rposix.listdir(path.as_unicode)
            elif path.as_bytes:
                result = rposix.listdir(path.as_bytes)
            else:
                # rposix.listdir will raise the error, but None is invalid here
                result = rposix.listdir('')
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)
        if u:
            len_result = len(result_u)
            result_w = [None] * len_result
            for i in range(len_result):
                result_w[i] = result_u[i].encode('utf-8')
            return space.newlist_text(result_w)
        elif _WIN32:
            return space.newlist_utf8(result, True)
        # only non-_WIN32
        len_result = len(result)
        result_w = [None] * len_result
        for i in range(len_result):
            result_w[i] = space.newfilename(result[i])
        return space.newlist(result_w)

@unwrap_spec(fd=c_int)
def get_inheritable(space, fd):
    try:
        return space.newbool(rposix.get_inheritable(fd))
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(fd=c_int, inheritable=int)
def set_inheritable(space, fd, inheritable):
    try:
        rposix.set_inheritable(fd, inheritable)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

_pipe_inhcache = rposix.SetNonInheritableCache()

def pipe(space):
    "Create a pipe.  Returns (read_end, write_end)."
    try:
        fd1, fd2 = rposix.pipe(rposix.O_CLOEXEC or 0)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    try:
        _pipe_inhcache.set_non_inheritable(fd1)
        _pipe_inhcache.set_non_inheritable(fd2)
    except OSError as e:
        rposix.c_close(fd2)
        rposix.c_close(fd1)
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtuple([space.newint(fd1), space.newint(fd2)])

@unwrap_spec(flags=c_int)
def pipe2(space, flags):
    try:
        fd1, fd2 = rposix.pipe2(flags)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtuple([space.newint(fd1), space.newint(fd2)])

@unwrap_spec(mode=c_int, dir_fd=DirFD(rposix.HAVE_FCHMODAT),
             follow_symlinks=bool)
def chmod(space, w_path, mode, __kwonly__,
          dir_fd=DEFAULT_DIR_FD, follow_symlinks=True):
    """chmod(path, mode, *, dir_fd=None, follow_symlinks=True)

Change the access permissions of a file.

path may always be specified as a string.
On some platforms, path may also be specified as an open file descriptor.
  If this functionality is unavailable, using it raises an exception.
If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, chmod will modify the symbolic link itself instead of the file the
  link points to.
It is an error to use dir_fd or follow_symlinks when specifying path as
  an open file descriptor.
dir_fd and follow_symlinks may not be implemented on your platform.
  If they are unavailable, using them will raise a NotImplementedError."""
    if not rposix.HAVE_FCHMODAT:
        if not follow_symlinks:
            raise argument_unavailable(space, "chmod", "follow_symlinks")
        while True:
            try:
                dispatch_filename(rposix.chmod)(space, w_path, mode)
                return
            except OSError as e:
                wrap_oserror2(space, e, w_path, eintr_retry=True)

    try:
        path = space.fsencode_w(w_path)
    except OperationError as operr:
        if not space.isinstance_w(w_path, space.w_int):
            raise oefmt(space.w_TypeError,
                "argument should be string, bytes or integer, not %T", w_path)
        fd = unwrap_fd(space, w_path)
        # NB. in CPython 3.5.2, os.chmod(fd) propagates EINTR to app-level,
        # but os.fchmod(fd) retries automatically.  This might be fixed in
        # more recent CPythons.
        while True:
            try:
                os.fchmod(fd, mode)
                return
            except OSError as e:
                wrap_oserror(space, e, eintr_retry=True)
    while True:
        try:
            _chmod_path(path, mode, dir_fd, follow_symlinks)
            break
        except OSError as e:
            if not follow_symlinks and e.errno in (ENOTSUP, EOPNOTSUPP):
                # fchmodat() doesn't actually implement follow_symlinks=False
                # so raise NotImplementedError in this case
                raise argument_unavailable(space, "chmod", "follow_symlinks")
            wrap_oserror2(space, e, w_path, eintr_retry=True)

def _chmod_path(path, mode, dir_fd, follow_symlinks):
    if dir_fd != DEFAULT_DIR_FD or not follow_symlinks:
        rposix.fchmodat(path, mode, dir_fd, follow_symlinks)
    else:
        rposix.chmod(path, mode)

@unwrap_spec(fd=c_int, mode=c_int)
def fchmod(space, fd, mode):
    """\
    Change the access permissions of the file given by file descriptor fd.
    """
    while True:
        try:
            os.fchmod(fd, mode)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

@unwrap_spec(src_dir_fd=DirFD(rposix.HAVE_RENAMEAT),
             dst_dir_fd=DirFD(rposix.HAVE_RENAMEAT))
def rename(space, w_src, w_dst, __kwonly__,
           src_dir_fd=DEFAULT_DIR_FD, dst_dir_fd=DEFAULT_DIR_FD):
    """rename(src, dst, *, src_dir_fd=None, dst_dir_fd=None)

Rename a file or directory.

If either src_dir_fd or dst_dir_fd is not None, it should be a file
  descriptor open to a directory, and the respective path string (src or dst)
  should be relative; the path will then be relative to that directory.
src_dir_fd and dst_dir_fd, may not be implemented on your platform.
  If they are unavailable, using them will raise a NotImplementedError."""
    try:
        if (rposix.HAVE_RENAMEAT and
            (src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD)):
            src = space.fsencode_w(w_src)
            dst = space.fsencode_w(w_dst)
            rposix.renameat(src, dst, src_dir_fd, dst_dir_fd)
        else:
            dispatch_filename_2(rposix.rename)(space, w_src, w_dst)
    except OSError as e:
        raise wrap_oserror2(space, e, w_filename=w_src, w_filename2=w_dst,
                            eintr_retry=False)

@unwrap_spec(src_dir_fd=DirFD(rposix.HAVE_RENAMEAT),
        dst_dir_fd=DirFD(rposix.HAVE_RENAMEAT))
def replace(space, w_src, w_dst, __kwonly__,
        src_dir_fd=DEFAULT_DIR_FD, dst_dir_fd=DEFAULT_DIR_FD):
    """replace(src, dst, *, src_dir_fd=None, dst_dir_fd=None)

Rename a file or directory, overwriting the destination.

If either src_dir_fd or dst_dir_fd is not None, it should be a file
  descriptor open to a directory, and the respective path string (src or dst)
  should be relative; the path will then be relative to that directory.
src_dir_fd and dst_dir_fd, may not be implemented on your platform.
  If they are unavailable, using them will raise a NotImplementedError."""
    try:
        if (rposix.HAVE_RENAMEAT and
            (src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD)):
            src = space.fsencode_w(w_src)
            dst = space.fsencode_w(w_dst)
            rposix.renameat(src, dst, src_dir_fd, dst_dir_fd)
        else:
            dispatch_filename_2(rposix.replace)(space, w_src, w_dst)
    except OSError as e:
        raise wrap_oserror2(space, e, w_filename=w_src, w_filename2=w_dst,
                            eintr_retry=False)

@unwrap_spec(mode=c_int, dir_fd=DirFD(rposix.HAVE_MKFIFOAT))
def mkfifo(space, w_path, mode=0o666, __kwonly__=None, dir_fd=DEFAULT_DIR_FD):
    """mkfifo(path, mode=0o666, *, dir_fd=None)

Create a FIFO (a POSIX named pipe).

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    # CPython 3.5.2: why does os.mkfifo() retry automatically if it
    # gets EINTR, but not os.mkdir()?
    while True:
        try:
            if rposix.HAVE_MKFIFOAT and dir_fd != DEFAULT_DIR_FD:
                path = space.fsencode_w(w_path)
                rposix.mkfifoat(path, mode, dir_fd)
            else:
                dispatch_filename(rposix.mkfifo)(space, w_path, mode)
            break
        except OSError as e:
            wrap_oserror2(space, e, w_path, eintr_retry=True)

@unwrap_spec(mode=c_int, device=c_int, dir_fd=DirFD(rposix.HAVE_MKNODAT))
def mknod(space, w_path, mode=0600, device=0,
          __kwonly__=None, dir_fd=DEFAULT_DIR_FD):
    """mknod(path, mode=0o600, device=0, *, dir_fd=None)

Create a filesystem node (file, device special file or named pipe)
named 'path'. mode specifies both the permissions to use and the
type of node to be created, being combined (bitwise OR) with one of
S_IFREG, S_IFCHR, S_IFBLK, and S_IFIFO. For S_IFCHR and S_IFBLK,
device defines the newly created device special file (probably using
os.makedev()), otherwise it is ignored.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    while True:
        try:
            if rposix.HAVE_MKNODAT and dir_fd != DEFAULT_DIR_FD:
                fname = space.fsencode_w(w_path)
                rposix.mknodat(fname, mode, device, dir_fd)
            else:
                dispatch_filename(rposix.mknod)(space, w_path, mode, device)
            break
        except OSError as e:
            wrap_oserror2(space, e, w_path, eintr_retry=True)

@unwrap_spec(mask=c_int)
def umask(space, mask):
    "Set the current numeric umask and return the previous umask."
    prevmask = os.umask(mask)
    return space.newint(prevmask)

def getpid(space):
    "Return the current process id."
    try:
        pid = os.getpid()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(pid)

@unwrap_spec(pid=c_int, signal=c_int)
def kill(space, pid, signal):
    "Kill a process with a signal."
    try:
        rposix.kill(pid, signal)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(pgid=c_int, signal=c_int)
def killpg(space, pgid, signal):
    "Kill a process group with a signal."
    try:
        os.killpg(pgid, signal)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

def abort(space):
    """Abort the interpreter immediately.  This 'dumps core' or otherwise fails
in the hardest way possible on the hosting operating system."""
    import signal
    rposix.kill(os.getpid(), signal.SIGABRT)

@unwrap_spec(
    src_dir_fd=DirFD(rposix.HAVE_LINKAT), dst_dir_fd=DirFD(rposix.HAVE_LINKAT),
    follow_symlinks=bool)
def link(space, w_src, w_dst, __kwonly__,
        src_dir_fd=DEFAULT_DIR_FD, dst_dir_fd=DEFAULT_DIR_FD,
        follow_symlinks=True):
    """\
link(src, dst, *, src_dir_fd=None, dst_dir_fd=None, follow_symlinks=True)

Create a hard link to a file.

If either src_dir_fd or dst_dir_fd is not None, it should be a file
  descriptor open to a directory, and the respective path string (src or dst)
  should be relative; the path will then be relative to that directory.
If follow_symlinks is False, and the last element of src is a symbolic
  link, link will create a link to the symbolic link itself instead of the
  file the link points to.
src_dir_fd, dst_dir_fd, and follow_symlinks may not be implemented on your
  platform.  If they are unavailable, using them will raise a
  NotImplementedError."""
    src = space.fsencode_w(w_src)
    dst = space.fsencode_w(w_dst)
    try:
        if (rposix.HAVE_LINKAT and
            (src_dir_fd != DEFAULT_DIR_FD or dst_dir_fd != DEFAULT_DIR_FD
             or not follow_symlinks)):
            rposix.linkat(src, dst, src_dir_fd, dst_dir_fd, follow_symlinks)
        else:
            rposix.link(src, dst)
    except OSError as e:
        raise wrap_oserror2(space, e, w_filename=w_src, w_filename2=w_dst,
                            eintr_retry=False)


@unwrap_spec(dir_fd=DirFD(rposix.HAVE_SYMLINKAT))
def symlink(space, w_src, w_dst, w_target_is_directory=None,
            __kwonly__=None, dir_fd=DEFAULT_DIR_FD):
    """symlink(src, dst, target_is_directory=False, *, dir_fd=None)

Create a symbolic link pointing to src named dst.

target_is_directory is required on Windows if the target is to be
  interpreted as a directory.  (On Windows, symlink requires
  Windows 6.0 or greater, and raises a NotImplementedError otherwise.)
  target_is_directory is ignored on non-Windows platforms.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    if _WIN32:
        raise oefmt(space.w_NotImplementedError,
                    "symlink() is not implemented for PyPy on Windows")
    try:
        if rposix.HAVE_SYMLINKAT and dir_fd != DEFAULT_DIR_FD:
            src = space.fsencode_w(w_src)
            dst = space.fsencode_w(w_dst)
            rposix.symlinkat(src, dst, dir_fd)
        else:
            dispatch_filename_2(rposix.symlink)(space, w_src, w_dst)
    except OSError as e:
        raise wrap_oserror2(space, e, w_filename=w_src, w_filename2=w_dst,
                            eintr_retry=False)


@unwrap_spec(
    path=path_or_fd(allow_fd=False),
    dir_fd=DirFD(rposix.HAVE_READLINKAT))
def readlink(space, path, __kwonly__, dir_fd=DEFAULT_DIR_FD):
    """readlink(path, *, dir_fd=None) -> path

Return a string representing the path to which the symbolic link points.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
dir_fd may not be implemented on your platform.
  If it is unavailable, using it will raise a NotImplementedError."""
    try:
        if rposix.HAVE_READLINKAT and dir_fd != DEFAULT_DIR_FD:
            result = call_rposix(rposix.readlinkat, path, dir_fd)
        else:
            result = call_rposix(rposix.readlink, path)
    except OSError as e:
        raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)
    w_result = space.newbytes(result)
    if space.isinstance_w(path.w_path, space.w_unicode):
        return space.fsdecode(w_result)
    return w_result

before_fork_hooks = []
after_fork_child_hooks = []
after_fork_parent_hooks = []

@specialize.memo()
def get_fork_hooks(where):
    if where == 'before':
        return before_fork_hooks
    elif where == 'child':
        return after_fork_child_hooks
    elif where == 'parent':
        return after_fork_parent_hooks
    else:
        assert False, "Unknown fork hook"

@not_rpython
def add_fork_hook(where, hook):
    get_fork_hooks(where).append(hook)

add_fork_hook('child', ExecutionContext._mark_thread_disappeared)

@specialize.arg(0)
def run_fork_hooks(where, space):
    for hook in get_fork_hooks(where):
        hook(space)

def _run_forking_function(space, kind):
    run_fork_hooks('before', space)
    try:
        if kind == "F":
            pid = os.fork()
            master_fd = -1
        elif kind == "P":
            pid, master_fd = os.forkpty()
        else:
            raise AssertionError
    except OSError as e:
        try:
            run_fork_hooks('parent', space)
        except:
            # Don't clobber the OSError if the fork failed
            pass
        raise wrap_oserror(space, e, eintr_retry=False)
    if pid == 0:
        run_fork_hooks('child', space)
    else:
        run_fork_hooks('parent', space)
    return pid, master_fd

def fork(space):
    pid, irrelevant = _run_forking_function(space, "F")
    return space.newint(pid)

class ApplevelForkCallbacks(object):
    def __init__(self, space):
        self.space = space
        self.before_w = []
        self.parent_w = []
        self.child_w = []

def register_at_fork(space, __args__):
    """
    register_at_fork(*, [before], [after_in_child], [after_in_parent])
    Register callables to be called when forking a new process.

      before
        A callable to be called in the parent before the fork() syscall.
      after_in_child
        A callable to be called in the child after fork().
      after_in_parent
        A callable to be called in the parent after fork().

    'before' callbacks are called in reverse order.
    'after_in_child' and 'after_in_parent' callbacks are called in order.
    """
    # annoying, can't express argument parsing of this nicely
    # because cpython explicitly wants
    # os.register_at_fork(before=None, after_in_parent=<callable>)
    # to fail, and we can't use unwrapped None as a kwonly default
    args_w, kwargs_w = __args__.unpack()
    if args_w:
        raise oefmt(space.w_TypeError,
            "register_at_fork() takes no positional arguments")
    w_before = kwargs_w.pop("before", None)
    w_after_in_parent = kwargs_w.pop("after_in_parent", None)
    w_after_in_child = kwargs_w.pop("after_in_child", None)
    if kwargs_w:
        for key in kwargs_w:
            raise oefmt(space.w_TypeError,
                "%s is an invalid keyword argument for register_at_fork()", key)

    registered = False
    cbs = space.fromcache(ApplevelForkCallbacks)
    if w_before is not None:
        if not space.callable_w(w_before):
            raise oefmt(space.w_TypeError,
                    "'before' must be callable, not %T",
                    w_before)
        cbs.before_w.append(w_before)
        registered = True
    if w_after_in_parent is not None:
        if not space.callable_w(w_after_in_parent):
            raise oefmt(space.w_TypeError,
                    "'after_in_parent' must be callable, not %T",
                    w_after_in_parent)
        cbs.parent_w.append(w_after_in_parent)
        registered = True
    if w_after_in_child is not None:
        if not space.callable_w(w_after_in_child):
            raise oefmt(space.w_TypeError,
                    "'after_in_child' must be callable, not %T",
                    w_after_in_child)
        cbs.child_w.append(w_after_in_child)
        registered = True
    if not registered:
        raise oefmt(space.w_TypeError,
            "At least one argument is required.")


def _run_applevel_hook(space, w_callable):
    try:
        space.call_function(w_callable)
    except OperationError as e:
        e.write_unraisable(space, "fork hook")

def run_applevel_fork_hooks(space, l_w, reverse=False):
    if len(l_w) == 0:
        return
    if not reverse:
        for i in range(len(l_w)): # callable can append to the list
            _run_applevel_hook(space, l_w[i])
    else:
        for i in range(len(l_w) - 1, -1, -1):
            _run_applevel_hook(space, l_w[i])

def run_applevel_fork_hooks_before(space):
    cbs = space.fromcache(ApplevelForkCallbacks)
    run_applevel_fork_hooks(space, cbs.before_w, reverse=True)

def run_applevel_fork_hooks_parent(space):
    cbs = space.fromcache(ApplevelForkCallbacks)
    run_applevel_fork_hooks(space, cbs.parent_w)

def run_applevel_fork_hooks_child(space):
    cbs = space.fromcache(ApplevelForkCallbacks)
    run_applevel_fork_hooks(space, cbs.child_w)

add_fork_hook('before', run_applevel_fork_hooks_before)
add_fork_hook('parent', run_applevel_fork_hooks_parent)
add_fork_hook('child', run_applevel_fork_hooks_child)


def openpty(space):
    "Open a pseudo-terminal, returning open fd's for both master and slave end."
    master_fd = slave_fd = -1
    try:
        master_fd, slave_fd = os.openpty()
        rposix.set_inheritable(master_fd, False)
        rposix.set_inheritable(slave_fd, False)
    except OSError as e:
        if master_fd >= 0:
            rposix.c_close(master_fd)
        if slave_fd >= 0:
            rposix.c_close(slave_fd)
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtuple([space.newint(master_fd), space.newint(slave_fd)])

def forkpty(space):
    pid, master_fd = _run_forking_function(space, "P")
    return space.newtuple([space.newint(pid),
                           space.newint(master_fd)])

@unwrap_spec(pid=c_int, options=c_int)
def waitpid(space, pid, options):
    """ waitpid(pid, options) -> (pid, status)

    Wait for completion of a given child process.
    """
    while True:
        try:
            pid, status = os.waitpid(pid, options)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
    return space.newtuple([space.newint(pid), space.newint(status)])

# missing: waitid()

@unwrap_spec(status=c_int)
def _exit(space, status):
    os._exit(status)

def execv(space, w_path, w_argv):
    """ execv(path, args)

Execute an executable path with arguments, replacing current process.

        path: path of executable file
        args: iterable of strings
    """
    command = space.fsencode_w(w_path)
    try:
        args_w = space.unpackiterable(w_argv)
        if len(args_w) < 1:
            raise oefmt(space.w_ValueError,
                "execv() arg 2 must not be empty")
        args = [space.fsencode_w(w_arg) for w_arg in args_w]
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
        raise oefmt(space.w_TypeError,
            "execv() arg 2 must be an iterable of strings")
    if not args[0]:
        raise oefmt(space.w_ValueError,
            "execv() arg 2 first element cannot be empty")
    try:
        os.execv(command, args)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)


def _env2interp(space, w_env):
    env = {}
    w_keys = space.call_method(w_env, 'keys')
    for w_key in space.unpackiterable(w_keys):
        w_value = space.getitem(w_env, w_key)
        key = space.fsencode_w(w_key)
        val = space.fsencode_w(w_value)
        # Search from index 1 because on Windows starting '=' is allowed for
        # defining hidden environment variables
        if len(key) == 0 or '=' in key[1:]:
            raise oefmt(space.w_ValueError,
                "illegal environment variable name")
        env[key] = val
    return env


def execve(space, w_path, w_argv, w_env):
    """execve(path, argv, env)

Execute a path with arguments and environment, replacing current process.

    path: path of executable file
    argv: tuple or list of arguments
    env: dictionary of strings mapping to strings

On some platforms, you may specify an open file descriptor for path;
  execve will execute the program the file descriptor is open to.
  If this functionality is unavailable, using it raises NotImplementedError.
    """
    if not (space.isinstance_w(w_argv, space.w_list)
            or space.isinstance_w(w_argv, space.w_tuple)):
        raise oefmt(space.w_TypeError,
            "execve: argv must be a tuple or a list")
    args = [space.fsencode_w(w_arg) for w_arg in space.unpackiterable(w_argv)]
    if len(args) < 1:
        raise oefmt(space.w_ValueError,
            "execve() arg 2 must not be empty")
    if not args[0]:
        raise oefmt(space.w_ValueError,
            "execve() arg 2 first element cannot be empty")
    env = _env2interp(space, w_env)
    try:
        path = space.fsencode_w(w_path)
    except OperationError:
        if not rposix.HAVE_FEXECVE:
            raise oefmt(space.w_TypeError,
                "execve: illegal type for path argument")
        if not space.isinstance_w(w_path, space.w_int):
            raise oefmt(space.w_TypeError,
                "argument should be string, bytes or integer, not %T", w_path)
        # File descriptor case
        fd = unwrap_fd(space, w_path)
        try:
            rposix.fexecve(fd, args, env)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
    else:
        try:
            os.execve(path, args, env)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(mode=int, path='fsencode')
def spawnv(space, mode, path, w_argv):
    if not (space.isinstance_w(w_argv, space.w_list)
            or space.isinstance_w(w_argv, space.w_tuple)):
        raise oefmt(space.w_TypeError,
            "spawnv: argv must be a tuple or a list")
    args = [space.fsencode_w(w_arg) for w_arg in space.unpackiterable(w_argv)]
    if len(args) < 1:
        raise oefmt(space.w_ValueError,
            "spawnv() arg 2 cannot be empty")
    if not args[0]:
        raise oefmt(space.w_ValueError,
            "spawnv() arg 2 first element cannot be empty")
    try:
        ret = os.spawnv(mode, path, args)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(ret)

@unwrap_spec(mode=int, path='fsencode')
def spawnve(space, mode, path, w_argv, w_env):
    if not (space.isinstance_w(w_argv, space.w_list)
            or space.isinstance_w(w_argv, space.w_tuple)):
        raise oefmt(space.w_TypeError,
            "spawnve: argv must be a tuple or a list")
    args = [space.fsencode_w(w_arg) for w_arg in space.unpackiterable(w_argv)]
    if len(args) < 1:
        raise oefmt(space.w_ValueError,
            "spawnv() arg 2 cannot be empty")
    env = _env2interp(space, w_env)
    if not args[0]:
        raise oefmt(space.w_ValueError,
            "spawnve() arg 2 first element cannot be empty")
    try:
        ret = os.spawnve(mode, path, args, env)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(ret)


@unwrap_spec(
    path=path_or_fd(allow_fd=rposix.HAVE_FUTIMENS or rposix.HAVE_FUTIMES),
    w_times=WrappedDefault(None), w_ns=WrappedDefault(None),
    dir_fd=DirFD(rposix.HAVE_UTIMENSAT), follow_symlinks=bool)
def utime(space, path, w_times, __kwonly__, w_ns, dir_fd=DEFAULT_DIR_FD,
          follow_symlinks=True):
    """utime(path, times=None, *, ns=None, dir_fd=None, follow_symlinks=True)

Set the access and modified time of path.

path may always be specified as a string.
On some platforms, path may also be specified as an open file descriptor.
  If this functionality is unavailable, using it raises an exception.

If times is not None, it must be a tuple (atime, mtime);
    atime and mtime should be expressed as float seconds since the epoch.
If ns is not None, it must be a tuple (atime_ns, mtime_ns);
    atime_ns and mtime_ns should be expressed as integer nanoseconds
    since the epoch.
If both times and ns are None, utime uses the current time.
Specifying tuples for both times and ns is an error.

If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, utime will modify the symbolic link itself instead of the file the
  link points to.
It is an error to use dir_fd or follow_symlinks when specifying path
  as an open file descriptor.
dir_fd and follow_symlinks may not be available on your platform.
  If they are unavailable, using them will raise a NotImplementedError."""
    utime = parse_utime_args(space, w_times, w_ns)

    if path.as_fd != -1:
        if dir_fd != DEFAULT_DIR_FD:
            raise oefmt(space.w_ValueError,
                        "utime: can't specify both dir_fd and fd")
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                        "utime: cannot use fd and follow_symlinks together")
        if rposix.HAVE_FUTIMENS:
            do_utimens(space, rposix.futimens, path.as_fd, utime)
        elif rposix.HAVE_FUTIMES:
            do_utimes(space, rposix.futimes, path.as_fd, utime)
    elif rposix.HAVE_UTIMENSAT:
        if path.as_bytes is None:
            raise oefmt(space.w_NotImplementedError,
                        "utime: unsupported value for 'path'")
        do_utimens(space, rposix.utimensat, path.as_bytes, utime,
                   dir_fd, follow_symlinks)
    elif rposix.HAVE_LUTIMES and not follow_symlinks:
        if path.as_bytes is None:
            raise oefmt(space.w_NotImplementedError,
                        "utime: unsupported value for 'path'")
        do_utimes(space, rposix.lutimes, path.as_bytes, utime)
    elif follow_symlinks:
        do_utimes(space, _dispatch_utime, path, utime)
    else:
        raise argument_unavailable(space, "utime", "follow_symlinks")

def parse_utime_args(space, w_times, w_ns):
    """Parse utime's times/ns arguments into a 5-item tuple of a "now"
    flag and 2 "TIMESPEC" like 2-item s/ns values
    """
    if (not space.is_w(w_times, space.w_None) and
            not space.is_w(w_ns, space.w_None)):
        raise oefmt(space.w_ValueError,
            "utime: you may specify either 'times' or 'ns' but not both")
    now = False
    if space.is_w(w_times, space.w_None) and space.is_w(w_ns, space.w_None):
        now = True
        atime_s = mtime_s = 0
        atime_ns = mtime_ns = 0
    elif not space.is_w(w_times, space.w_None):
        times_w = space.fixedview(w_times)
        if len(times_w) != 2 or not space.isinstance_w(w_times, space.w_tuple):
            raise oefmt(space.w_TypeError,
                "utime: 'times' must be either a tuple of two ints or None")
        atime_s, atime_ns = convert_seconds(space, times_w[0])
        mtime_s, mtime_ns = convert_seconds(space, times_w[1])
    else:
        args_w = space.fixedview(w_ns)
        if len(args_w) != 2 or not space.isinstance_w(w_ns, space.w_tuple):
            raise oefmt(space.w_TypeError,
                "utime: 'ns' must be a tuple of two ints")
        atime_s, atime_ns = convert_ns(space, args_w[0])
        mtime_s, mtime_ns = convert_ns(space, args_w[1])
    return now, atime_s, atime_ns, mtime_s, mtime_ns

@specialize.arg(1)
def do_utimens(space, func, arg, utime, *args):
    """Common implementation for futimens/utimensat etc."""
    now, atime_s, atime_ns, mtime_s, mtime_ns = utime
    if now:
        atime_ns = mtime_ns = rposix.UTIME_NOW
    try:
        func(arg, atime_s, atime_ns, mtime_s, mtime_ns, *args)
    except OSError as e:
        # CPython's Modules/posixmodule.c::posix_utime() has this
        # comment:
        # /* Avoid putting the file name into the error here,
        #    as that may confuse the user into believing that
        #    something is wrong with the file, when it also
        #    could be the time stamp that gives a problem. */
        # so we use wrap_oserror() instead of wrap_oserror2() here
        raise wrap_oserror(space, e, eintr_retry=False)

@specialize.arg(1)
def do_utimes(space, func, arg, utime):
    """Common implementation for f/l/utimes"""
    now, atime_s, atime_ns, mtime_s, mtime_ns = utime
    try:
        if now:
            func(arg, None)
        else:
            # convert back to utimes style floats. loses precision of
            # nanoseconds but utimes only support microseconds anyway
            atime = atime_s + (atime_ns / 1e9)
            mtime = mtime_s + (mtime_ns / 1e9)
            func(arg, (atime, mtime))
    except OSError as e:
        # see comment above: don't use wrap_oserror2()
        raise wrap_oserror(space, e, eintr_retry=False)

@specialize.argtype(1)
def _dispatch_utime(path, times):
    # XXX: a dup. of call_rposix to specialize rposix.utime taking a
    # Path for win32 support w/ do_utimes
    if path.as_unicode is not None:
        return rposix.utime(path.as_unicode, times)
    else:
        path_b = path.as_bytes
        assert path_b is not None
        return rposix.utime(path.as_bytes, times)


def convert_seconds(space, w_time):
    if space.isinstance_w(w_time, space.w_float):
        time = space.float_w(w_time)
        fracpart, intpart = modf(time)
        if fracpart < 0:
            fracpart += 1.
            intpart -= 1.
        return int(intpart), int(fracpart*1e9)
    else:
        time = space.int_w(w_time)
        return time, 0

def convert_ns(space, w_ns_time):
    w_billion = space.newint(1000000000)
    w_res = space.divmod(w_ns_time, w_billion)
    res_w = space.fixedview(w_res)
    time_int = space.int_w(res_w[0])
    time_frac = space.int_w(res_w[1])
    return time_int, time_frac


def uname(space):
    """ uname() -> (sysname, nodename, release, version, machine)

    Return a tuple identifying the current operating system.
    """
    try:
        r = os.uname()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    l_w = [space.newfilename(i)
           for i in [r[0], r[1], r[2], r[3], r[4]]]
    w_tuple = space.newtuple(l_w)
    w_uname_result = space.getattr(space.getbuiltinmodule(os.name),
                                   space.newtext('uname_result'))
    return space.call_function(w_uname_result, w_tuple)

def getuid(space):
    """ getuid() -> uid

    Return the current process's user id.
    """
    return wrap_uid(space, os.getuid())

@unwrap_spec(uid=c_uid_t)
def setuid(space, uid):
    """ setuid(uid)

    Set the current process's user id.
    """
    try:
        os.setuid(uid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(euid=c_uid_t)
def seteuid(space, euid):
    """ seteuid(euid)

    Set the current process's effective user id.
    """
    try:
        os.seteuid(euid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(gid=c_gid_t)
def setgid(space, gid):
    """ setgid(gid)

    Set the current process's group id.
    """
    try:
        os.setgid(gid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(egid=c_gid_t)
def setegid(space, egid):
    """ setegid(egid)

    Set the current process's effective group id.
    """
    try:
        os.setegid(egid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

def chroot(space, w_path):
    """ chroot(path)

    Change root directory to path.
    """
    path = space.fsencode_w(w_path)
    try:
        os.chroot(path)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)
    return space.w_None

def getgid(space):
    """ getgid() -> gid

    Return the current process's group id.
    """
    return wrap_gid(space, os.getgid())

def getegid(space):
    """ getegid() -> gid

    Return the current process's effective group id.
    """
    return wrap_gid(space, os.getegid())

def geteuid(space):
    """ geteuid() -> euid

    Return the current process's effective user id.
    """
    return wrap_uid(space, os.geteuid())

def getgroups(space):
    """ getgroups() -> list of group IDs

    Return list of supplemental group IDs for the process.
    """
    try:
        list = os.getgroups()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newlist([wrap_gid(space, e) for e in list])

def setgroups(space, w_groups):
    """ setgroups(groups)

    Set the groups of the current process to list.
    """
    list = []
    for w_gid in space.unpackiterable(w_groups):
        list.append(space.c_uid_t_w(w_gid))
    try:
        os.setgroups(list[:])
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(username='text', gid=c_gid_t)
def initgroups(space, username, gid):
    """ initgroups(username, gid) -> None

    Call the system initgroups() to initialize the group access list with all of
    the groups of which the specified username is a member, plus the specified
    group id.
    """
    try:
        os.initgroups(username, gid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(username='text', gid=c_gid_t)
def getgrouplist(space, username, gid):
    """
    getgrouplist(user, group) -> list of groups to which a user belongs

    Returns a list of groups to which a user belongs.

    user: username to lookup
    group: base group id of the user
    """
    try:
        groups = rposix.getgrouplist(username, gid)
        return space.newlist([space.newint(g) for g in groups])
    except OSError as e:
        raise wrap_oserror(space, e)


def getpgrp(space):
    """ getpgrp() -> pgrp

    Return the current process group id.
    """
    return space.newint(os.getpgrp())

def setpgrp(space):
    """ setpgrp()

    Make this process a session leader.
    """
    try:
        os.setpgrp()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.w_None

def getppid(space):
    """ getppid() -> ppid

    Return the parent's process id.
    """
    return space.newint(os.getppid())

@unwrap_spec(pid=c_int)
def getpgid(space, pid):
    """ getpgid(pid) -> pgid

    Call the system call getpgid().
    """
    try:
        pgid = os.getpgid(pid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(pgid)

@unwrap_spec(pid=c_int, pgrp=c_int)
def setpgid(space, pid, pgrp):
    """ setpgid(pid, pgrp)

    Call the system call setpgid().
    """
    try:
        os.setpgid(pid, pgrp)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.w_None

@unwrap_spec(ruid=c_uid_t, euid=c_uid_t)
def setreuid(space, ruid, euid):
    """ setreuid(ruid, euid)

    Set the current process's real and effective user ids.
    """
    try:
        os.setreuid(ruid, euid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(rgid=c_gid_t, egid=c_gid_t)
def setregid(space, rgid, egid):
    """ setregid(rgid, egid)

    Set the current process's real and effective group ids.
    """
    try:
        os.setregid(rgid, egid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(pid=c_int)
def getsid(space, pid):
    """ getsid(pid) -> sid

    Call the system call getsid().
    """
    try:
        sid = os.getsid(pid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(sid)

def setsid(space):
    """ setsid()

    Call the system call setsid().
    """
    try:
        os.setsid()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.w_None

@unwrap_spec(fd=c_int)
def tcgetpgrp(space, fd):
    """ tcgetpgrp(fd) -> pgid

    Return the process group associated with the terminal given by a fd.
    """
    try:
        pgid = os.tcgetpgrp(fd)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(pgid)

@unwrap_spec(fd=c_int, pgid=c_gid_t)
def tcsetpgrp(space, fd, pgid):
    """ tcsetpgrp(fd, pgid)

    Set the process group associated with the terminal given by a fd.
    """
    try:
        os.tcsetpgrp(fd, pgid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

def getresuid(space):
    """ getresuid() -> (ruid, euid, suid)

    Get tuple of the current process's real, effective, and saved user ids.
    """
    try:
        (ruid, euid, suid) = os.getresuid()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtuple([wrap_uid(space, ruid),
                           wrap_uid(space, euid),
                           wrap_uid(space, suid)])

def getresgid(space):
    """ getresgid() -> (rgid, egid, sgid)

    Get tuple of the current process's real, effective, and saved group ids.
    """
    try:
        (rgid, egid, sgid) = os.getresgid()
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtuple([wrap_gid(space, rgid),
                           wrap_gid(space, egid),
                           wrap_gid(space, sgid)])

@unwrap_spec(ruid=c_uid_t, euid=c_uid_t, suid=c_uid_t)
def setresuid(space, ruid, euid, suid):
    """ setresuid(ruid, euid, suid)

    Set the current process's real, effective, and saved user ids.
    """
    try:
        os.setresuid(ruid, euid, suid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(rgid=c_gid_t, egid=c_gid_t, sgid=c_gid_t)
def setresgid(space, rgid, egid, sgid):
    """ setresgid(rgid, egid, sgid)

    Set the current process's real, effective, and saved group ids.
    """
    try:
        os.setresgid(rgid, egid, sgid)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(which=int, who=int)
def getpriority(space, which, who):
    """ getpriority(which, who) -> int

    Get program scheduling priority.
    """
    try:
        returned_priority = rposix.getpriority(which, who)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(returned_priority)

@unwrap_spec(which=int, who=int, priority=int)
def setpriority(space, which, who, priority):
    """ setpriority(which, who, priority)

    Set program scheduling priority.
    """
    try:
        rposix.setpriority(which, who, priority)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

def declare_new_w_star(name):
    if name in ('WEXITSTATUS', 'WSTOPSIG', 'WTERMSIG'):
        @unwrap_spec(status=c_int)
        def WSTAR(space, status):
            return space.newint(getattr(os, name)(status))
    else:
        @unwrap_spec(status=c_int)
        def WSTAR(space, status):
            return space.newbool(getattr(os, name)(status))
    WSTAR.__doc__ = getattr(os, name).__doc__
    WSTAR.func_name = name
    return WSTAR

for name in rposix.WAIT_MACROS:
    if hasattr(os, name):
        func = declare_new_w_star(name)
        globals()[name] = func


@unwrap_spec(fd=c_int)
def ttyname(space, fd):
    try:
        return space.newfilename(os.ttyname(fd))
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)


def confname_w(space, w_name, namespace):
    # XXX slightly non-nice, reuses the sysconf of the underlying os module
    if space.isinstance_w(w_name, space.w_unicode):
        try:
            num = namespace[space.text_w(w_name)]
        except KeyError:
            raise oefmt(space.w_ValueError, "unrecognized configuration name")
    else:
        num = space.int_w(w_name)
    return num

def sysconf(space, w_name):
    num = confname_w(space, w_name, rposix.sysconf_names)
    try:
        res = os.sysconf(num)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(res)

def sysconf_names():
    return rposix.sysconf_names

@unwrap_spec(fd=c_int)
def fpathconf(space, fd, w_name):
    num = confname_w(space, w_name, os.pathconf_names)
    try:
        res = os.fpathconf(fd, num)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(res)

@unwrap_spec(path=path_or_fd(allow_fd=hasattr(os, 'fpathconf')))
def pathconf(space, path, w_name):
    num = confname_w(space, w_name, rposix.pathconf_names)
    if path.as_fd != -1:
        try:
            res = os.fpathconf(path.as_fd, num)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
    else:
        try:
            res = os.pathconf(path.as_bytes, num)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path, eintr_retry=False)
    return space.newint(res)

def pathconf_names():
    return rposix.pathconf_names

def confstr(space, w_name):
    num = confname_w(space, w_name, rposix.confstr_names)
    try:
        res = os.confstr(num)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newtext(res)

def confstr_names():
    return rposix.confstr_names

@unwrap_spec(
    uid=c_uid_t, gid=c_gid_t,
    dir_fd=DirFD(rposix.HAVE_FCHOWNAT), follow_symlinks=bool)
def chown(space, w_path, uid, gid, __kwonly__,
          dir_fd=DEFAULT_DIR_FD, follow_symlinks=True):
    """chown(path, uid, gid, *, dir_fd=None, follow_symlinks=True)

Change the owner and group id of path to the numeric uid and gid.

path may always be specified as a string.
On some platforms, path may also be specified as an open file descriptor.
  If this functionality is unavailable, using it raises an exception.
If dir_fd is not None, it should be a file descriptor open to a directory,
  and path should be relative; path will then be relative to that directory.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, chown will modify the symbolic link itself instead of the file the
  link points to.
It is an error to use dir_fd or follow_symlinks when specifying path as
  an open file descriptor.
dir_fd and follow_symlinks may not be implemented on your platform.
  If they are unavailable, using them will raise a NotImplementedError."""
    if not (rposix.HAVE_LCHOWN or rposix.HAVE_FCHMODAT):
        if not follow_symlinks:
            raise argument_unavailable(space, 'chown', 'follow_symlinks')
    try:
        path = space.fsencode_w(w_path)
    except OperationError:
        if not space.isinstance_w(w_path, space.w_int):
            raise oefmt(space.w_TypeError,
                "argument should be string, bytes or integer, not %T", w_path)
        # File descriptor case
        fd = unwrap_fd(space, w_path)
        if dir_fd != DEFAULT_DIR_FD:
            raise oefmt(space.w_ValueError,
                "chown: can't specify both dir_fd and fd")
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                "chown: cannnot use fd and follow_symlinks together")
        # NB. in CPython 3.5.2, os.chown(fd) propagates EINTR to app-level,
        # but os.fchown(fd) retries automatically.  This might be fixed in
        # more recent CPythons.
        while True:
            try:
                os.fchown(fd, uid, gid)
                return
            except OSError as e:
                wrap_oserror(space, e, eintr_retry=True)
    while True:
        # String case
        try:
            if (rposix.HAVE_LCHOWN and
                    dir_fd == DEFAULT_DIR_FD and not follow_symlinks):
                os.lchown(path, uid, gid)
            elif rposix.HAVE_FCHOWNAT and (
                    not follow_symlinks or dir_fd != DEFAULT_DIR_FD):
                rposix.fchownat(path, uid, gid, dir_fd, follow_symlinks)
            else:
                assert follow_symlinks
                assert dir_fd == DEFAULT_DIR_FD
                os.chown(path, uid, gid)
            break
        except OSError as e:
            wrap_oserror2(space, e, w_path, eintr_retry=True)


@unwrap_spec(uid=c_uid_t, gid=c_gid_t)
def lchown(space, w_path, uid, gid):
    """lchown(path, uid, gid)

Change the owner and group id of path to the numeric uid and gid.
This function will not follow symbolic links.
Equivalent to os.chown(path, uid, gid, follow_symlinks=False)."""
    path = space.fsencode_w(w_path)
    try:
        os.lchown(path, uid, gid)
    except OSError as e:
        raise wrap_oserror2(space, e, w_path, eintr_retry=False)

@unwrap_spec(uid=c_uid_t, gid=c_gid_t)
def fchown(space, w_fd, uid, gid):
    """fchown(fd, uid, gid)

Change the owner and group id of the file given by file descriptor
fd to the numeric uid and gid.  Equivalent to os.chown(fd, uid, gid)."""
    fd = space.c_filedescriptor_w(w_fd)
    while True:
        try:
            os.fchown(fd, uid, gid)
            break
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)

def getloadavg(space):
    try:
        load = os.getloadavg()
    except OSError:
        raise oefmt(space.w_OSError, "Load averages are unobtainable")
    return space.newtuple([space.newfloat(load[0]),
                           space.newfloat(load[1]),
                           space.newfloat(load[2])])

@unwrap_spec(major=c_int, minor=c_int)
def makedev(space, major, minor):
    result = os.makedev(major, minor)
    return space.newint(result)

@unwrap_spec(device="c_uint")
def major(space, device):
    result = os.major(intmask(device))
    return space.newint(result)

@unwrap_spec(device="c_uint")
def minor(space, device):
    result = os.minor(intmask(device))
    return space.newint(result)

@unwrap_spec(increment=c_int)
def nice(space, increment):
    """Decrease the priority of process by 'increment'
    and return the new priority."""
    try:
        res = os.nice(increment)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newint(res)

class SigCheck:
    pass
_sigcheck = SigCheck()
def _signal_checker():
    _sigcheck.space.getexecutioncontext().checksignals()

@unwrap_spec(size=int)
def urandom(space, size):
    """urandom(size) -> str

    Return a string of 'size' random bytes suitable for cryptographic use.
    """
    context = get(space).random_context
    if size < 0:
        raise oefmt(space.w_ValueError, "negative argument not allowed")
    try:
        # urandom() takes a final argument that should be a regular function,
        # not a bound method like 'getexecutioncontext().checksignals'.
        # Otherwise, we can't use it from several independent places.
        _sigcheck.space = space
        return space.newbytes(rurandom.urandom(context, size, _signal_checker))
    except OSError as e:
        # CPython raises NotImplementedError if /dev/urandom cannot be found.
        # To maximize compatibility, we should also raise NotImplementedError
        # and not OSError (although CPython also raises OSError in case it
        # could open /dev/urandom but there are further problems).
        raise wrap_oserror(space, e,
            w_exception_class=space.w_NotImplementedError, eintr_retry=False)

def ctermid(space):
    """ctermid() -> string

    Return the name of the controlling terminal for this process.
    """
    return space.newfilename(os.ctermid())

@unwrap_spec(fd=c_int)
def device_encoding(space, fd):
    """device_encoding(fd) -> str

    Return a string describing the encoding of the device if the output
    is a terminal; else return None.
    """
    if not (os.isatty(fd)):
        return space.w_None
    if _WIN32:
        if fd == 0:
            ccp = rwin32.GetConsoleCP()
        elif fd in (1, 2):
            ccp = rwin32.GetConsoleOutputCP()
        else:
            ccp = 0
        # GetConsoleCP() and GetConsoleOutputCP() return 0 if the
        # application has no console.
        if ccp != 0:
            return space.newtext('cp%d' % ccp)
    from rpython.rlib import rlocale
    if rlocale.HAVE_LANGINFO:
        codeset = rlocale.nl_langinfo(rlocale.CODESET)
        if codeset:
            return space.newtext(codeset)
    return space.w_None

if _WIN32:
    from pypy.module.posix import interp_nt as nt

    @unwrap_spec(fd=c_int)
    def _getfileinformation(space, fd):
        try:
            info = nt._getfileinformation(fd)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)
        return space.newtuple([space.newint(info[0]),
                               space.newint(info[1]),
                               space.newint(info[2])])

    def _getfinalpathname(space, w_path):
        try:
            s, lgt = dispatch_filename(nt._getfinalpathname)(space, w_path)
        except nt.LLNotImplemented as e:
            raise OperationError(space.w_NotImplementedError,
                                 space.newtext(e.msg))
        except OSError as e:
            raise wrap_oserror2(space, e, w_path, eintr_retry=False)
        return space.newtext(s, lgt)

    @unwrap_spec(fd=c_int)
    def get_handle_inheritable(space, fd):
        handle = rffi.cast(rwin32.HANDLE, fd)
        try:
            return space.newbool(rwin32.get_handle_inheritable(handle))
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)

    @unwrap_spec(fd=c_int, inheritable=bool)
    def set_handle_inheritable(space, fd, inheritable):
        handle = rffi.cast(rwin32.HANDLE, fd)
        try:
            rwin32.set_handle_inheritable(handle, inheritable)
        except OSError as e:
            raise wrap_oserror(space, e, eintr_retry=False)


def chflags():
    """chflags(path, flags, *, follow_symlinks=True)

Set file flags.

If follow_symlinks is False, and the last element of the path is a symbolic
  link, chflags will change flags on the symbolic link itself instead of the
  file the link points to.
follow_symlinks may not be implemented on your platform.  If it is
unavailable, using it will raise a NotImplementedError."""

def lchflags():
    """lchflags(path, flags)

Set file flags.
This function will not follow symbolic links.
Equivalent to chflags(path, flags, follow_symlinks=False)."""

@unwrap_spec(path=path_or_fd(), attribute=path_or_fd(allow_fd=False),
             follow_symlinks=bool)
def getxattr(space, path, attribute, __kwonly__, follow_symlinks=True):
    """getxattr(path, attribute, *, follow_symlinks=True) -> value

Return the value of extended attribute attribute on path.

path may be either a string or an open file descriptor.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, getxattr will examine the symbolic link itself instead of the file
  the link points to."""
    if path.as_fd != -1:
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                "getxattr: cannot use fd and follow_symlinks together")
        try:
            result = rposix.fgetxattr(path.as_fd, attribute.as_bytes)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    else:
        try:
            result = rposix.getxattr(path.as_bytes, attribute.as_bytes,
                follow_symlinks=follow_symlinks)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    return space.newbytes(result)

@unwrap_spec(path=path_or_fd(), attribute=path_or_fd(allow_fd=False),
             flags=c_int,
             follow_symlinks=bool)
def setxattr(space, path, attribute, w_value, flags=0,
             __kwonly__=None, follow_symlinks=True):
    """setxattr(path, attribute, value, flags=0, *, follow_symlinks=True)

Set extended attribute attribute on path to value.
path may be either a string or an open file descriptor.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, setxattr will modify the symbolic link itself instead of the file
  the link points to."""
    value = space.charbuf_w(w_value)
    if path.as_fd != -1:
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                "setxattr: cannot use fd and follow_symlinks together")
        try:
            rposix.fsetxattr(path.as_fd, attribute.as_bytes, value, flags)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    else:
        try:
            rposix.setxattr(path.as_bytes, attribute.as_bytes, value, flags,
                follow_symlinks=follow_symlinks)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)


@unwrap_spec(path=path_or_fd(), attribute=path_or_fd(allow_fd=False),
             follow_symlinks=bool)
def removexattr(space, path, attribute, __kwonly__, follow_symlinks=True):
    """removexattr(path, attribute, *, follow_symlinks=True)

Remove extended attribute attribute on path.
path may be either a string or an open file descriptor.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, removexattr will modify the symbolic link itself instead of the file
  the link points to."""
    if path.as_fd != -1:
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                "removexattr: cannot use fd and follow_symlinks together")
        try:
            rposix.fremovexattr(path.as_fd, attribute.as_bytes)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    else:
        try:
            rposix.removexattr(path.as_bytes, attribute.as_bytes,
                follow_symlinks=follow_symlinks)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)


@unwrap_spec(path=path_or_fd(), follow_symlinks=bool)
def listxattr(space, path, __kwonly__, follow_symlinks=True):
    """listxattr(path='.', *, follow_symlinks=True)

Return a list of extended attributes on path.

path may be either None, a string, or an open file descriptor.
if path is None, listxattr will examine the current directory.
If follow_symlinks is False, and the last element of the path is a symbolic
  link, listxattr will examine the symbolic link itself instead of the file
  the link points to."""
    if path.as_fd != -1:
        if not follow_symlinks:
            raise oefmt(space.w_ValueError,
                        "listxattr: cannot use fd and follow_symlinks together")
        try:
            result = rposix.flistxattr(path.as_fd)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    else:
        try:
            result = rposix.listxattr(path.as_bytes, follow_symlinks)
        except OSError as e:
            raise wrap_oserror2(space, e, path.w_path)
    return space.newlist([space.newfilename(attr) for attr in result])

@unwrap_spec(name='text', flags=int)
def memfd_create(space, name, flags=getattr(rposix, "MFD_CLOEXEC", 0xdead)):
    """
os.memfd_create(name[, flags=os.MFD_CLOEXEC])

Create an anonymous file and return a file descriptor that refers to it. flags
must be one of the os.MFD_* constants available on the system (or a bitwise
ORed combination of them). By default, the new file descriptor is
non-inheritable.

The name supplied in name is used as a filename and will be displayed as the
target of the corresponding symbolic link in the directory /proc/self/fd/. The
displayed name is always prefixed with memfd: and serves only for debugging
purposes. Names do not affect the behavior of the file descriptor, and as such
multiple files can have the same name without any side effects.
"""
    try:
        result = rposix.memfd_create(name, flags)
    except OSError as e:
        raise wrap_oserror2(space, e)
    return space.newint(result)


have_functions = []
for name in """FACCESSAT FCHDIR FCHMOD FCHMODAT FCHOWN FCHOWNAT FEXECVE
               FDOPENDIR FPATHCONF FSTATAT FSTATVFS FTRUNCATE FUTIMENS FUTIMES
               FUTIMESAT LINKAT LCHFLAGS LCHMOD LCHOWN LSTAT LUTIMES
               MKDIRAT MKFIFOAT MKNODAT OPENAT READLINKAT RENAMEAT
               SYMLINKAT UNLINKAT UTIMENSAT""".split():
    if getattr(rposix, "HAVE_%s" % name):
        have_functions.append("HAVE_%s" % name)
if _WIN32:
    have_functions.append("HAVE_MS_WINDOWS")

def _get_terminal_size(space, w_fd=None):
    if w_fd is None:
        fd = rfile.RFile(rfile.c_stdout(), close2=(None, None)).fileno()
    else:
        if not space.isinstance_w(w_fd, space.w_int):
            raise oefmt(space.w_TypeError,
                        "an integer is required, got %T", w_fd)
        else:
            fd = space.c_int_w(w_fd)

    if _WIN32:
        if fd == 0:
            handle_id = rwin32.STD_INPUT_HANDLE
        elif fd == 1:
            handle_id = rwin32.STD_OUTPUT_HANDLE
        elif fd == 2:
            handle_id = rwin32.STD_ERROR_HANDLE
        else:
            raise oefmt(space.w_ValueError, "bad file descriptor")

        handle = rwin32.GetStdHandle(handle_id)

        if handle == rwin32.NULL_HANDLE:
            raise oefmt(space.w_OSError, "handle cannot be retrieved")
        elif handle == rwin32.INVALID_HANDLE_VALUE:
            raise rwin32.lastSavedWindowsError()
        with lltype.scoped_alloc(rwin32.CONSOLE_SCREEN_BUFFER_INFO) as buffer_info:
            success = rwin32.GetConsoleScreenBufferInfo(handle, buffer_info)
            if not success:
                raise rwin32.lastSavedWindowsError()
            w_columns = space.newint(r_int(buffer_info.c_srWindow.c_Right) - r_int(buffer_info.c_srWindow.c_Left) + 1)
            w_lines = space.newint(r_int(buffer_info.c_srWindow.c_Bottom) - r_int(buffer_info.c_srWindow.c_Top) + 1)
    else:
        with lltype.scoped_alloc(rposix.WINSIZE) as winsize:
            failed = rposix.c_ioctl_voidp(fd, rposix.TIOCGWINSZ, winsize)
            if failed:
                raise exception_from_saved_errno(space, space.w_OSError)

            w_columns = space.newint(r_uint(winsize.c_ws_col))
            w_lines = space.newint(r_uint(winsize.c_ws_row))
    return w_columns, w_lines

def get_terminal_size(space, w_fd=None):
    try:
        w_columns, w_lines = _get_terminal_size(space, w_fd)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    w_tuple = space.newtuple([w_columns, w_lines])
    w_terminal_size = space.getattr(space.getbuiltinmodule(os.name),
                                    space.newtext('terminal_size'))

    return space.call_function(w_terminal_size, w_tuple)

def cpu_count(space):
    count = rposix.cpu_count()
    if count <= 0:
        return space.w_None
    return space.newint(count)

@unwrap_spec(fd=c_int)
def get_blocking(space, fd):
    """get_blocking(fd) -> bool

Get the blocking mode of the file descriptor:
False if the O_NONBLOCK flag is set, True if the flag is cleared."""
    try:
        flags = rposix.get_status_flags(fd)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)
    return space.newbool(flags & rposix.O_NONBLOCK == 0)

@unwrap_spec(fd=c_int, blocking=int)
def set_blocking(space, fd, blocking):
    """\
set_blocking(fd, blocking)

Set the blocking mode of the specified file descriptor.
Set the O_NONBLOCK flag if blocking is False,
clear the O_NONBLOCK flag otherwise."""
    try:
        flags = rposix.get_status_flags(fd)
        if blocking:
            flags &= ~rposix.O_NONBLOCK
        else:
            flags |= rposix.O_NONBLOCK
        rposix.set_status_flags(fd, flags)
    except OSError as e:
        raise wrap_oserror(space, e, eintr_retry=False)

@unwrap_spec(out_fd=c_int, count=int)
def sendfile(space, out_fd, w_in_fd, w_offset, count):
    """\
sendfile(out_fd, in_fd, offset, count[, headers][, trailers], flags=0)
            -> byteswritten
Copy count bytes from file descriptor in to file descriptor out."""
    # why is an argument called "in"???  that doesn't make sense (it is
    # a reserved word), but that's what CPython does
    in_ = space.c_int_w(w_in_fd)

    # XXX only supports the common arguments for now (BSD takes more).
    # Until that is fixed, we only expose sendfile() on linux.
    if space.is_none(w_offset):     # linux only
        while True:
            try:
                res = rposix.sendfile_no_offset(out_fd, in_, count)
                break
            except OSError as e:
                wrap_oserror(space, e, eintr_retry=True)
    else:
        offset = space.gateway_r_longlong_w(w_offset)
        while True:
            try:
                res = rposix.sendfile(out_fd, in_, offset, count)
                break
            except OSError as e:
                wrap_oserror(space, e, eintr_retry=True)
    return space.newint(res)

@unwrap_spec(policy=int)
def sched_get_priority_max(space, policy):
    """returns the maximum priority value that
    can be used with the scheduling algorithm
    identified by policy
    """
    while True:
        try:
            s = rposix.sched_get_priority_max(policy)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
           return space.newint(s)

@unwrap_spec(policy=int)
def sched_get_priority_min(space, policy):
    """returns the minimum priority value that
     can be used with the scheduling algorithm
     identified by policy
    """
    while True:
        try:
            s = rposix.sched_get_priority_min(policy)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
           return space.newint(s)

@unwrap_spec(fd=c_int, cmd=c_int, length=r_longlong)
def lockf(space, fd, cmd, length):
    """apply, test or remove a POSIX lock on an
    open file.
    """
    while True:
        try:
            s = rposix.lockf(fd, cmd, length)
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
           return space.newint(s)

def sched_yield(space):
    """ Voluntarily relinquish the CPU"""
    while True:
        try:
            res = rposix.sched_yield()
        except OSError as e:
            wrap_oserror(space, e, eintr_retry=True)
        else:
            return space.newint(res)

def fspath(space, w_path):
    """
    Return the file system path representation of the object.

    If the object is str or bytes, then allow it to pass through as-is. If the
    object defines __fspath__(), then return the result of that method. All other
    types raise a TypeError.
    """
    if (space.isinstance_w(w_path, space.w_text) or
        space.isinstance_w(w_path, space.w_bytes)):
        return w_path

    w_fspath_method = space.lookup(w_path, '__fspath__')
    if w_fspath_method is None:
        raise oefmt(
            space.w_TypeError,
            'expected str, bytes or os.PathLike object, not %T',
            w_path
        )

    w_result = space.get_and_call_function(w_fspath_method, w_path)
    if (space.isinstance_w(w_result, space.w_text) or
        space.isinstance_w(w_result, space.w_bytes)):
        return w_result

    raise oefmt(
        space.w_TypeError,
        'expected %T.__fspath__() to return str or bytes, not %T',
        w_path,
        w_result
    )


@unwrap_spec(pid=int)
def sched_rr_get_interval(space, pid):
    """ get execution time limits. """

    try:
        res = rposix.sched_rr_get_interval(pid)
    except OSError as e:
        wrap_oserror(space, e, eintr_retry=True)
    else:
        return space.newfloat(res)


@unwrap_spec(pid=int)
def sched_getscheduler(space, pid):
    """ get scheduling policy/parameters. """

    try:
        res = rposix.sched_getscheduler(pid)
    except OSError as e:
        wrap_oserror(space, e, eintr_retry=True)
    else:
        return space.newint(res)


@unwrap_spec(pid=int, policy=int)
def sched_setscheduler(space, pid, policy, w_param):
    """ set scheduling policy/parameters. """
    w_sched_param = space.getattr(space.getbuiltinmodule(os.name),
                                  space.newtext('sched_param'))
    if not space.isinstance_w(w_param, w_sched_param):
        raise oefmt(space.w_TypeError, "must have a sched_param object")
    priority = space.int_w(space.getitem(w_param, space.newint(0)))
    if priority > INT_MAX or priority < INT_MIN:
        raise oefmt(space.w_OverflowError, "sched_priority %d out of range", priority)
    try:
        res = rposix.sched_setscheduler(pid, policy, priority)
    except OSError as e:
        wrap_oserror(space, e, eintr_retry=True)
    else:
        return space.newint(res)


@unwrap_spec(pid=int)
def sched_getparam(space, pid):
    """ get scheduling parameters. """

    try:
        res = rposix.sched_getparam(pid)
    except OSError as e:
        wrap_oserror(space, e, eintr_retry=True)
    else:
        w_sched_param = space.getattr(space.getbuiltinmodule(os.name),
                                      space.newtext('sched_param'))

        return space.call_function(w_sched_param, space.newint(res))


@unwrap_spec(pid=int, )
def sched_setparam(space, pid, w_param):
    """ set scheduling parameters. """
    w_sched_param = space.getattr(space.getbuiltinmodule(os.name),
                                  space.newtext('sched_param'))
    if not space.isinstance_w(w_param, w_sched_param):
        raise oefmt(space.w_TypeError, "must have a sched_param object")
    priority = space.int_w(space.getitem(w_param, space.newint(0)))
    if priority > INT_MAX or priority < INT_MIN:
        raise oefmt(space.w_OverflowError, "sched_priority out of range")
    try:
        res = rposix.sched_setparam(pid, priority)
    except OSError as e:
        wrap_oserror(space, e, eintr_retry=True)
    else:
        return space.newint(res)

def splitdrive(p):
    # copied from ntpath.py, but changed to move the sep to the root.
    # where os.path.splitpath('c:\\abc\\def.txt')
    # returns ('c:', '\\abc\\def.txt', we want ('c:\\', 'abc\\def.txt')
    # and '//server/abc/xyz/def.txt' becomes
    # ('//server/abc/', 'xyz/def.txt')
    if len(p) >= 2:
        if isinstance(p, bytes):
            sep = b'\\'
            altsep = b'/'
            colon = b':'
        else:
            sep = '\\'
            altsep = '/'
            colon = ':'
        normp = p.replace(altsep, sep)
        if (normp[0:2] == sep*2) and (normp[2:3] != sep):
            # is a UNC path:
            # vvvvvvvvvvvvvvvvvvvvv drive letter or UNC path
            # \\machine\mountpoint\directory\etc\...
            #           directory  ^^^^^^^^^^^^^^
            index = normp.find(sep, 2)
            if index < 0:
                return p[:0], p
            index2 = normp.find(sep, index + 1)
            # a UNC path can't have two slashes in a row
            # (after the initial two)
            if index2 == index + 1:
                return p[:0], p
            if index2 < 0:
                index2 = len(p)
            return p[:index2+1], p[index2+1:]
        if normp[1:2] == colon and normp[2:3] == sep:
            return p[:3], p[3:]
        elif normp[1:2] == colon:
            return p[:2], p[2:]
    return p[:0], p

def _path_splitroot(space, w_path):
    """Removes everything after the root on Win32."""

    # ... which begs the question "what is a "root"?
    # answer: from trial and error, it is almost-but-not-quite
    # os.path.splitdrive
    p = space.text_w(fspath(space, w_path))
    ret0, ret1 = splitdrive(p)
    #XXX what do we do when w_p is bytes?
    return space.newtuple([space.newtext(ret0), space.newtext(ret1)])

class W_DLLCapsule(W_Root):

    def __init__(self, cookie):
        self.cookie = cookie

def _add_dll_directory(space, w_path):
    """os._add_dll_directory

        path: path_t

    Add a path to the DLL search path.

    This search path is used when resolving dependencies for imported
    extension modules (the module itself is resolved through sys.path),
    and also by ctypes.

    Returns an opaque value that may be passed to os.remove_dll_directory
    to remove this directory from the search path.
    """
    space.audit("os.add_dll_directory", [w_path])
    cookie = rwin32.AddDllDirectory(space.utf8_w(w_path), space.len_w(w_path))
    return W_DLLCapsule(cookie)

def _remove_dll_directory(space, w_cookie):
    """os._remove_dll_directory

        cookie: object

    Removes a path from the DLL search path.

    The parameter is an opaque value that was returned from
    os.add_dll_directory. You can only remove directories that you added
    yourself.
    """

    if not isinstance(w_cookie, W_DLLCapsule):
        raise oefmt(space.w_TypeError, "Provided cookie was not returned "
                    "from os.add_dll_directory")
    cookie = w_cookie.cookie
    # CPython does not emit an audit event here
    return space.newbool(bool(rwin32.RemoveDllDirectory(cookie)))

