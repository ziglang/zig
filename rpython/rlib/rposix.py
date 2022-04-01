import os
import sys
import errno
from rpython.annotator.model import s_Str0
from rpython.rtyper.lltypesystem.rffi import CConstant, CExternVariable, INT
from rpython.rtyper.lltypesystem import lltype, ll2ctypes, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.rlib import debug, jit, rstring, rthread, types
from rpython.rlib._os_support import (
    _CYGWIN, _MACRO_ON_POSIX, UNDERSCORE_ON_WIN32, _WIN32,
    POSIX_SIZE_T, POSIX_SSIZE_T,
    _prefer_unicode, _preferred_traits, _preferred_traits2)
from rpython.rlib.objectmodel import (
    specialize, enforceargs, register_replacement_for, NOT_CONSTANT)
from rpython.rlib.rarithmetic import intmask, widen
from rpython.rlib.signature import signature
from rpython.tool.sourcetools import func_renamer
from rpython.translator.platform import platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo


if _WIN32:
    from rpython.rlib import rwin32
    from rpython.rlib.rwin32file import make_win32_traits


class CConstantErrno(CConstant):
    # these accessors are used when calling get_errno() or set_errno()
    # on top of CPython
    def __getitem__(self, index):
        assert index == 0
        try:
            return ll2ctypes.TLS.errno
        except AttributeError:
            raise ValueError("no C function call occurred so far, "
                             "errno is undefined")
    def __setitem__(self, index, value):
        assert index == 0
        ll2ctypes.TLS.errno = value

if os.name == 'nt':
    includes=['errno.h','stdio.h', 'stdlib.h']
    separate_module_sources =['''
        /* Lifted completely from CPython 3 Modules/posixmodule.c */
        static void __cdecl _Py_silent_invalid_parameter_handler(
            wchar_t const* expression,
            wchar_t const* function,
            wchar_t const* file,
            unsigned int line,
            uintptr_t pReserved) {
        }

        RPY_EXTERN void* enter_suppress_iph(void)
        {
            void* ret = _set_thread_local_invalid_parameter_handler(_Py_silent_invalid_parameter_handler);
            /*fprintf(stdout, "setting %p returning %p\\n", (void*)_Py_silent_invalid_parameter_handler, ret);*/
            return ret;
        }
        RPY_EXTERN void exit_suppress_iph(void*  old_handler)
        {
            void * ret;
            _invalid_parameter_handler _handler = (_invalid_parameter_handler)old_handler;
            ret = _set_thread_local_invalid_parameter_handler(_handler);
            /*fprintf(stdout, "exiting, setting %p returning %p\\n", old_handler, ret);*/
        }
        RPY_EXTERN size_t wrap_write(int fd, const void* data, size_t count)
        {
            _invalid_parameter_handler old = enter_suppress_iph();
            if (count > 32767 && _isatty(fd)) {
                // CPython Issue #11395, PyPy Issue #2636: the Windows console
                // returns an error (12: not enough space error) on writing into
                // stdout if stdout mode is binary and the length is greater than
                // 66,000 bytes (or less, depending on heap usage).  Can't easily
                // test that, because we need 'fd' to be non-redirected...
                count = 32767;
            }
            else if (count > 0x7fffffff)
            {
                count = 0x7fffffff;
            }
            size_t ret = _write(fd, data, count);
            exit_suppress_iph(old);
            return ret;
        }
        RPY_EXTERN size_t wrap_read(int fd, const void* buffer, size_t buffer_size)
        {
            _invalid_parameter_handler old = enter_suppress_iph();
            size_t ret = _read(fd, buffer, buffer_size);
            exit_suppress_iph(old);
            return ret;
        }
    ''',]
    post_include_bits=['RPY_EXTERN void* enter_suppress_iph();',
                       'RPY_EXTERN void exit_suppress_iph(void* handle);',
                       'RPY_EXTERN size_t wrap_write(int, const void*, size_t);',
                       'RPY_EXTERN size_t wrap_read(int, const void*, size_t);',
                      ]
else:
    separate_module_sources = []
    post_include_bits = []
    includes=['errno.h','stdio.h']
errno_eci = ExternalCompilationInfo(
    includes=includes,
    separate_module_sources=separate_module_sources,
    post_include_bits=post_include_bits,
)

# Direct getters/setters, don't use directly!
_get_errno, _set_errno = CExternVariable(INT, 'errno', errno_eci,
                                         CConstantErrno, sandboxsafe=True,
                                         _nowrapper=True, c_type='int')

def get_saved_errno():
    """Return the value of the "saved errno".
    This value is saved after a call to a C function, if it was declared
    with the flag llexternal(..., save_err=rffi.RFFI_SAVE_ERRNO).
    Functions without that flag don't change the saved errno.
    """
    return intmask(rthread.tlfield_rpy_errno.getraw())

def set_saved_errno(errno):
    """Set the value of the saved errno.  This value will be used to
    initialize the real errno just before calling the following C function,
    provided it was declared llexternal(..., save_err=RFFI_READSAVED_ERRNO).
    Note also that it is more common to want the real errno to be initially
    zero; for that case, use llexternal(..., save_err=RFFI_ZERO_ERRNO_BEFORE)
    and then you don't need set_saved_errno(0).
    """
    rthread.tlfield_rpy_errno.setraw(rffi.cast(INT, errno))

def get_saved_alterrno():
    """Return the value of the "saved alterrno".
    This value is saved after a call to a C function, if it was declared
    with the flag llexternal(..., save_err=rffi.RFFI_SAVE_ERRNO | rffl.RFFI_ALT_ERRNO).
    Functions without that flag don't change the saved errno.
    """
    return intmask(rthread.tlfield_alt_errno.getraw())

def set_saved_alterrno(errno):
    """Set the value of the saved alterrno.  This value will be used to
    initialize the real errno just before calling the following C function,
    provided it was declared llexternal(..., save_err=RFFI_READSAVED_ERRNO | rffl.RFFI_ALT_ERRNO).
    Note also that it is more common to want the real errno to be initially
    zero; for that case, use llexternal(..., save_err=RFFI_ZERO_ERRNO_BEFORE)
    and then you don't need set_saved_errno(0).
    """
    rthread.tlfield_alt_errno.setraw(rffi.cast(INT, errno))


# These are not posix specific, but where should they move to?
@specialize.call_location()
def _errno_before(save_err):
    if save_err & rffi.RFFI_READSAVED_ERRNO:
        if save_err & rffi.RFFI_ALT_ERRNO:
            _set_errno(rthread.tlfield_alt_errno.getraw())
        else:
            _set_errno(rthread.tlfield_rpy_errno.getraw())
    elif save_err & rffi.RFFI_ZERO_ERRNO_BEFORE:
        _set_errno(rffi.cast(rffi.INT, 0))
    if _WIN32 and (save_err & rffi.RFFI_READSAVED_LASTERROR):
        if save_err & rffi.RFFI_ALT_ERRNO:
            err = rthread.tlfield_alt_lasterror.getraw()
        else:
            err = rthread.tlfield_rpy_lasterror.getraw()
        # careful, getraw() overwrites GetLastError.
        # We must assign it with _SetLastError() as the last
        # operation, i.e. after the errno handling.
        rwin32._SetLastError(err)

@specialize.call_location()
def _errno_after(save_err):
    if _WIN32:
        if save_err & rffi.RFFI_SAVE_LASTERROR:
            err = rwin32._GetLastError()
            # careful, setraw() overwrites GetLastError.
            # We must read it first, before the errno handling.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rthread.tlfield_alt_lasterror.setraw(err)
            else:
                rthread.tlfield_rpy_lasterror.setraw(err)
        elif save_err & rffi.RFFI_SAVE_WSALASTERROR:
            from rpython.rlib import _rsocket_rffi
            err = _rsocket_rffi._WSAGetLastError()
            if save_err & rffi.RFFI_ALT_ERRNO:
                rthread.tlfield_alt_lasterror.setraw(err)
            else:
                rthread.tlfield_rpy_lasterror.setraw(err)
    if save_err & rffi.RFFI_SAVE_ERRNO:
        if save_err & rffi.RFFI_ALT_ERRNO:
            rthread.tlfield_alt_errno.setraw(_get_errno())
        else:
            rthread.tlfield_rpy_errno.setraw(_get_errno())
            # ^^^ keep fork() up-to-date too, below
if _WIN32:
    includes = ['io.h', 'sys/utime.h', 'sys/types.h', 'process.h', 'time.h',
                'direct.h', 'Windows.h']
    libraries = []
else:
    if sys.platform.startswith(('darwin', 'netbsd', 'openbsd')):
        _ptyh = 'util.h'
    elif sys.platform.startswith('freebsd'):
        _ptyh = 'libutil.h'
    else:
        _ptyh = 'pty.h'
    includes = ['unistd.h',  'sys/types.h', 'sys/wait.h',
                'utime.h', 'sys/time.h', 'sys/times.h',
                'sys/resource.h',
                'sched.h',
                'grp.h', 'dirent.h', 'sys/stat.h', 'fcntl.h',
                'signal.h', 'sys/utsname.h', _ptyh]
    if sys.platform.startswith('linux') or sys.platform.startswith('gnu'):
        includes.append('sys/sysmacros.h')
    if sys.platform.startswith('freebsd') or sys.platform.startswith('openbsd'):
        includes.append('sys/ttycom.h')
    libraries = ['util']

eci = ExternalCompilationInfo(
    includes=includes,
    libraries=libraries,
)

def external(name, args, result, compilation_info=eci, **kwds):
    return rffi.llexternal(name, args, result,
                           compilation_info=compilation_info, **kwds)


if os.name == 'nt':
    # is_valid_fd is useful only on MSVC9, and should be deprecated. With it
    c_enter_suppress_iph = jit.dont_look_inside(external("enter_suppress_iph",
                                  [], rffi.VOIDP, compilation_info=errno_eci))
    c_exit_suppress_iph = jit.dont_look_inside(external("exit_suppress_iph",
                                  [rffi.VOIDP], lltype.Void,
                                  compilation_info=errno_eci))
    c_enter_suppress_iph_del = jit.dont_look_inside(external("enter_suppress_iph",
                                  [], rffi.VOIDP, compilation_info=errno_eci,
                                  releasegil=False))
    c_exit_suppress_iph_del = jit.dont_look_inside(external("exit_suppress_iph",
                                  [rffi.VOIDP], lltype.Void, releasegil=False,
                                  compilation_info=errno_eci))

    class SuppressIPH_del(object):

        def __init__(self):
            pass

        def __enter__(self):
            self.invalid_param_hndlr = c_enter_suppress_iph_del()
            return self

        def __exit__(self, *args):
            c_exit_suppress_iph_del(self.invalid_param_hndlr)

    class SuppressIPH(object):

        def __init__(self):
            pass

        def __enter__(self):
            self.invalid_param_hndlr = c_enter_suppress_iph()
            return self

        def __exit__(self, *args):
            c_exit_suppress_iph(self.invalid_param_hndlr)

else:
    class SuppressIPH(object):

        def __init__(self):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

    SuppressIPH_del = SuppressIPH

def closerange(fd_low, fd_high):
    # this behaves like os.closerange() from Python 2.6.
    for fd in xrange(fd_low, fd_high):
        try:
            with SuppressIPH():
                os.close(fd)
        except OSError:
            pass

class CConfig:
    _compilation_info_ = eci
    SEEK_SET = rffi_platform.DefinedConstantInteger('SEEK_SET')
    SEEK_CUR = rffi_platform.DefinedConstantInteger('SEEK_CUR')
    SEEK_END = rffi_platform.DefinedConstantInteger('SEEK_END')
    PRIO_PROCESS = rffi_platform.DefinedConstantInteger('PRIO_PROCESS')
    PRIO_PGRP = rffi_platform.DefinedConstantInteger('PRIO_PGRP')
    PRIO_USER = rffi_platform.DefinedConstantInteger('PRIO_USER')
    SCHED_FIFO = rffi_platform.DefinedConstantInteger('SCHED_FIFO')
    SCHED_RR = rffi_platform.DefinedConstantInteger('SCHED_RR')
    SCHED_OTHER = rffi_platform.DefinedConstantInteger('SCHED_OTHER')
    SCHED_BATCH = rffi_platform.DefinedConstantInteger('SCHED_BATCH')
    O_NONBLOCK = rffi_platform.DefinedConstantInteger('O_NONBLOCK')
    F_LOCK = rffi_platform.DefinedConstantInteger('F_LOCK')
    F_TLOCK = rffi_platform.DefinedConstantInteger('F_TLOCK')
    F_ULOCK = rffi_platform.DefinedConstantInteger('F_ULOCK')
    F_TEST = rffi_platform.DefinedConstantInteger('F_TEST')
    OFF_T = rffi_platform.SimpleType('off_t')
    OFF_T_SIZE = rffi_platform.SizeOf('off_t')

    HAVE_UTIMES = rffi_platform.Has('utimes')
    HAVE_D_TYPE = rffi_platform.Has('DT_UNKNOWN')
    HAVE_FALLOCATE = rffi_platform.Has('posix_fallocate')
    HAVE_FADVISE = rffi_platform.Has('posix_fadvise')
    UTIMBUF = rffi_platform.Struct('struct %sutimbuf' % UNDERSCORE_ON_WIN32,
                                   [('actime', rffi.INT),
                                    ('modtime', rffi.INT)])
    CLOCK_T = rffi_platform.SimpleType('clock_t', rffi.INT)
    if not _WIN32:
        UID_T = rffi_platform.SimpleType('uid_t', rffi.UINT)
        GID_T = rffi_platform.SimpleType('gid_t', rffi.UINT)
        ID_T = rffi_platform.SimpleType('id_t', rffi.UINT)
        TIOCGWINSZ = rffi_platform.DefinedConstantInteger('TIOCGWINSZ')

        TMS = rffi_platform.Struct(
            'struct tms', [('tms_utime', rffi.INT),
                           ('tms_stime', rffi.INT),
                           ('tms_cutime', rffi.INT),
                           ('tms_cstime', rffi.INT)])

        WINSIZE = rffi_platform.Struct(
            'struct winsize', [('ws_row', rffi.USHORT),
                           ('ws_col', rffi.USHORT),
                           ('ws_xpixel', rffi.USHORT),
                           ('ws_ypixel', rffi.USHORT)])

    GETPGRP_HAVE_ARG = rffi_platform.Has("getpgrp(0)")
    SETPGRP_HAVE_ARG = rffi_platform.Has("setpgrp(0, 0)")

config = rffi_platform.configure(CConfig)
globals().update(config)

# For now we require off_t to be the same size as LONGLONG, which is the
# interface required by callers of functions that thake an argument of type
# off_t.
if not _WIN32:
    assert OFF_T_SIZE == rffi.sizeof(rffi.LONGLONG)

c_dup = external(UNDERSCORE_ON_WIN32 + 'dup', [rffi.INT], rffi.INT,
                 save_err=rffi.RFFI_SAVE_ERRNO)
c_dup2 = external(UNDERSCORE_ON_WIN32 + 'dup2', [rffi.INT, rffi.INT], rffi.INT,
                  save_err=rffi.RFFI_SAVE_ERRNO)
c_open = external(UNDERSCORE_ON_WIN32 + 'open',
                  [rffi.CCHARP, rffi.INT, rffi.MODE_T], rffi.INT,
                  save_err=rffi.RFFI_SAVE_ERRNO)

# Win32 Unicode functions
c_wopen = external(UNDERSCORE_ON_WIN32 + 'wopen',
                   [rffi.CWCHARP, rffi.INT, rffi.MODE_T], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)

#___________________________________________________________________
# Wrappers around posix functions, that accept either strings, or
# instances with a "as_bytes()" method.
# - pypy.modules.posix.interp_posix passes an object containing a unicode path
#   which can encode itself with sys.filesystemencoding.
# - but rpython.rtyper.module.ll_os.py on Windows will replace these functions
#   with other wrappers that directly handle unicode strings.
@specialize.argtype(0)
@signature(types.any(), returns=s_Str0)
def _as_bytes(path):
    assert path is not None
    if isinstance(path, str):
        return path
    elif isinstance(path, unicode):
        # This never happens in PyPy's Python interpreter!
        # Only in raw RPython code that uses unicode strings.
        # We implement python2 behavior: silently convert to ascii.
        return path.encode('ascii')
    else:
        return path.as_bytes()

@specialize.argtype(0)
def _as_bytes0(path):
    """Crashes translation if the path contains NUL characters."""
    res = _as_bytes(path)
    rstring.check_str0(res)
    return res

@specialize.argtype(0)
def _as_unicode(path):
    assert path is not None
    if isinstance(path, unicode):
        return path
    else:
        return path.as_unicode()

@specialize.argtype(0)
def _as_unicode0(path):
    """Crashes translation if the path contains NUL characters."""
    res = _as_unicode(path)
    rstring.check_str0(res)
    return res

@specialize.argtype(0, 1)
def putenv(name, value):
    os.environ[_as_bytes(name)] = _as_bytes(value)

@specialize.argtype(0)
def unsetenv(name):
    del os.environ[_as_bytes(name)]

#___________________________________________________________________
# Implementation of many posix functions.
# They usually check the return value and raise an (RPython) OSError
# with errno.

def replace_os_function(name):
    func = getattr(os, name, None)
    if func is None:
        return lambda f: f
    return register_replacement_for(
        func,
        sandboxed_name='ll_os.ll_os_%s' % name)

@specialize.arg(0)
def handle_posix_error(name, result):
    result = widen(result)
    if result < 0:
        raise OSError(get_saved_errno(), '%s failed' % name)
    return result

def _dup(fd, inheritable=True):
    with SuppressIPH():
        if inheritable:
            res = c_dup(fd)
        else:
            res = c_dup_noninheritable(fd)
        return res

@replace_os_function('dup')
def dup(fd, inheritable=True):
    res = _dup(fd, inheritable)
    return handle_posix_error('dup', res)

@replace_os_function('dup2')
def dup2(fd, newfd, inheritable=True):
    with SuppressIPH():
        if inheritable:
            res = c_dup2(fd, newfd)
        else:
            res = c_dup2_noninheritable(fd, newfd)
        handle_posix_error('dup2', res)

#___________________________________________________________________

@replace_os_function('open')
@specialize.argtype(0)
@enforceargs(NOT_CONSTANT, int, int, typecheck=False)
def open(path, flags, mode):
    if _prefer_unicode(path):
        fd = c_wopen(_as_unicode0(path), flags, mode)
    else:
        fd = c_open(_as_bytes0(path), flags, mode)
    return handle_posix_error('open', fd)

if os.name == 'nt':
    c_read = external('wrap_read',
                  [rffi.INT, rffi.VOIDP, POSIX_SIZE_T], POSIX_SSIZE_T,
                  save_err=rffi.RFFI_SAVE_ERRNO, compilation_info=errno_eci)
    c_write = external('wrap_write',
                   [rffi.INT, rffi.VOIDP, POSIX_SIZE_T], POSIX_SSIZE_T,
                   save_err=rffi.RFFI_SAVE_ERRNO, compilation_info=errno_eci)
else:
    c_read = external('read',
                  [rffi.INT, rffi.VOIDP, POSIX_SIZE_T], POSIX_SSIZE_T,
                  save_err=rffi.RFFI_SAVE_ERRNO)
    c_write = external('write',
                   [rffi.INT, rffi.VOIDP, POSIX_SIZE_T], POSIX_SSIZE_T,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_close = external(UNDERSCORE_ON_WIN32 + 'close', [rffi.INT], rffi.INT,
                   releasegil=False, save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('read')
@signature(types.int(), types.int(), returns=types.any())
def read(fd, count):
    if count < 0:
        raise OSError(errno.EINVAL, None)
    with rffi.scoped_alloc_buffer(count) as buf:
        void_buf = rffi.cast(rffi.VOIDP, buf.raw)
        got = handle_posix_error('read', c_read(fd, void_buf, count))
        return buf.str(got)

@replace_os_function('write')
@signature(types.int(), types.any(), returns=types.any())
def write(fd, data):
    count = len(data)
    with rffi.scoped_nonmovingbuffer(data) as buf:
        ret = c_write(fd, buf, count)
        return handle_posix_error('write', ret)

@replace_os_function('close')
@signature(types.int(), returns=types.any())
def close(fd):
    with SuppressIPH():
        handle_posix_error('close', c_close(fd))

c_lseek = external('_lseeki64' if _WIN32 else 'lseek',
                   [rffi.INT, rffi.LONGLONG, rffi.INT], rffi.LONGLONG,
                   macro=_MACRO_ON_POSIX, save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('lseek')
def lseek(fd, pos, how):
    with SuppressIPH():
        if SEEK_SET is not None:
            if how == 0:
                how = SEEK_SET
            elif how == 1:
                how = SEEK_CUR
            elif how == 2:
                how = SEEK_END
        return handle_posix_error('lseek', c_lseek(fd, pos, how))

if not _WIN32:
    c_pread = external('pread',
                      [rffi.INT, rffi.VOIDP, rffi.SIZE_T , OFF_T], rffi.SSIZE_T,
                      save_err=rffi.RFFI_SAVE_ERRNO)
    c_pwrite = external('pwrite',
                       [rffi.INT, rffi.VOIDP, rffi.SIZE_T, OFF_T], rffi.SSIZE_T,
                       save_err=rffi.RFFI_SAVE_ERRNO)

    @enforceargs(int, int, None)
    def pread(fd, count, offset):
        if count < 0:
            raise OSError(errno.EINVAL, None)
        with rffi.scoped_alloc_buffer(count) as buf:
            void_buf = rffi.cast(rffi.VOIDP, buf.raw)
            return buf.str(handle_posix_error('pread', c_pread(fd, void_buf, count, offset)))

    @enforceargs(int, None, None)
    def pwrite(fd, data, offset):
        count = len(data)
        with rffi.scoped_nonmovingbuffer(data) as buf:
            return handle_posix_error('pwrite', c_pwrite(fd, buf, count, offset))

    if HAVE_FALLOCATE:
        c_posix_fallocate = external('posix_fallocate',
                                     [rffi.INT, OFF_T, OFF_T], rffi.INT,
                                     save_err=rffi.RFFI_SAVE_ERRNO)

        @enforceargs(int, None, None)
        def posix_fallocate(fd, offset, length):
            return handle_posix_error('posix_fallocate', c_posix_fallocate(fd, offset, length))

    if HAVE_FADVISE:
        class CConfig:
            _compilation_info_ = eci
            POSIX_FADV_WILLNEED = rffi_platform.DefinedConstantInteger('POSIX_FADV_WILLNEED')
            POSIX_FADV_NORMAL = rffi_platform.DefinedConstantInteger('POSIX_FADV_NORMAL')
            POSIX_FADV_SEQUENTIAL = rffi_platform.DefinedConstantInteger('POSIX_FADV_SEQUENTIAL')
            POSIX_FADV_RANDOM= rffi_platform.DefinedConstantInteger('POSIX_FADV_RANDOM')
            POSIX_FADV_NOREUSE = rffi_platform.DefinedConstantInteger('POSIX_FADV_NOREUSE')
            POSIX_FADV_DONTNEED = rffi_platform.DefinedConstantInteger('POSIX_FADV_DONTNEED')

        config = rffi_platform.configure(CConfig)
        globals().update(config)

        c_posix_fadvise = external('posix_fadvise',
                                   [rffi.INT, OFF_T, OFF_T, rffi.INT], rffi.INT,
                                   save_err=rffi.RFFI_SAVE_ERRNO)

        @enforceargs(int, None, None, int)
        def posix_fadvise(fd, offset, length, advice):
            error = c_posix_fadvise(fd, offset, length, advice)
            error = widen(error)
            if error != 0:
                raise OSError(error, 'posix_fadvise failed')

    c_lockf = external('lockf',
            [rffi.INT, rffi.INT , OFF_T], rffi.INT,
            save_err=rffi.RFFI_SAVE_ERRNO)
    @enforceargs(int, None, None)
    def lockf(fd, cmd, length):
        return handle_posix_error('lockf', c_lockf(fd, cmd, length))

c_fsync = external('fsync' if not _WIN32 else '_commit', [rffi.INT], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_fdatasync = external('fdatasync', [rffi.INT], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)
if _WIN32:
    c_ftruncate = external('_chsize_s', [rffi.INT, rffi.LONGLONG], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)
else:
    c_sync = external('sync', [], lltype.Void)
    c_ftruncate = external('ftruncate', [rffi.INT, rffi.LONGLONG], rffi.INT,
                       macro=_MACRO_ON_POSIX, save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('ftruncate')
def ftruncate(fd, length):
    with SuppressIPH():
        handle_posix_error('ftruncate', c_ftruncate(fd, length))

@replace_os_function('fsync')
def fsync(fd):
    with SuppressIPH():
        handle_posix_error('fsync', c_fsync(fd))

@replace_os_function('fdatasync')
def fdatasync(fd):
    handle_posix_error('fdatasync', c_fdatasync(fd))

def sync():
    c_sync()

#___________________________________________________________________

c_chdir = external('chdir', [rffi.CCHARP], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_fchdir = external('fchdir', [rffi.INT], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_access = external(UNDERSCORE_ON_WIN32 + 'access',
                    [rffi.CCHARP, rffi.INT], rffi.INT)
c_waccess = external(UNDERSCORE_ON_WIN32 + 'waccess',
                     [rffi.CWCHARP, rffi.INT], rffi.INT)

@replace_os_function('chdir')
@specialize.argtype(0)
def chdir(path):
    if not _WIN32:
        handle_posix_error('chdir', c_chdir(_as_bytes0(path)))
    else:
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        path = traits.as_str0(path)

        # This is a reimplementation of the C library's chdir
        # function, but one that produces Win32 errors instead of DOS
        # error codes.
        # chdir is essentially a wrapper around SetCurrentDirectory;
        # however, it also needs to set "magic" environment variables
        # indicating the per-drive current directory, which are of the
        # form =<drive>:
        if not win32traits.SetCurrentDirectory(path):
            raise rwin32.lastSavedWindowsError()
        MAX_PATH = rwin32.MAX_PATH
        assert MAX_PATH > 0

        with traits.scoped_alloc_buffer(MAX_PATH) as path:
            res = win32traits.GetCurrentDirectory(MAX_PATH + 1, path.raw)
            if not res:
                raise rwin32.lastSavedWindowsError()
            res = rffi.cast(lltype.Signed, res)
            assert res > 0
            if res <= MAX_PATH + 1:
                new_path = path.str(res)
            else:
                with traits.scoped_alloc_buffer(res) as path:
                    res = win32traits.GetCurrentDirectory(res, path.raw)
                    if not res:
                        raise rwin32.lastSavedWindowsError()
                    res = rffi.cast(lltype.Signed, res)
                    assert res > 0
                    new_path = path.str(res)
        if traits.str is unicode:
            if new_path[0] == u'\\' or new_path[0] == u'/':  # UNC path
                return
            magic_envvar = u'=' + new_path[0] + u':'
        else:
            if new_path[0] == '\\' or new_path[0] == '/':  # UNC path
                return
            magic_envvar = '=' + new_path[0] + ':'
        if not win32traits.SetEnvironmentVariable(magic_envvar, new_path):
            raise rwin32.lastSavedWindowsError()

@replace_os_function('fchdir')
def fchdir(fd):
    handle_posix_error('fchdir', c_fchdir(fd))

@replace_os_function('access')
@specialize.argtype(0)
def access(path, mode):
    if _WIN32:
        # All files are executable on Windows
        mode = mode & ~os.X_OK
    if _prefer_unicode(path):
        error = c_waccess(_as_unicode0(path), mode)
    else:
        error = c_access(_as_bytes0(path), mode)
    return error == 0

# This Win32 function is not exposed via os, but needed to get a
# correct implementation of os.path.abspath.
@specialize.argtype(0)
def getfullpathname(path):
    length = rwin32.MAX_PATH + 1
    traits = _preferred_traits(path)
    win32traits = make_win32_traits(traits)
    while True:      # should run the loop body maximum twice
        with traits.scoped_alloc_buffer(length) as buf:
            res = win32traits.GetFullPathName(
                traits.as_str0(path), rffi.cast(rwin32.DWORD, length),
                buf.raw, lltype.nullptr(win32traits.LPSTRP.TO))
            res = intmask(res)
            if res == 0:
                raise rwin32.lastSavedWindowsError("_getfullpathname failed")
            if res >= length:
                length = res + 1
                continue
            result = buf.str(res)
            assert result is not None
            result = rstring.assert_str0(result)
            return result

c_getcwd = external(UNDERSCORE_ON_WIN32 + 'getcwd',
                    [rffi.CCHARP, rffi.SIZE_T], rffi.CCHARP,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_wgetcwd = external(UNDERSCORE_ON_WIN32 + 'wgetcwd',
                     [rffi.CWCHARP, rffi.SIZE_T], rffi.CWCHARP,
                     save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('getcwd')
def getcwd():
    bufsize = 256
    while True:
        buf = lltype.malloc(rffi.CCHARP.TO, bufsize, flavor='raw')
        res = c_getcwd(buf, bufsize)
        if res:
            break   # ok
        error = get_saved_errno()
        lltype.free(buf, flavor='raw')
        if error != errno.ERANGE:
            raise OSError(error, "getcwd failed")
        # else try again with a larger buffer, up to some sane limit
        bufsize *= 4
        if bufsize > 1024*1024:  # xxx hard-coded upper limit
                                 #     must be <2**31 for win32
            raise OSError(error, "getcwd result too large")
    result = rffi.charp2str(res)
    lltype.free(buf, flavor='raw')
    return result

@replace_os_function('getcwdu')
def getcwdu():
    bufsize = 256
    while True:
        buf = lltype.malloc(rffi.CWCHARP.TO, bufsize, flavor='raw')
        res = c_wgetcwd(buf, bufsize)
        if res:
            break   # ok
        error = get_saved_errno()
        lltype.free(buf, flavor='raw')
        if error != errno.ERANGE:
            raise OSError(error, "getcwd failed")
        # else try again with a larger buffer, up to some sane limit
        bufsize *= 4
        if bufsize > 1024*1024:  # xxx hard-coded upper limit
                                 #     must be <2**31 for win32
            raise OSError(error, "getcwd result too large")
    result = rffi.wcharp2unicode(res)
    lltype.free(buf, flavor='raw')
    return result

if not _WIN32:
    class CConfig:
        _compilation_info_ = eci
        DIRENT = rffi_platform.Struct('struct dirent',
            [('d_name', lltype.FixedSizeArray(rffi.CHAR, 1)),
             ('d_ino', lltype.Signed)]
            + ([('d_type', rffi.INT)] if HAVE_D_TYPE else []))
        if HAVE_D_TYPE:
            DT_UNKNOWN = rffi_platform.ConstantInteger('DT_UNKNOWN')
            DT_REG     = rffi_platform.ConstantInteger('DT_REG')
            DT_DIR     = rffi_platform.ConstantInteger('DT_DIR')
            DT_LNK     = rffi_platform.ConstantInteger('DT_LNK')

    DIRP = rffi.COpaquePtr('DIR')
    dirent_config = rffi_platform.configure(CConfig)
    DIRENT = dirent_config['DIRENT']
    DIRENTP = lltype.Ptr(DIRENT)
    c_opendir = external('opendir',
        [rffi.CCHARP], DIRP, save_err=rffi.RFFI_SAVE_ERRNO)
    c_fdopendir = external('fdopendir',
        [rffi.INT], DIRP, save_err=rffi.RFFI_SAVE_ERRNO)
    c_rewinddir = external('rewinddir',
        [DIRP], lltype.Void, releasegil=False)
    # XXX macro=True is hack to make sure we get the correct kind of
    # dirent struct (which depends on defines)
    c_readdir = external('readdir', [DIRP], DIRENTP,
                         macro=True, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_closedir = external('closedir', [DIRP], rffi.INT, releasegil=False)
    c_dirfd = external('dirfd', [DIRP], rffi.INT, releasegil=False,
                       macro=True)
    c_ioctl_voidp = external('ioctl', [rffi.INT, rffi.UINT, rffi.VOIDP], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
else:
    dirent_config = {}

def _listdir(dirp, rewind=False):
    result = []
    while True:
        direntp = c_readdir(dirp)
        if not direntp:
            error = get_saved_errno()
            break
        namep = rffi.cast(rffi.CCHARP, direntp.c_d_name)
        name = rffi.charp2str(namep)
        if name != '.' and name != '..':
            result.append(name)
    if rewind:
        c_rewinddir(dirp)
    c_closedir(dirp)
    if error:
        raise OSError(error, "readdir failed")
    return result

if not _WIN32:
    def fdlistdir(dirfd):
        """
        Like listdir(), except that the directory is specified as an open
        file descriptor.

        Note: fdlistdir() closes the file descriptor.  To emulate the
        Python 3.x 'os.opendir(dirfd)', you must first duplicate the
        file descriptor.
        """
        dirp = c_fdopendir(dirfd)
        if not dirp:
            error = get_saved_errno()
            c_close(dirfd)
            raise OSError(error, "opendir failed")
        return _listdir(dirp, rewind=True)

@replace_os_function('listdir')
@specialize.argtype(0)
def listdir(path):
    if not _WIN32:
        path = _as_bytes0(path)
        dirp = c_opendir(path)
        if not dirp:
            raise OSError(get_saved_errno(), "opendir failed")
        return _listdir(dirp)
    else:  # _WIN32 case
        if not path:
            traits = _preferred_traits('')
            win32traits = make_win32_traits(traits)
            raise OSError(win32traits.ERROR_FILE_NOT_FOUND,
                         "listdir called with invalid path")
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        path = traits.as_str0(path)

        if traits.str is unicode:
            if path and path[-1] not in (u'/', u'\\', u':'):
                path += u'\\'
            mask = path + u'*.*'
        else:
            if path and path[-1] not in ('/', '\\', ':'):
                path += '\\'
            mask = path + '*.*'

        filedata = lltype.malloc(win32traits.WIN32_FIND_DATA, flavor='raw')
        try:
            result = []
            hFindFile = win32traits.FindFirstFile(mask, filedata)
            if hFindFile == rwin32.INVALID_HANDLE_VALUE:
                error = rwin32.GetLastError_saved()
                if error == win32traits.ERROR_FILE_NOT_FOUND:
                    return result
                else:
                    raise WindowsError(error,  "FindFirstFile failed")
            while True:
                name = traits.charp2str(rffi.cast(traits.CCHARP,
                                                  filedata.c_cFileName))
                if traits.str is unicode:
                    if not (name == u"." or name == u".."):
                        result.append(name)
                else:
                    if not (name == "." or name == ".."):
                        result.append(name)
                if not win32traits.FindNextFile(hFindFile, filedata):
                    break
            # FindNextFile sets error to ERROR_NO_MORE_FILES if
            # it got to the end of the directory
            error = rwin32.GetLastError_saved()
            win32traits.FindClose(hFindFile)
            if error == win32traits.ERROR_NO_MORE_FILES:
                return result
            else:
                raise WindowsError(error,  "FindNextFile failed")
        finally:
            lltype.free(filedata, flavor='raw')

#___________________________________________________________________

c_execv = external('execv', [rffi.CCHARP, rffi.CCHARPP], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_execve = external('execve',
                    [rffi.CCHARP, rffi.CCHARPP, rffi.CCHARPP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_spawnv = external(UNDERSCORE_ON_WIN32 + 'spawnv',
                    [rffi.INT, rffi.CCHARP, rffi.CCHARPP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_spawnve = external(UNDERSCORE_ON_WIN32 + 'spawnve',
                    [rffi.INT, rffi.CCHARP, rffi.CCHARPP, rffi.CCHARPP],
                     rffi.INT,
                     save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('execv')
def execv(path, args):
    rstring.check_str0(path)
    # This list conversion already takes care of NUL bytes.
    l_args = rffi.ll_liststr2charpp(args)
    c_execv(path, l_args)
    rffi.free_charpp(l_args)
    raise OSError(get_saved_errno(), "execv failed")

@replace_os_function('execve')
def execve(path, args, env):
    envstrs = []
    for item in env.iteritems():
        envstr = "%s=%s" % item
        envstrs.append(envstr)

    rstring.check_str0(path)
    # This list conversion already takes care of NUL bytes.
    l_args = rffi.ll_liststr2charpp(args)
    l_env = rffi.ll_liststr2charpp(envstrs)
    c_execve(path, l_args, l_env)

    rffi.free_charpp(l_env)
    rffi.free_charpp(l_args)
    raise OSError(get_saved_errno(), "execve failed")

@replace_os_function('spawnv')
def spawnv(mode, path, args):
    rstring.check_str0(path)
    l_args = rffi.ll_liststr2charpp(args)
    childpid = c_spawnv(mode, path, l_args)
    rffi.free_charpp(l_args)
    return handle_posix_error('spawnv', childpid)

@replace_os_function('spawnve')
def spawnve(mode, path, args, env):
    envstrs = []
    for item in env.iteritems():
        envstrs.append("%s=%s" % item)
    rstring.check_str0(path)
    l_args = rffi.ll_liststr2charpp(args)
    l_env = rffi.ll_liststr2charpp(envstrs)
    childpid = c_spawnve(mode, path, l_args, l_env)
    rffi.free_charpp(l_env)
    rffi.free_charpp(l_args)
    return handle_posix_error('spawnve', childpid)

c_fork = external('fork', [], rffi.PID_T, _nowrapper = True)
c_openpty = external('openpty',
                     [rffi.INTP, rffi.INTP, rffi.VOIDP, rffi.VOIDP, rffi.VOIDP],
                     rffi.INT,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_forkpty = external('forkpty',
                     [rffi.INTP, rffi.VOIDP, rffi.VOIDP, rffi.VOIDP],
                     rffi.PID_T, _nowrapper = True)

@replace_os_function('fork')
@jit.dont_look_inside
def fork():
    # NB. keep forkpty() up-to-date, too
    # lots of custom logic here, to do things in the right order
    ofs = debug.debug_offset()
    opaqueaddr = rthread.gc_thread_before_fork()
    childpid = c_fork()
    errno = _get_errno()
    rthread.gc_thread_after_fork(childpid, opaqueaddr)
    rthread.tlfield_rpy_errno.setraw(errno)
    childpid = handle_posix_error('fork', childpid)
    if childpid == 0:
        debug.debug_forked(ofs)
    return childpid

@replace_os_function('openpty')
@jit.dont_look_inside
def openpty():
    master_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
    slave_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
    try:
        handle_posix_error(
            'openpty', c_openpty(master_p, slave_p, None, None, None))
        return (widen(master_p[0]), widen(slave_p[0]))
    finally:
        lltype.free(master_p, flavor='raw')
        lltype.free(slave_p, flavor='raw')

@replace_os_function('forkpty')
@jit.dont_look_inside
def forkpty():
    master_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
    master_p[0] = rffi.cast(rffi.INT, -1)
    null = lltype.nullptr(rffi.VOIDP.TO)
    try:
        ofs = debug.debug_offset()
        opaqueaddr = rthread.gc_thread_before_fork()
        childpid = c_forkpty(master_p, null, null, null)
        errno = _get_errno()
        rthread.gc_thread_after_fork(childpid, opaqueaddr)
        rthread.tlfield_rpy_errno.setraw(errno)
        childpid = handle_posix_error('forkpty', childpid)
        if childpid == 0:
            debug.debug_forked(ofs)
        return (childpid, master_p[0])
    finally:
        lltype.free(master_p, flavor='raw')

if _WIN32:
    # emulate waitpid() with the _cwait() of Microsoft's compiler
    c__cwait = external('_cwait',
                        [rffi.INTP, rffi.PID_T, rffi.INT], rffi.PID_T,
                        save_err=rffi.RFFI_SAVE_ERRNO)
    @jit.dont_look_inside
    def c_waitpid(pid, status_p, options):
        result = c__cwait(status_p, pid, options)
        # shift the status left a byte so this is more
        # like the POSIX waitpid
        status_p[0] = rffi.cast(rffi.INT, widen(status_p[0]) << 8)
        return result
elif _CYGWIN:
    c_waitpid = external('cygwin_waitpid',
                         [rffi.PID_T, rffi.INTP, rffi.INT], rffi.PID_T,
                         save_err=rffi.RFFI_SAVE_ERRNO)
else:
    c_waitpid = external('waitpid',
                         [rffi.PID_T, rffi.INTP, rffi.INT], rffi.PID_T,
                         save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('waitpid')
def waitpid(pid, options):
    status_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
    status_p[0] = rffi.cast(rffi.INT, 0)
    try:
        result = handle_posix_error('waitpid',
                                    c_waitpid(pid, status_p, options))
        status = widen(status_p[0])
        return (result, status)
    finally:
        lltype.free(status_p, flavor='raw')

def _make_waitmacro(name):
    # note that rffi.INT as first parameter type is intentional.
    # on s390x providing a lltype.Signed as param type, the
    # macro wrapper function will always return 0
    # reason: legacy code required a union wait. see
    # https://sourceware.org/bugzilla/show_bug.cgi?id=19613
    # for more details. If this get's fixed we can use lltype.Signed
    # again.  (The exact same issue occurs on ppc64 big-endian.)
    c_func = external(name, [rffi.INT], lltype.Signed,
                      macro=_MACRO_ON_POSIX)
    returning_int = name in ('WEXITSTATUS', 'WSTOPSIG', 'WTERMSIG')

    @replace_os_function(name)
    @func_renamer(name)
    def _waitmacro(status):
        if returning_int:
            return c_func(status)
        else:
            return bool(c_func(status))

WAIT_MACROS = ['WCOREDUMP', 'WIFSTOPPED',
               'WIFSIGNALED', 'WIFEXITED',
               'WEXITSTATUS', 'WSTOPSIG', 'WTERMSIG']
if not sys.platform.startswith('gnu'):
    WAIT_MACROS.append('WIFCONTINUED')

for name in WAIT_MACROS:
    _make_waitmacro(name)

#___________________________________________________________________

c_getlogin = external('getlogin', [], rffi.CCHARP,
                      releasegil=False, save_err=rffi.RFFI_SAVE_ERRNO)
c_getloadavg = external('getloadavg',
                        [rffi.CArrayPtr(lltype.Float), rffi.INT], rffi.INT)

@replace_os_function('getlogin')
def getlogin():
    result = c_getlogin()
    if not result:
        raise OSError(get_saved_errno(), "getlogin failed")
    return rffi.charp2str(result)

@replace_os_function('getloadavg')
def getloadavg():
    load = lltype.malloc(rffi.CArrayPtr(lltype.Float).TO, 3, flavor='raw')
    try:
        r = c_getloadavg(load, 3)
        if r != 3:
            raise OSError
        return (load[0], load[1], load[2])
    finally:
        lltype.free(load, flavor='raw')

#___________________________________________________________________

c_readlink = external('readlink',
                      [rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T], rffi.SSIZE_T,
                      save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('readlink')
def readlink(path):
    path = _as_bytes0(path)
    bufsize = 1023
    while True:
        buf = lltype.malloc(rffi.CCHARP.TO, bufsize, flavor='raw')
        res = widen(c_readlink(path, buf, bufsize))
        if res < 0:
            lltype.free(buf, flavor='raw')
            error = get_saved_errno()    # failed
            raise OSError(error, "readlink failed")
        elif res < bufsize:
            break                       # ok
        else:
            # buf too small, try again with a larger buffer
            lltype.free(buf, flavor='raw')
            bufsize *= 4
    # convert the result to a string
    result = rffi.charp2strn(buf, res)
    lltype.free(buf, flavor='raw')
    return result

c_isatty = external(UNDERSCORE_ON_WIN32 + 'isatty', [rffi.INT], rffi.INT)

@replace_os_function('isatty')
def isatty(fd):
    with SuppressIPH():
        return c_isatty(fd) != 0
    return False

c_ttyname = external('ttyname', [lltype.Signed], rffi.CCHARP,
                     releasegil=False,
                     save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('ttyname')
def ttyname(fd):
    l_name = c_ttyname(fd)
    if not l_name:
        raise OSError(get_saved_errno(), "ttyname raised")
    return rffi.charp2str(l_name)

c_strerror = external('strerror', [rffi.INT], rffi.CCHARP,
                      releasegil=False)

@replace_os_function('strerror')
def strerror(errnum):
    res = c_strerror(errnum)
    if not res:
        raise ValueError("os_strerror failed")
    return rffi.charp2str(res)

c_system = external('system', [rffi.CCHARP], rffi.INT)

@replace_os_function('system')
def system(command):
    return widen(c_system(command))

c_unlink = external('unlink', [rffi.CCHARP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_mkdir = external('mkdir', [rffi.CCHARP, rffi.MODE_T], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_rmdir = external(UNDERSCORE_ON_WIN32 + 'rmdir', [rffi.CCHARP], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_wrmdir = external(UNDERSCORE_ON_WIN32 + 'wrmdir', [rffi.CWCHARP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('unlink')
@specialize.argtype(0)
def unlink(path):
    if not _WIN32:
        handle_posix_error('unlink', c_unlink(_as_bytes0(path)))
    else:
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        if not win32traits.DeleteFile(traits.as_str0(path)):
            raise rwin32.lastSavedWindowsError()

@replace_os_function('mkdir')
@specialize.argtype(0)
def mkdir(path, mode=0o777):
    if not _WIN32:
        handle_posix_error('mkdir', c_mkdir(_as_bytes0(path), mode))
    else:
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        if not win32traits.CreateDirectory(traits.as_str0(path), None):
            raise rwin32.lastSavedWindowsError()

@replace_os_function('rmdir')
@specialize.argtype(0)
@jit.dont_look_inside
def rmdir(path):
    if _prefer_unicode(path):
        handle_posix_error('wrmdir', c_wrmdir(_as_unicode0(path)))
    else:
        handle_posix_error('rmdir', c_rmdir(_as_bytes0(path)))

c_chmod = external('chmod', [rffi.CCHARP, rffi.MODE_T], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_fchmod = external('fchmod', [rffi.INT, rffi.MODE_T], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO,)
c_rename = external('rename', [rffi.CCHARP, rffi.CCHARP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('chmod')
@specialize.argtype(0)
def chmod(path, mode):
    if not _WIN32:
        handle_posix_error('chmod', c_chmod(_as_bytes0(path), mode))
    else:
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        path = traits.as_str0(path)
        attr = win32traits.GetFileAttributes(path)
        if attr == win32traits.INVALID_FILE_ATTRIBUTES:
            raise rwin32.lastSavedWindowsError()
        if mode & 0200: # _S_IWRITE
            attr &= ~win32traits.FILE_ATTRIBUTE_READONLY
        else:
            attr |= win32traits.FILE_ATTRIBUTE_READONLY
        if not win32traits.SetFileAttributes(path, attr):
            raise rwin32.lastSavedWindowsError()

@replace_os_function('fchmod')
def fchmod(fd, mode):
    handle_posix_error('fchmod', c_fchmod(fd, mode))

@replace_os_function('rename')
@specialize.argtype(0, 1)
def rename(path1, path2):
    if _WIN32:
        traits = _preferred_traits2(path1, path2)
        win32traits = make_win32_traits(traits)
        path1 = traits.as_str0(path1)
        path2 = traits.as_str0(path2)
        if not win32traits.MoveFileEx(path1, path2, 0):
            raise rwin32.lastSavedWindowsError()
    else:
        handle_posix_error('rename',
                           c_rename(_as_bytes0(path1), _as_bytes0(path2)))

@specialize.argtype(0, 1)
def replace(path1, path2):
    if _WIN32:
        traits = _preferred_traits2(path1, path2)
        win32traits = make_win32_traits(traits)
        path1 = traits.as_str0(path1)
        path2 = traits.as_str0(path2)
        ret = win32traits.MoveFileEx(path1, path2,
                     win32traits.MOVEFILE_REPLACE_EXISTING)
        if not ret:
            raise rwin32.lastSavedWindowsError()
    else:
        ret = rename(path1, path2)
    return ret

#___________________________________________________________________

c_mkfifo = external('mkfifo', [rffi.CCHARP, rffi.MODE_T], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_mknod = external('mknod', [rffi.CCHARP, rffi.MODE_T, rffi.INT], rffi.INT,
#                                           # xxx: actually ^^^ dev_t
                   macro=_MACRO_ON_POSIX, save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('mkfifo')
@specialize.argtype(0)
def mkfifo(path, mode):
    handle_posix_error('mkfifo', c_mkfifo(_as_bytes0(path), mode))

@replace_os_function('mknod')
@specialize.argtype(0)
def mknod(path, mode, dev):
    handle_posix_error('mknod', c_mknod(_as_bytes0(path), mode, dev))

constants =[ # These are added to posix/nt
             # windows
             'LOAD_LIBRARY_SEARCH_DEFAULT_DIRS',
             'LOAD_LIBRARY_SEARCH_APPLICATION_DIR',
             'LOAD_LIBRARY_SEARCH_SYSTEM32',
             'LOAD_LIBRARY_SEARCH_USER_DIRS',
             'LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR',
             # darwin
             'COPYFILE_DATA',
             # linux, darwin
             'O_CLOEXEC',
            ]
darwin_constants = ['COPYFILE_DATA']
if _WIN32:
    CreatePipe = external('CreatePipe', [rwin32.LPHANDLE,
                                         rwin32.LPHANDLE,
                                         rffi.VOIDP,
                                         rwin32.DWORD],
                          rwin32.BOOL)
    c_open_osfhandle = external('_open_osfhandle', [rffi.INTPTR_T,
                                                    rffi.INT],
                                rffi.INT)
    HAVE_PIPE2 = False
    HAVE_DUP3 = False
    class CConfig:
        _compilation_info_ = eci
    for name in constants:
        setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))
    config = rffi_platform.configure(CConfig)
    for name in constants:
        locals()[name] = config[name]
else:
    INT_ARRAY_P = rffi.CArrayPtr(rffi.INT)
    c_pipe = external('pipe', [INT_ARRAY_P], rffi.INT,
                      save_err=rffi.RFFI_SAVE_ERRNO)
    class CConfig:
        _compilation_info_ = eci
        HAVE_PIPE2 = rffi_platform.Has('pipe2')
        HAVE_DUP3 = rffi_platform.Has('dup3')
    for name in constants:
        setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))
    config = rffi_platform.configure(CConfig)
    for name in constants:
        locals()[name] = config[name]
    HAVE_PIPE2 = config['HAVE_PIPE2']
    HAVE_DUP3 = config['HAVE_DUP3']
    if HAVE_PIPE2:
        c_pipe2 = external('pipe2', [INT_ARRAY_P, rffi.INT], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('pipe')
def pipe(flags=0):
    # 'flags' might be ignored.  Check the result.
    # The handles returned are always inheritable on Posix.
    # The situation on Windows is not completely clear: I think
    # it should always return non-inheritable handles, but CPython
    # uses SECURITY_ATTRIBUTES to ensure that and we don't.
    if _WIN32:
        # 'flags' ignored
        ralloc = lltype.scoped_alloc(rwin32.LPHANDLE.TO, 1)
        walloc = lltype.scoped_alloc(rwin32.LPHANDLE.TO, 1)
        with ralloc as pread, walloc as pwrite:
            if CreatePipe(pread, pwrite, lltype.nullptr(rffi.VOIDP.TO), 0):
                hread = pread[0]
                hwrite = pwrite[0]
                fdread = c_open_osfhandle(rffi.cast(rffi.INTPTR_T, hread), 0)
                fdwrite = c_open_osfhandle(rffi.cast(rffi.INTPTR_T, hwrite), 1)
                if not (fdread == -1 or fdwrite == -1):
                    return (fdread, fdwrite)
                rwin32.CloseHandle(hread)
                rwin32.CloseHandle(hwrite)
        raise WindowsError(rwin32.GetLastError_saved(), "CreatePipe failed")
    else:
        filedes = lltype.malloc(INT_ARRAY_P.TO, 2, flavor='raw')
        try:
            if HAVE_PIPE2 and _pipe2_syscall.attempt_syscall():
                res = c_pipe2(filedes, flags)
                if _pipe2_syscall.fallback(res):
                    res = c_pipe(filedes)
            else:
                res = c_pipe(filedes)      # 'flags' ignored
            handle_posix_error('pipe', res)
            return (widen(filedes[0]), widen(filedes[1]))
        finally:
            lltype.free(filedes, flavor='raw')

def pipe2(flags):
    # Only available if there is really a c_pipe2 function.
    # No fallback to pipe() if we get ENOSYS.
    filedes = lltype.malloc(INT_ARRAY_P.TO, 2, flavor='raw')
    try:
        res = c_pipe2(filedes, flags)
        handle_posix_error('pipe2', res)
        return (widen(filedes[0]), widen(filedes[1]))
    finally:
        lltype.free(filedes, flavor='raw')

c_link = external('link', [rffi.CCHARP, rffi.CCHARP], rffi.INT,
                  save_err=rffi.RFFI_SAVE_ERRNO,)
c_symlink = external('symlink', [rffi.CCHARP, rffi.CCHARP], rffi.INT,
                     save_err=rffi.RFFI_SAVE_ERRNO)

#___________________________________________________________________

@replace_os_function('link')
@specialize.argtype(0, 1)
def link(oldpath, newpath):
    if not _WIN32:
        oldpath = _as_bytes0(oldpath)
        newpath = _as_bytes0(newpath)
        handle_posix_error('link', c_link(oldpath, newpath))
    else:
        traits = _preferred_traits(oldpath)
        win32traits = make_win32_traits(traits)
        oldpath = traits.as_str0(oldpath)
        newpath = traits.as_str0(newpath)
        if not win32traits.CreateHardLink(newpath, oldpath, None):
            raise rwin32.lastSavedWindowsError()

@replace_os_function('symlink')
@specialize.argtype(0, 1)
def symlink(oldpath, newpath):
    oldpath = _as_bytes0(oldpath)
    newpath = _as_bytes0(newpath)
    handle_posix_error('symlink', c_symlink(oldpath, newpath))

c_umask = external(UNDERSCORE_ON_WIN32 + 'umask', [rffi.MODE_T], rffi.MODE_T)

@replace_os_function('umask')
def umask(newmask):
    return widen(c_umask(newmask))

c_chown = external('chown', [rffi.CCHARP, rffi.INT, rffi.INT], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
c_lchown = external('lchown', [rffi.CCHARP, rffi.INT, rffi.INT], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_fchown = external('fchown', [rffi.INT, rffi.INT, rffi.INT], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('chown')
def chown(path, uid, gid):
    handle_posix_error('chown', c_chown(path, uid, gid))

@replace_os_function('lchown')
def lchown(path, uid, gid):
    handle_posix_error('lchown', c_lchown(path, uid, gid))

@replace_os_function('fchown')
def fchown(fd, uid, gid):
    handle_posix_error('fchown', c_fchown(fd, uid, gid))

#___________________________________________________________________

UTIMBUFP = lltype.Ptr(UTIMBUF)
c_utime = external('utime', [rffi.CCHARP, UTIMBUFP], rffi.INT,
                   save_err=rffi.RFFI_SAVE_ERRNO)
if HAVE_UTIMES:
    class CConfig:
        _compilation_info_ = eci
        TIMEVAL = rffi_platform.Struct('struct timeval', [
            ('tv_sec', rffi.LONG),
            ('tv_usec', rffi.LONG)])
    config = rffi_platform.configure(CConfig)
    TIMEVAL = config['TIMEVAL']
    TIMEVAL2P = rffi.CArrayPtr(TIMEVAL)
    c_utimes = external('utimes', [rffi.CCHARP, TIMEVAL2P], rffi.INT,
                        save_err=rffi.RFFI_SAVE_ERRNO)

if _WIN32:
    from rpython.rlib import rwin32
    GetSystemTime = external(
        'GetSystemTime',
        [lltype.Ptr(rwin32.SYSTEMTIME)],
        lltype.Void,
        calling_conv='win',
        save_err=rffi.RFFI_SAVE_LASTERROR)

    SystemTimeToFileTime = external(
        'SystemTimeToFileTime',
        [lltype.Ptr(rwin32.SYSTEMTIME),
         lltype.Ptr(rwin32.FILETIME)],
        rwin32.BOOL,
        calling_conv='win',
        save_err=rffi.RFFI_SAVE_LASTERROR)

    SetFileTime = external(
        'SetFileTime',
        [rwin32.HANDLE,
         lltype.Ptr(rwin32.FILETIME),
         lltype.Ptr(rwin32.FILETIME),
         lltype.Ptr(rwin32.FILETIME)],
        rwin32.BOOL,
        calling_conv='win')


@replace_os_function('utime')
@specialize.argtype(0, 1)
def utime(path, times):
    if not _WIN32:
        path = _as_bytes0(path)
        if times is None:
            error = c_utime(path, lltype.nullptr(UTIMBUFP.TO))
        else:
            if HAVE_UTIMES:
                with lltype.scoped_alloc(TIMEVAL2P.TO, 2) as l_timeval2p:
                    times_to_timeval2p(times, l_timeval2p)
                    error = c_utimes(path, l_timeval2p)
            else:
                # we only have utime(), which does not allow
                # sub-second resolution
                actime, modtime = times
                l_utimbuf = lltype.malloc(UTIMBUFP.TO, flavor='raw')
                l_utimbuf.c_actime  = rffi.r_time_t(actime)
                l_utimbuf.c_modtime = rffi.r_time_t(modtime)
                error = c_utime(path, l_utimbuf)
                lltype.free(l_utimbuf, flavor='raw')
        handle_posix_error('utime', error)
    else:  # _WIN32 case
        from rpython.rlib.rwin32file import time_t_to_FILE_TIME
        traits = _preferred_traits(path)
        win32traits = make_win32_traits(traits)
        path = traits.as_str0(path)
        hFile = win32traits.CreateFile(path,
                           win32traits.FILE_WRITE_ATTRIBUTES, 0,
                           None, win32traits.OPEN_EXISTING,
                           win32traits.FILE_FLAG_BACKUP_SEMANTICS,
                           rwin32.NULL_HANDLE)
        if hFile == rwin32.INVALID_HANDLE_VALUE:
            raise rwin32.lastSavedWindowsError()
        ctime = lltype.nullptr(rwin32.FILETIME)
        atime = lltype.malloc(rwin32.FILETIME, flavor='raw')
        mtime = lltype.malloc(rwin32.FILETIME, flavor='raw')
        try:
            if times is None:
                now = lltype.malloc(rwin32.SYSTEMTIME, flavor='raw')
                try:
                    GetSystemTime(now)
                    if (not SystemTimeToFileTime(now, atime) or
                        not SystemTimeToFileTime(now, mtime)):
                        raise rwin32.lastSavedWindowsError()
                finally:
                    lltype.free(now, flavor='raw')
            else:
                actime, modtime = times
                time_t_to_FILE_TIME(actime, atime)
                time_t_to_FILE_TIME(modtime, mtime)
            if not SetFileTime(hFile, ctime, atime, mtime):
                raise rwin32.lastSavedWindowsError()
        finally:
            rwin32.CloseHandle(hFile)
            lltype.free(atime, flavor='raw')
            lltype.free(mtime, flavor='raw')

def times_to_timeval2p(times, l_timeval2p):
    actime, modtime = times
    _time_to_timeval(actime, l_timeval2p[0])
    _time_to_timeval(modtime, l_timeval2p[1])

def _time_to_timeval(t, l_timeval):
    import math
    fracpart, intpart = math.modf(t)
    intpart = int(intpart)
    fracpart = int(fracpart * 1e6)
    if fracpart < 0:
        intpart -= 1
        fracpart += 1000000
    assert 0 <= fracpart < 1000000
    rffi.setintfield(l_timeval, 'c_tv_sec', intpart)
    rffi.setintfield(l_timeval, 'c_tv_usec', fracpart)

if not _WIN32:
    TMSP = lltype.Ptr(TMS)
    c_times = external('times', [TMSP], CLOCK_T,
                        save_err=rffi.RFFI_SAVE_ERRNO |
                                 rffi.RFFI_ZERO_ERRNO_BEFORE)

    # Here is a random extra platform parameter which is important.
    # Strictly speaking, this should probably be retrieved at runtime, not
    # at translation time.
    CLOCK_TICKS_PER_SECOND = float(os.sysconf('SC_CLK_TCK'))
else:
    GetCurrentProcess = external(
        'GetCurrentProcess', [],
        rwin32.HANDLE, calling_conv='win')
    GetProcessTimes = external(
        'GetProcessTimes', [
            rwin32.HANDLE,
            lltype.Ptr(rwin32.FILETIME), lltype.Ptr(rwin32.FILETIME),
            lltype.Ptr(rwin32.FILETIME), lltype.Ptr(rwin32.FILETIME)],
        rwin32.BOOL, calling_conv='win')

@replace_os_function('times')
def times():
    if not _WIN32:
        l_tmsbuf = lltype.malloc(TMSP.TO, flavor='raw')
        try:
            # note: times() can return a negative value (or even -1)
            # even if there is no error
            result = rffi.cast(lltype.Signed, c_times(l_tmsbuf))
            if result == -1:
                errno = get_saved_errno()
                if errno != 0:
                    raise OSError(errno, 'times() failed')
            return (
                rffi.cast(lltype.Signed, l_tmsbuf.c_tms_utime)
                                               / CLOCK_TICKS_PER_SECOND,
                rffi.cast(lltype.Signed, l_tmsbuf.c_tms_stime)
                                               / CLOCK_TICKS_PER_SECOND,
                rffi.cast(lltype.Signed, l_tmsbuf.c_tms_cutime)
                                               / CLOCK_TICKS_PER_SECOND,
                rffi.cast(lltype.Signed, l_tmsbuf.c_tms_cstime)
                                               / CLOCK_TICKS_PER_SECOND,
                result / CLOCK_TICKS_PER_SECOND)
        finally:
            lltype.free(l_tmsbuf, flavor='raw')
    else:
        pcreate = lltype.malloc(rwin32.FILETIME, flavor='raw')
        pexit   = lltype.malloc(rwin32.FILETIME, flavor='raw')
        pkernel = lltype.malloc(rwin32.FILETIME, flavor='raw')
        puser   = lltype.malloc(rwin32.FILETIME, flavor='raw')
        try:
            hProc = GetCurrentProcess()
            GetProcessTimes(hProc, pcreate, pexit, pkernel, puser)
            # The fields of a FILETIME structure are the hi and lo parts
            # of a 64-bit value expressed in 100 nanosecond units
            # (of course).
            return (
                rffi.cast(lltype.Signed, pkernel.c_dwHighDateTime) * 429.4967296 +
                rffi.cast(lltype.Signed, pkernel.c_dwLowDateTime) * 1E-7,
                rffi.cast(lltype.Signed, puser.c_dwHighDateTime) * 429.4967296 +
                rffi.cast(lltype.Signed, puser.c_dwLowDateTime) * 1E-7,
                0., 0., 0.)
        finally:
            lltype.free(puser,   flavor='raw')
            lltype.free(pkernel, flavor='raw')
            lltype.free(pexit,   flavor='raw')
            lltype.free(pcreate, flavor='raw')

c_kill = external('kill', [rffi.PID_T, rffi.INT], rffi.INT,
                  save_err=rffi.RFFI_SAVE_ERRNO)
c_killpg = external('killpg', [rffi.INT, rffi.INT], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_exit = external('_exit', [rffi.INT], lltype.Void)
c_nice = external('nice', [rffi.INT], rffi.INT,
                  save_err=rffi.RFFI_FULL_ERRNO_ZERO)

@replace_os_function('kill')
def kill(pid, sig):
    if not _WIN32:
        return handle_posix_error('kill', c_kill(pid, sig))
    else:
        if sig == rwin32.CTRL_C_EVENT or sig == rwin32.CTRL_BREAK_EVENT:
            if rwin32.GenerateConsoleCtrlEvent(sig, pid) == 0:
                raise rwin32.lastSavedWindowsError(
                    'kill() failed generating event')
            return
        handle = rwin32.OpenProcess(rwin32.PROCESS_ALL_ACCESS, False, pid)
        if not handle:
            raise rwin32.lastSavedWindowsError('kill() failed opening process')
        try:
            if rwin32.TerminateProcess(handle, sig) == 0:
                raise rwin32.lastSavedWindowsError(
                    'kill() failed to terminate process')
        finally:
            rwin32.CloseHandle(handle)

@replace_os_function('killpg')
def killpg(pgrp, sig):
    return handle_posix_error('killpg', c_killpg(pgrp, sig))

@replace_os_function('_exit')
@jit.dont_look_inside
def exit(status):
    debug.debug_flush()
    c_exit(status)

@replace_os_function('nice')
def nice(inc):
    # Assume that the system provides a standard-compliant version
    # of nice() that returns the new priority.  Nowadays, FreeBSD
    # might be the last major non-compliant system (xxx check me).
    res = widen(c_nice(inc))
    if res == -1:
        err = get_saved_errno()
        if err != 0:
            raise OSError(err, "os_nice failed")
    return res

c_ctermid = external('ctermid', [rffi.CCHARP], rffi.CCHARP)

@replace_os_function('ctermid')
def ctermid():
    return rffi.charp2str(c_ctermid(lltype.nullptr(rffi.CCHARP.TO)))

c_tmpnam = external('tmpnam', [rffi.CCHARP], rffi.CCHARP)

@replace_os_function('tmpnam')
def tmpnam():
    return rffi.charp2str(c_tmpnam(lltype.nullptr(rffi.CCHARP.TO)))

#___________________________________________________________________

c_getpid = external('getpid', [], rffi.PID_T,
                    releasegil=False, save_err=rffi.RFFI_SAVE_ERRNO)
c_getppid = external('getppid', [], rffi.PID_T,
                     releasegil=False, save_err=rffi.RFFI_SAVE_ERRNO)
c_setsid = external('setsid', [], rffi.PID_T,
                    save_err=rffi.RFFI_SAVE_ERRNO)
c_getsid = external('getsid', [rffi.PID_T], rffi.PID_T,
                    save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('getpid')
def getpid():
    return handle_posix_error('getpid', c_getpid())

@replace_os_function('getppid')
def getppid():
    return handle_posix_error('getppid', c_getppid())

@replace_os_function('setsid')
def setsid():
    return handle_posix_error('setsid', c_setsid())

@replace_os_function('getsid')
def getsid(pid):
    return handle_posix_error('getsid', c_getsid(pid))

c_getpgid = external('getpgid', [rffi.PID_T], rffi.PID_T,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_setpgid = external('setpgid', [rffi.PID_T, rffi.PID_T], rffi.INT,
                     save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('getpgid')
def getpgid(pid):
    return handle_posix_error('getpgid', c_getpgid(pid))

@replace_os_function('setpgid')
def setpgid(pid, gid):
    handle_posix_error('setpgid', c_setpgid(pid, gid))

if not _WIN32:
    GID_GROUPS_T = rffi.CArrayPtr(GID_T)
    c_getgroups = external('getgroups', [rffi.INT, GID_GROUPS_T], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_setgroups = external('setgroups', [rffi.SIZE_T, GID_GROUPS_T], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_initgroups = external('initgroups', [rffi.CCHARP, GID_T], rffi.INT,
                            save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('getgroups')
def getgroups():
    n = handle_posix_error('getgroups',
                           c_getgroups(0, lltype.nullptr(GID_GROUPS_T.TO)))
    groups = lltype.malloc(GID_GROUPS_T.TO, n, flavor='raw')
    try:
        n = handle_posix_error('getgroups', c_getgroups(n, groups))
        return [widen_gid(groups[i]) for i in range(n)]
    finally:
        lltype.free(groups, flavor='raw')

@replace_os_function('setgroups')
def setgroups(gids):
    n = len(gids)
    groups = lltype.malloc(GID_GROUPS_T.TO, n, flavor='raw')
    try:
        for i in range(n):
            groups[i] = rffi.cast(GID_T, gids[i])
        handle_posix_error('setgroups', c_setgroups(n, groups))
    finally:
        lltype.free(groups, flavor='raw')

@replace_os_function('initgroups')
def initgroups(user, group):
    handle_posix_error('initgroups', c_initgroups(user, group))

if GETPGRP_HAVE_ARG:
    c_getpgrp = external('getpgrp', [rffi.INT], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
else:
    c_getpgrp = external('getpgrp', [], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
if SETPGRP_HAVE_ARG:
    c_setpgrp = external('setpgrp', [rffi.INT, rffi.INT], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
else:
    c_setpgrp = external('setpgrp', [], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('getpgrp')
def getpgrp():
    if GETPGRP_HAVE_ARG:
        return handle_posix_error('getpgrp', c_getpgrp(0))
    else:
        return handle_posix_error('getpgrp', c_getpgrp())

@replace_os_function('setpgrp')
def setpgrp():
    if SETPGRP_HAVE_ARG:
        handle_posix_error('setpgrp', c_setpgrp(0, 0))
    else:
        handle_posix_error('setpgrp', c_setpgrp())

c_tcgetpgrp = external('tcgetpgrp', [rffi.INT], rffi.PID_T,
                       save_err=rffi.RFFI_SAVE_ERRNO)
c_tcsetpgrp = external('tcsetpgrp', [rffi.INT, rffi.PID_T], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('tcgetpgrp')
def tcgetpgrp(fd):
    return handle_posix_error('tcgetpgrp', c_tcgetpgrp(fd))

@replace_os_function('tcsetpgrp')
def tcsetpgrp(fd, pgrp):
    return handle_posix_error('tcsetpgrp', c_tcsetpgrp(fd, pgrp))

#___________________________________________________________________

if not _WIN32:
    c_getuid = external('getuid', [], UID_T)
    c_geteuid = external('geteuid', [], UID_T)
    c_setuid = external('setuid', [UID_T], rffi.INT,
                        save_err=rffi.RFFI_SAVE_ERRNO)
    c_seteuid = external('seteuid', [UID_T], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
    c_getgid = external('getgid', [], GID_T)
    c_getegid = external('getegid', [], GID_T)
    c_setgid = external('setgid', [GID_T], rffi.INT,
                        save_err=rffi.RFFI_SAVE_ERRNO)
    c_setegid = external('setegid', [GID_T], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)

    def widen_uid(x):
        return rffi.cast(lltype.Unsigned, x)
    widen_gid = widen_uid

    # NOTE: the resulting type of functions that return a uid/gid is
    # always Unsigned.  The argument type of functions that take a
    # uid/gid should also be Unsigned.

    @replace_os_function('getuid')
    def getuid():
        return widen_uid(c_getuid())

    @replace_os_function('geteuid')
    def geteuid():
        return widen_uid(c_geteuid())

    @replace_os_function('setuid')
    def setuid(uid):
        handle_posix_error('setuid', c_setuid(uid))

    @replace_os_function('seteuid')
    def seteuid(uid):
        handle_posix_error('seteuid', c_seteuid(uid))

    @replace_os_function('getgid')
    def getgid():
        return widen_gid(c_getgid())

    @replace_os_function('getegid')
    def getegid():
        return widen_gid(c_getegid())

    @replace_os_function('setgid')
    def setgid(gid):
        handle_posix_error('setgid', c_setgid(gid))

    @replace_os_function('setegid')
    def setegid(gid):
        handle_posix_error('setegid', c_setegid(gid))

    c_setreuid = external('setreuid', [UID_T, UID_T], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)
    c_setregid = external('setregid', [GID_T, GID_T], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)

    @replace_os_function('setreuid')
    def setreuid(ruid, euid):
        handle_posix_error('setreuid', c_setreuid(ruid, euid))

    @replace_os_function('setregid')
    def setregid(rgid, egid):
        handle_posix_error('setregid', c_setregid(rgid, egid))

    UID_T_P = lltype.Ptr(lltype.Array(UID_T, hints={'nolength': True}))
    GID_T_P = lltype.Ptr(lltype.Array(GID_T, hints={'nolength': True}))
    c_getresuid = external('getresuid', [UID_T_P] * 3, rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_getresgid = external('getresgid', [GID_T_P] * 3, rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_setresuid = external('setresuid', [UID_T] * 3, rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_setresgid = external('setresgid', [GID_T] * 3, rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)

    @replace_os_function('getresuid')
    def getresuid():
        out = lltype.malloc(UID_T_P.TO, 3, flavor='raw')
        try:
            handle_posix_error('getresuid',
                               c_getresuid(rffi.ptradd(out, 0),
                                           rffi.ptradd(out, 1),
                                           rffi.ptradd(out, 2)))
            return (widen_uid(out[0]), widen_uid(out[1]), widen_uid(out[2]))
        finally:
            lltype.free(out, flavor='raw')

    @replace_os_function('getresgid')
    def getresgid():
        out = lltype.malloc(GID_T_P.TO, 3, flavor='raw')
        try:
            handle_posix_error('getresgid',
                               c_getresgid(rffi.ptradd(out, 0),
                                           rffi.ptradd(out, 1),
                                           rffi.ptradd(out, 2)))
            return (widen_gid(out[0]), widen_gid(out[1]), widen_gid(out[2]))
        finally:
            lltype.free(out, flavor='raw')

    @replace_os_function('setresuid')
    def setresuid(ruid, euid, suid):
        handle_posix_error('setresuid', c_setresuid(ruid, euid, suid))

    @replace_os_function('setresgid')
    def setresgid(rgid, egid, sgid):
        handle_posix_error('setresgid', c_setresgid(rgid, egid, sgid))

    c_getpriority = external('getpriority', [rffi.INT, ID_T], rffi.INT,
                             save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_setpriority = external('setpriority', [rffi.INT, ID_T, rffi.INT],
                             rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO)

    def getpriority(which, who):
        result = widen(c_getpriority(which, who))
        error = get_saved_errno()
        if error != 0:
            raise OSError(error, 'getpriority failed')
        return result

    def setpriority(which, who, prio):
        handle_posix_error('setpriority', c_setpriority(which, who, prio))

    c_sched_get_priority_max = external('sched_get_priority_max', [rffi.INT],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_sched_get_priority_min = external('sched_get_priority_min', [rffi.INT],
                             rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO)
    c_sched_yield = external('sched_yield', [], rffi.INT)

    @enforceargs(int)
    def sched_get_priority_max(policy):
        return handle_posix_error('sched_get_priority_max', c_sched_get_priority_max(policy))

    @enforceargs(int)
    def sched_get_priority_min(policy):
        return handle_posix_error('sched_get_priority_min', c_sched_get_priority_min(policy))

    def sched_yield():
        return handle_posix_error('sched_yield', c_sched_yield())

    c_getgroupslist = external('getgrouplist', [rffi.CCHARP, GID_T,
                            GID_GROUPS_T, rffi.INTP], rffi.INT,
                            save_err=rffi.RFFI_SAVE_ERRNO)

    def getgrouplist(user, group):
        groups_p = lltype.malloc(GID_GROUPS_T.TO, 64, flavor='raw')
        ngroups_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
        ngroups_p[0] = rffi.cast(rffi.INT, 64)
        try:
            n = handle_posix_error('getgrouplist', c_getgroupslist(user, group,
                             groups_p, ngroups_p))
            if n == -1:
               if widen(ngroups_p[0]) > 64:
                    # reallocate. Should never happen
                    lltype.free(groups_p, flavor='raw')
                    groups_p = lltype.nullptr(GID_GROUPS_T.TO)
                    groups_p = lltype.malloc(GID_GROUPS_T.TO, widen(ngroups_p[0]),
                                             flavor='raw')
                     
                    n = handle_posix_error('getgrouplist', c_getgroupslist(user,
                                                     group, groups_p, ngroups_p))
            ngroups = widen(ngroups_p[0])
            groups = [0] * ngroups
            for i in range(ngroups):
                groups[i] = groups_p[i]
            return groups
        finally:
            lltype.free(ngroups_p, flavor='raw')
            if groups_p:
                lltype.free(groups_p, flavor='raw')


#___________________________________________________________________

c_chroot = external('chroot', [rffi.CCHARP], rffi.INT,
                    save_err=rffi.RFFI_SAVE_ERRNO,
                    macro=_MACRO_ON_POSIX,
                    compilation_info=ExternalCompilationInfo(includes=['unistd.h']))

@replace_os_function('chroot')
def chroot(path):
    handle_posix_error('chroot', c_chroot(_as_bytes0(path)))

if not _WIN32:
    CHARARRAY1 = lltype.FixedSizeArray(lltype.Char, 1)
    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes = ['sys/utsname.h']
        )
        UTSNAME = rffi_platform.Struct('struct utsname', [
            ('sysname',  CHARARRAY1),
            ('nodename', CHARARRAY1),
            ('release',  CHARARRAY1),
            ('version',  CHARARRAY1),
            ('machine',  CHARARRAY1)])
    config = rffi_platform.configure(CConfig)
    UTSNAMEP = lltype.Ptr(config['UTSNAME'])

    c_uname = external('uname', [UTSNAMEP], rffi.INT,
                       compilation_info=CConfig._compilation_info_,
                       save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('uname')
def uname():
    l_utsbuf = lltype.malloc(UTSNAMEP.TO, flavor='raw')
    try:
        handle_posix_error('uname', c_uname(l_utsbuf))
        return (
            rffi.charp2str(rffi.cast(rffi.CCHARP, l_utsbuf.c_sysname)),
            rffi.charp2str(rffi.cast(rffi.CCHARP, l_utsbuf.c_nodename)),
            rffi.charp2str(rffi.cast(rffi.CCHARP, l_utsbuf.c_release)),
            rffi.charp2str(rffi.cast(rffi.CCHARP, l_utsbuf.c_version)),
            rffi.charp2str(rffi.cast(rffi.CCHARP, l_utsbuf.c_machine)),
        )
    finally:
        lltype.free(l_utsbuf, flavor='raw')

if sys.platform != 'win32':
    # These are actually macros on some/most systems
    c_makedev = external('makedev', [rffi.INT, rffi.INT], rffi.INT, macro=True)
    c_major = external('major', [rffi.INT], rffi.INT, macro=True)
    c_minor = external('minor', [rffi.INT], rffi.INT, macro=True)

    @replace_os_function('makedev')
    def makedev(maj, min):
        return c_makedev(maj, min)

    @replace_os_function('major')
    def major(dev):
        return c_major(dev)

    @replace_os_function('minor')
    def minor(dev):
        return c_minor(dev)

#___________________________________________________________________

c_sysconf = external('sysconf', [rffi.INT], rffi.LONG,
                     save_err=rffi.RFFI_FULL_ERRNO_ZERO)
c_fpathconf = external('fpathconf', [rffi.INT, rffi.INT], rffi.LONG,
                       save_err=rffi.RFFI_FULL_ERRNO_ZERO)
c_pathconf = external('pathconf', [rffi.CCHARP, rffi.INT], rffi.LONG,
                      save_err=rffi.RFFI_FULL_ERRNO_ZERO)
c_confstr = external('confstr',
                     [rffi.INT, rffi.CCHARP, rffi.SIZE_T], rffi.SIZE_T,
                      save_err=rffi.RFFI_FULL_ERRNO_ZERO)

@replace_os_function('sysconf')
def sysconf(value):
    res = c_sysconf(value)
    if res == -1:
        errno = get_saved_errno()
        if errno != 0:
            raise OSError(errno, "sysconf failed")
    return res

@replace_os_function('fpathconf')
def fpathconf(fd, value):
    res = c_fpathconf(fd, value)
    if res == -1:
        errno = get_saved_errno()
        if errno != 0:
            raise OSError(errno, "fpathconf failed")
    return res

@replace_os_function('pathconf')
def pathconf(path, value):
    res = c_pathconf(_as_bytes0(path), value)
    if res == -1:
        errno = get_saved_errno()
        if errno != 0:
            raise OSError(errno, "pathconf failed")
    return res

@replace_os_function('confstr')
def confstr(value):
    n = intmask(c_confstr(value, lltype.nullptr(rffi.CCHARP.TO), 0))
    if n > 0:
        buf = lltype.malloc(rffi.CCHARP.TO, n, flavor='raw')
        try:
            c_confstr(value, buf, n)
            return rffi.charp2strn(buf, n)
        finally:
            lltype.free(buf, flavor='raw')
    else:
        errno = get_saved_errno()
        if errno != 0:
            raise OSError(errno, "confstr failed")
        return None

# ____________________________________________________________
# Support for os.environ

# XXX only for systems where os.environ is an instance of _Environ,
# which should cover Unix and Windows at least
assert type(os.environ) is not dict

from rpython.rtyper.controllerentry import ControllerEntryForPrebuilt

class EnvironExtRegistry(ControllerEntryForPrebuilt):
    _about_ = os.environ

    def getcontroller(self):
        from rpython.rlib.rposix_environ import OsEnvironController
        return OsEnvironController()


# ____________________________________________________________
# Support for f... and ...at families of POSIX functions

class CConfig:
    _compilation_info_ = eci.merge(ExternalCompilationInfo(
        includes=['sys/statvfs.h'],
    ))
    for _name in """faccessat fchdir fchmod fchmodat fchown fchownat fexecve
            fdopendir fpathconf fstat fstatat fstatvfs ftruncate
            futimens futimes futimesat linkat chflags lchflags lchmod lchown
            lstat lutimes mkdirat mkfifoat mknodat openat readlinkat renameat
            symlinkat unlinkat utimensat sched_getparam""".split():
        locals()['HAVE_%s' % _name.upper()] = rffi_platform.Has(_name)
cConfig = rffi_platform.configure(CConfig)
globals().update(cConfig)

if not _WIN32:
    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes=['sys/stat.h',
                      'unistd.h',
                      'fcntl.h',
                     ],
        )
        AT_FDCWD = rffi_platform.DefinedConstantInteger('AT_FDCWD')
        AT_SYMLINK_NOFOLLOW = rffi_platform.DefinedConstantInteger('AT_SYMLINK_NOFOLLOW')
        AT_EACCESS = rffi_platform.DefinedConstantInteger('AT_EACCESS')
        AT_REMOVEDIR = rffi_platform.DefinedConstantInteger('AT_REMOVEDIR')
        AT_EMPTY_PATH = rffi_platform.DefinedConstantInteger('AT_EMPTY_PATH')
        UTIME_NOW = rffi_platform.DefinedConstantInteger('UTIME_NOW')
        UTIME_OMIT = rffi_platform.DefinedConstantInteger('UTIME_OMIT')
        TIMESPEC = rffi_platform.Struct('struct timespec', [
            ('tv_sec', rffi.TIME_T),
            ('tv_nsec', rffi.LONG)])
        AT_EACCESS = rffi_platform.DefinedConstantInteger('AT_EACCESS')

    cConfig = rffi_platform.configure(CConfig)
    globals().update(cConfig)

    TIMESPEC2P = rffi.CArrayPtr(TIMESPEC)

    class ConfConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes=[ 'unistd.h', ],
        )
    
    # Taken from posixmodule.c. Note the avaialbility is determined at
    # compile time by the host, but filled in by a runtime call to pathconf,
    # sysconf, or confstr.
    pathconf_consts_defs = {
        "PC_ABI_AIO_XFER_MAX": "_PC_ABI_AIO_XFER_MAX",
        "PC_ABI_ASYNC_IO": "_PC_ABI_ASYNC_IO",
        "PC_ASYNC_IO": "_PC_ASYNC_IO",
        "PC_CHOWN_RESTRICTED": "_PC_CHOWN_RESTRICTED",
        "PC_FILESIZEBITS": "_PC_FILESIZEBITS",
        "PC_LAST": "_PC_LAST",
        "PC_LINK_MAX": "_PC_LINK_MAX",
        "PC_MAX_CANON": "_PC_MAX_CANON",
        "PC_MAX_INPUT": "_PC_MAX_INPUT",
        "PC_NAME_MAX": "_PC_NAME_MAX",
        "PC_NO_TRUNC": "_PC_NO_TRUNC",
        "PC_PATH_MAX": "_PC_PATH_MAX",
        "PC_PIPE_BUF": "_PC_PIPE_BUF",
        "PC_PRIO_IO": "_PC_PRIO_IO",
        "PC_SOCK_MAXBUF": "_PC_SOCK_MAXBUF",
        "PC_SYNC_IO": "_PC_SYNC_IO",
        "PC_VDISABLE": "_PC_VDISABLE",
        "PC_ACL_ENABLED": "_PC_ACL_ENABLED",
        "PC_MIN_HOLE_SIZE": "_PC_MIN_HOLE_SIZE",
        "PC_ALLOC_SIZE_MIN": "_PC_ALLOC_SIZE_MIN",
        "PC_REC_INCR_XFER_SIZE": "_PC_REC_INCR_XFER_SIZE",
        "PC_REC_MAX_XFER_SIZE": "_PC_REC_MAX_XFER_SIZE",
        "PC_REC_MIN_XFER_SIZE": "_PC_REC_MIN_XFER_SIZE",
        "PC_REC_XFER_ALIGN": "_PC_REC_XFER_ALIGN",
        "PC_SYMLINK_MAX": "_PC_SYMLINK_MAX",
        "PC_XATTR_ENABLED": "_PC_XATTR_ENABLED",
        "PC_XATTR_EXISTS": "_PC_XATTR_EXISTS",
        "PC_TIMESTAMP_RESOLUTION": "_PC_TIMESTAMP_RESOLUTION",
    }

    confstr_consts_defs = {
        "CS_ARCHITECTURE": "_CS_ARCHITECTURE",
        "CS_GNU_LIBC_VERSION": "_CS_GNU_LIBC_VERSION",
        "CS_GNU_LIBPTHREAD_VERSION": "_CS_GNU_LIBPTHREAD_VERSION",
        "CS_HOSTNAME": "_CS_HOSTNAME",
        "CS_HW_PROVIDER": "_CS_HW_PROVIDER",
        "CS_HW_SERIAL": "_CS_HW_SERIAL",
        "CS_INITTAB_NAME": "_CS_INITTAB_NAME",
        "CS_LFS64_CFLAGS": "_CS_LFS64_CFLAGS",
        "CS_LFS64_LDFLAGS": "_CS_LFS64_LDFLAGS",
        "CS_LFS64_LIBS": "_CS_LFS64_LIBS",
        "CS_LFS64_LINTFLAGS": "_CS_LFS64_LINTFLAGS",
        "CS_LFS_CFLAGS": "_CS_LFS_CFLAGS",
        "CS_LFS_LDFLAGS": "_CS_LFS_LDFLAGS",
        "CS_LFS_LIBS": "_CS_LFS_LIBS",
        "CS_LFS_LINTFLAGS": "_CS_LFS_LINTFLAGS",
        "CS_MACHINE": "_CS_MACHINE",
        "CS_PATH": "_CS_PATH",
        "CS_RELEASE": "_CS_RELEASE",
        "CS_SRPC_DOMAIN": "_CS_SRPC_DOMAIN",
        "CS_SYSNAME": "_CS_SYSNAME",
        "CS_VERSION": "_CS_VERSION",
        "CS_XBS5_ILP32_OFF32_CFLAGS": "_CS_XBS5_ILP32_OFF32_CFLAGS",
        "CS_XBS5_ILP32_OFF32_LDFLAGS": "_CS_XBS5_ILP32_OFF32_LDFLAGS",
        "CS_XBS5_ILP32_OFF32_LIBS": "_CS_XBS5_ILP32_OFF32_LIBS",
        "CS_XBS5_ILP32_OFF32_LINTFLAGS": "_CS_XBS5_ILP32_OFF32_LINTFLAGS",
        "CS_XBS5_ILP32_OFFBIG_CFLAGS": "_CS_XBS5_ILP32_OFFBIG_CFLAGS",
        "CS_XBS5_ILP32_OFFBIG_LDFLAGS": "_CS_XBS5_ILP32_OFFBIG_LDFLAGS",
        "CS_XBS5_ILP32_OFFBIG_LIBS": "_CS_XBS5_ILP32_OFFBIG_LIBS",
        "CS_XBS5_ILP32_OFFBIG_LINTFLAGS": "_CS_XBS5_ILP32_OFFBIG_LINTFLAGS",
        "CS_XBS5_LP64_OFF64_CFLAGS": "_CS_XBS5_LP64_OFF64_CFLAGS",
        "CS_XBS5_LP64_OFF64_LDFLAGS": "_CS_XBS5_LP64_OFF64_LDFLAGS",
        "CS_XBS5_LP64_OFF64_LIBS": "_CS_XBS5_LP64_OFF64_LIBS",
        "CS_XBS5_LP64_OFF64_LINTFLAGS": "_CS_XBS5_LP64_OFF64_LINTFLAGS",
        "CS_XBS5_LPBIG_OFFBIG_CFLAGS": "_CS_XBS5_LPBIG_OFFBIG_CFLAGS",
        "CS_XBS5_LPBIG_OFFBIG_LDFLAGS": "_CS_XBS5_LPBIG_OFFBIG_LDFLAGS",
        "CS_XBS5_LPBIG_OFFBIG_LIBS": "_CS_XBS5_LPBIG_OFFBIG_LIBS",
        "CS_XBS5_LPBIG_OFFBIG_LINTFLAGS": "_CS_XBS5_LPBIG_OFFBIG_LINTFLAGS",
        "MIPS_CS_AVAIL_PROCESSORS": "_MIPS_CS_AVAIL_PROCESSORS",
        "MIPS_CS_BASE": "_MIPS_CS_BASE",
        "MIPS_CS_HOSTID": "_MIPS_CS_HOSTID",
        "MIPS_CS_HW_NAME": "_MIPS_CS_HW_NAME",
        "MIPS_CS_NUM_PROCESSORS": "_MIPS_CS_NUM_PROCESSORS",
        "MIPS_CS_OSREL_MAJ": "_MIPS_CS_OSREL_MAJ",
        "MIPS_CS_OSREL_MIN": "_MIPS_CS_OSREL_MIN",
        "MIPS_CS_OSREL_PATCH": "_MIPS_CS_OSREL_PATCH",
        "MIPS_CS_OS_NAME": "_MIPS_CS_OS_NAME",
        "MIPS_CS_OS_PROVIDER": "_MIPS_CS_OS_PROVIDER",
        "MIPS_CS_PROCESSORS": "_MIPS_CS_PROCESSORS",
        "MIPS_CS_SERIAL": "_MIPS_CS_SERIAL",
        "MIPS_CS_VENDOR": "_MIPS_CS_VENDOR",
    }

    sysconf_consts_defs = {
        "SC_2_CHAR_TERM": "_SC_2_CHAR_TERM",
        "SC_2_C_BIND": "_SC_2_C_BIND",
        "SC_2_C_DEV": "_SC_2_C_DEV",
        "SC_2_C_VERSION": "_SC_2_C_VERSION",
        "SC_2_FORT_DEV": "_SC_2_FORT_DEV",
        "SC_2_FORT_RUN": "_SC_2_FORT_RUN",
        "SC_2_LOCALEDEF": "_SC_2_LOCALEDEF",
        "SC_2_SW_DEV": "_SC_2_SW_DEV",
        "SC_2_UPE": "_SC_2_UPE",
        "SC_2_VERSION": "_SC_2_VERSION",
        "SC_ABI_ASYNCHRONOUS_IO": "_SC_ABI_ASYNCHRONOUS_IO",
        "SC_ACL": "_SC_ACL",
        "SC_AIO_LISTIO_MAX": "_SC_AIO_LISTIO_MAX",
        "SC_AIO_MAX": "_SC_AIO_MAX",
        "SC_AIO_PRIO_DELTA_MAX": "_SC_AIO_PRIO_DELTA_MAX",
        "SC_ARG_MAX": "_SC_ARG_MAX",
        "SC_ASYNCHRONOUS_IO": "_SC_ASYNCHRONOUS_IO",
        "SC_ATEXIT_MAX": "_SC_ATEXIT_MAX",
        "SC_AUDIT": "_SC_AUDIT",
        "SC_AVPHYS_PAGES": "_SC_AVPHYS_PAGES",
        "SC_BC_BASE_MAX": "_SC_BC_BASE_MAX",
        "SC_BC_DIM_MAX": "_SC_BC_DIM_MAX",
        "SC_BC_SCALE_MAX": "_SC_BC_SCALE_MAX",
        "SC_BC_STRING_MAX": "_SC_BC_STRING_MAX",
        "SC_CAP": "_SC_CAP",
        "SC_CHARCLASS_NAME_MAX": "_SC_CHARCLASS_NAME_MAX",
        "SC_CHAR_BIT": "_SC_CHAR_BIT",
        "SC_CHAR_MAX": "_SC_CHAR_MAX",
        "SC_CHAR_MIN": "_SC_CHAR_MIN",
        "SC_CHILD_MAX": "_SC_CHILD_MAX",
        "SC_CLK_TCK": "_SC_CLK_TCK",
        "SC_COHER_BLKSZ": "_SC_COHER_BLKSZ",
        "SC_COLL_WEIGHTS_MAX": "_SC_COLL_WEIGHTS_MAX",
        "SC_DCACHE_ASSOC": "_SC_DCACHE_ASSOC",
        "SC_DCACHE_BLKSZ": "_SC_DCACHE_BLKSZ",
        "SC_DCACHE_LINESZ": "_SC_DCACHE_LINESZ",
        "SC_DCACHE_SZ": "_SC_DCACHE_SZ",
        "SC_DCACHE_TBLKSZ": "_SC_DCACHE_TBLKSZ",
        "SC_DELAYTIMER_MAX": "_SC_DELAYTIMER_MAX",
        "SC_EQUIV_CLASS_MAX": "_SC_EQUIV_CLASS_MAX",
        "SC_EXPR_NEST_MAX": "_SC_EXPR_NEST_MAX",
        "SC_FSYNC": "_SC_FSYNC",
        "SC_GETGR_R_SIZE_MAX": "_SC_GETGR_R_SIZE_MAX",
        "SC_GETPW_R_SIZE_MAX": "_SC_GETPW_R_SIZE_MAX",
        "SC_ICACHE_ASSOC": "_SC_ICACHE_ASSOC",
        "SC_ICACHE_BLKSZ": "_SC_ICACHE_BLKSZ",
        "SC_ICACHE_LINESZ": "_SC_ICACHE_LINESZ",
        "SC_ICACHE_SZ": "_SC_ICACHE_SZ",
        "SC_INF": "_SC_INF",
        "SC_INT_MAX": "_SC_INT_MAX",
        "SC_INT_MIN": "_SC_INT_MIN",
        "SC_IOV_MAX": "_SC_IOV_MAX",
        "SC_IP_SECOPTS": "_SC_IP_SECOPTS",
        "SC_JOB_CONTROL": "_SC_JOB_CONTROL",
        "SC_KERN_POINTERS": "_SC_KERN_POINTERS",
        "SC_KERN_SIM": "_SC_KERN_SIM",
        "SC_LINE_MAX": "_SC_LINE_MAX",
        "SC_LOGIN_NAME_MAX": "_SC_LOGIN_NAME_MAX",
        "SC_LOGNAME_MAX": "_SC_LOGNAME_MAX",
        "SC_LONG_BIT": "_SC_LONG_BIT",
        "SC_MAC": "_SC_MAC",
        "SC_MAPPED_FILES": "_SC_MAPPED_FILES",
        "SC_MAXPID": "_SC_MAXPID",
        "SC_MB_LEN_MAX": "_SC_MB_LEN_MAX",
        "SC_MEMLOCK": "_SC_MEMLOCK",
        "SC_MEMLOCK_RANGE": "_SC_MEMLOCK_RANGE",
        "SC_MEMORY_PROTECTION": "_SC_MEMORY_PROTECTION",
        "SC_MESSAGE_PASSING": "_SC_MESSAGE_PASSING",
        "SC_MMAP_FIXED_ALIGNMENT": "_SC_MMAP_FIXED_ALIGNMENT",
        "SC_MQ_OPEN_MAX": "_SC_MQ_OPEN_MAX",
        "SC_MQ_PRIO_MAX": "_SC_MQ_PRIO_MAX",
        "SC_NACLS_MAX": "_SC_NACLS_MAX",
        "SC_NGROUPS_MAX": "_SC_NGROUPS_MAX",
        "SC_NL_ARGMAX": "_SC_NL_ARGMAX",
        "SC_NL_LANGMAX": "_SC_NL_LANGMAX",
        "SC_NL_MSGMAX": "_SC_NL_MSGMAX",
        "SC_NL_NMAX": "_SC_NL_NMAX",
        "SC_NL_SETMAX": "_SC_NL_SETMAX",
        "SC_NL_TEXTMAX": "_SC_NL_TEXTMAX",
        "SC_NPROCESSORS_CONF": "_SC_NPROCESSORS_CONF",
        "SC_NPROCESSORS_ONLN": "_SC_NPROCESSORS_ONLN",
        "SC_NPROC_CONF": "_SC_NPROC_CONF",
        "SC_NPROC_ONLN": "_SC_NPROC_ONLN",
        "SC_NZERO": "_SC_NZERO",
        "SC_OPEN_MAX": "_SC_OPEN_MAX",
        "SC_PAGESIZE": "_SC_PAGESIZE",
        "SC_PAGE_SIZE": "_SC_PAGE_SIZE",
        "SC_PASS_MAX": "_SC_PASS_MAX",
        "SC_PHYS_PAGES": "_SC_PHYS_PAGES",
        "SC_PII": "_SC_PII",
        "SC_PII_INTERNET": "_SC_PII_INTERNET",
        "SC_PII_INTERNET_DGRAM": "_SC_PII_INTERNET_DGRAM",
        "SC_PII_INTERNET_STREAM": "_SC_PII_INTERNET_STREAM",
        "SC_PII_OSI": "_SC_PII_OSI",
        "SC_PII_OSI_CLTS": "_SC_PII_OSI_CLTS",
        "SC_PII_OSI_COTS": "_SC_PII_OSI_COTS",
        "SC_PII_OSI_M": "_SC_PII_OSI_M",
        "SC_PII_SOCKET": "_SC_PII_SOCKET",
        "SC_PII_XTI": "_SC_PII_XTI",
        "SC_POLL": "_SC_POLL",
        "SC_PRIORITIZED_IO": "_SC_PRIORITIZED_IO",
        "SC_PRIORITY_SCHEDULING": "_SC_PRIORITY_SCHEDULING",
        "SC_REALTIME_SIGNALS": "_SC_REALTIME_SIGNALS",
        "SC_RE_DUP_MAX": "_SC_RE_DUP_MAX",
        "SC_RTSIG_MAX": "_SC_RTSIG_MAX",
        "SC_SAVED_IDS": "_SC_SAVED_IDS",
        "SC_SCHAR_MAX": "_SC_SCHAR_MAX",
        "SC_SCHAR_MIN": "_SC_SCHAR_MIN",
        "SC_SELECT": "_SC_SELECT",
        "SC_SEMAPHORES": "_SC_SEMAPHORES",
        "SC_SEM_NSEMS_MAX": "_SC_SEM_NSEMS_MAX",
        "SC_SEM_VALUE_MAX": "_SC_SEM_VALUE_MAX",
        "SC_SHARED_MEMORY_OBJECTS": "_SC_SHARED_MEMORY_OBJECTS",
        "SC_SHRT_MAX": "_SC_SHRT_MAX",
        "SC_SHRT_MIN": "_SC_SHRT_MIN",
        "SC_SIGQUEUE_MAX": "_SC_SIGQUEUE_MAX",
        "SC_SIGRT_MAX": "_SC_SIGRT_MAX",
        "SC_SIGRT_MIN": "_SC_SIGRT_MIN",
        "SC_SOFTPOWER": "_SC_SOFTPOWER",
        "SC_SPLIT_CACHE": "_SC_SPLIT_CACHE",
        "SC_SSIZE_MAX": "_SC_SSIZE_MAX",
        "SC_STACK_PROT": "_SC_STACK_PROT",
        "SC_STREAM_MAX": "_SC_STREAM_MAX",
        "SC_SYNCHRONIZED_IO": "_SC_SYNCHRONIZED_IO",
        "SC_THREADS": "_SC_THREADS",
        "SC_THREAD_ATTR_STACKADDR": "_SC_THREAD_ATTR_STACKADDR",
        "SC_THREAD_ATTR_STACKSIZE": "_SC_THREAD_ATTR_STACKSIZE",
        "SC_THREAD_DESTRUCTOR_ITERATIONS": "_SC_THREAD_DESTRUCTOR_ITERATIONS",
        "SC_THREAD_KEYS_MAX": "_SC_THREAD_KEYS_MAX",
        "SC_THREAD_PRIORITY_SCHEDULING": "_SC_THREAD_PRIORITY_SCHEDULING",
        "SC_THREAD_PRIO_INHERIT": "_SC_THREAD_PRIO_INHERIT",
        "SC_THREAD_PRIO_PROTECT": "_SC_THREAD_PRIO_PROTECT",
        "SC_THREAD_PROCESS_SHARED": "_SC_THREAD_PROCESS_SHARED",
        "SC_THREAD_SAFE_FUNCTIONS": "_SC_THREAD_SAFE_FUNCTIONS",
        "SC_THREAD_STACK_MIN": "_SC_THREAD_STACK_MIN",
        "SC_THREAD_THREADS_MAX": "_SC_THREAD_THREADS_MAX",
        "SC_TIMERS": "_SC_TIMERS",
        "SC_TIMER_MAX": "_SC_TIMER_MAX",
        "SC_TTY_NAME_MAX": "_SC_TTY_NAME_MAX",
        "SC_TZNAME_MAX": "_SC_TZNAME_MAX",
        "SC_T_IOV_MAX": "_SC_T_IOV_MAX",
        "SC_UCHAR_MAX": "_SC_UCHAR_MAX",
        "SC_UINT_MAX": "_SC_UINT_MAX",
        "SC_UIO_MAXIOV": "_SC_UIO_MAXIOV",
        "SC_ULONG_MAX": "_SC_ULONG_MAX",
        "SC_USHRT_MAX": "_SC_USHRT_MAX",
        "SC_VERSION": "_SC_VERSION",
        "SC_WORD_BIT": "_SC_WORD_BIT",
        "SC_XBS5_ILP32_OFF32": "_SC_XBS5_ILP32_OFF32",
        "SC_XBS5_ILP32_OFFBIG": "_SC_XBS5_ILP32_OFFBIG",
        "SC_XBS5_LP64_OFF64": "_SC_XBS5_LP64_OFF64",
        "SC_XBS5_LPBIG_OFFBIG": "_SC_XBS5_LPBIG_OFFBIG",
        "SC_XOPEN_CRYPT": "_SC_XOPEN_CRYPT",
        "SC_XOPEN_ENH_I18N": "_SC_XOPEN_ENH_I18N",
        "SC_XOPEN_LEGACY": "_SC_XOPEN_LEGACY",
        "SC_XOPEN_REALTIME": "_SC_XOPEN_REALTIME",
        "SC_XOPEN_REALTIME_THREADS": "_SC_XOPEN_REALTIME_THREADS",
        "SC_XOPEN_SHM": "_SC_XOPEN_SHM",
        "SC_XOPEN_UNIX": "_SC_XOPEN_UNIX",
        "SC_XOPEN_VERSION": "_SC_XOPEN_VERSION",
        "SC_XOPEN_XCU_VERSION": "_SC_XOPEN_XCU_VERSION",
        "SC_XOPEN_XPG2": "_SC_XOPEN_XPG2",
        "SC_XOPEN_XPG3": "_SC_XOPEN_XPG3",
        "SC_XOPEN_XPG4": "_SC_XOPEN_XPG4",
    }
    for k,v in pathconf_consts_defs.items():
       setattr(ConfConfig, k, rffi_platform.DefinedConstantInteger(v))
    for k,v in confstr_consts_defs.items():
       setattr(ConfConfig, k, rffi_platform.DefinedConstantInteger(v))
    for k,v in sysconf_consts_defs.items():
       setattr(ConfConfig, k, rffi_platform.DefinedConstantInteger(v))
            
    confConfig = rffi_platform.configure(ConfConfig)
    pathconf_names = {}
    confstr_names = {}
    sysconf_names = {}
    for k in pathconf_consts_defs:
        v = confConfig.get(k, None)
        if v is not None:
            pathconf_names[k] = v
    for k in confstr_consts_defs:
        v = confConfig.get(k, None)
        if v is not None:
            confstr_names[k] = v
    for k in sysconf_consts_defs:
        v = confConfig.get(k, None)
        if v is not None:
            sysconf_names[k] = v



if HAVE_SCHED_GETPARAM:
    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes=['sys/stat.h',
                      'unistd.h',
                      'sched.h',
                     ],
        )
        SCHED_PARAM = rffi_platform.Struct('struct sched_param', [
            ('sched_priority', rffi.INT)])

    cConfig = rffi_platform.configure(CConfig)
    globals().update(cConfig)

    SCHED_PARAM2P = rffi.CArrayPtr(SCHED_PARAM)

    c_sched_rr_get_interval = external('sched_rr_get_interval',
                              [rffi.PID_T, TIMESPEC2P],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_sched_getscheduler = external('sched_getscheduler', [rffi.PID_T],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_sched_setscheduler = external('sched_setscheduler',
                              [rffi.PID_T, rffi.INT, SCHED_PARAM2P],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_sched_getparam = external('sched_getparam', [rffi.PID_T, SCHED_PARAM2P],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)
    c_sched_setparam = external('sched_setparam', [rffi.PID_T, SCHED_PARAM2P],
                              rffi.INT, save_err=rffi.RFFI_FULL_ERRNO_ZERO)

    def sched_rr_get_interval(pid):
        with lltype.scoped_alloc(TIMESPEC2P.TO, 1) as interval:
            handle_posix_error('sched_rr_get_interval', c_sched_rr_get_interval(pid, interval))
            return interval[0].c_tv_sec + 1e-9 * interval[0].c_tv_nsec

    def sched_getscheduler(pid):
        return handle_posix_error('sched_getscheduler', c_sched_getscheduler(pid))

    def sched_setscheduler(pid, policy, priority):
        with lltype.scoped_alloc(SCHED_PARAM2P.TO, 1) as param:
            param[0].c_sched_priority = rffi.cast(rffi.INT, priority)
            return handle_posix_error('sched_setscheduler', c_sched_setscheduler(pid, policy, param))


    def sched_getparam(pid):
        with lltype.scoped_alloc(SCHED_PARAM2P.TO, 1) as param:
            handle_posix_error('sched_getparam', c_sched_getparam(pid, param))
            return param[0].c_sched_priority

    def sched_setparam(pid, priority):
        with lltype.scoped_alloc(SCHED_PARAM2P.TO, 1) as param:
            param[0].c_sched_priority = rffi.cast(rffi.INT, priority)
            return handle_posix_error('sched_setparam', c_sched_setparam(pid, param))


if HAVE_FACCESSAT:
    c_faccessat = external('faccessat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.INT], rffi.INT)

    def faccessat(pathname, mode, dir_fd=AT_FDCWD,
            effective_ids=False, follow_symlinks=True):
        """Thin wrapper around faccessat(2) with an interface simlar to
        Python3's os.access().
        """
        flags = 0
        if not follow_symlinks:
            flags |= AT_SYMLINK_NOFOLLOW
        if effective_ids:
            flags |= AT_EACCESS
        error = c_faccessat(dir_fd, pathname, mode, flags)
        return error == 0

if HAVE_FCHMODAT:
    c_fchmodat = external('fchmodat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO,)

    def fchmodat(path, mode, dir_fd=AT_FDCWD, follow_symlinks=True):
        if follow_symlinks:
            flag = 0
        else:
            flag = AT_SYMLINK_NOFOLLOW
        error = c_fchmodat(dir_fd, path, mode, flag)
        handle_posix_error('fchmodat', error)

if HAVE_FCHOWNAT:
    c_fchownat = external('fchownat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.INT, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO,)

    def fchownat(path, owner, group, dir_fd=AT_FDCWD,
            follow_symlinks=True, empty_path=False):
        flag = 0
        if not follow_symlinks:
            flag |= AT_SYMLINK_NOFOLLOW
        if empty_path:
            flag |= AT_EMPTY_PATH
        error = c_fchownat(dir_fd, path, owner, group, flag)
        handle_posix_error('fchownat', error)

if HAVE_FEXECVE:
    c_fexecve = external('fexecve',
        [rffi.INT, rffi.CCHARPP, rffi.CCHARPP], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def fexecve(fd, args, env):
        envstrs = []
        for item in env.iteritems():
            envstr = "%s=%s" % item
            envstrs.append(envstr)

        # This list conversion already takes care of NUL bytes.
        l_args = rffi.ll_liststr2charpp(args)
        l_env = rffi.ll_liststr2charpp(envstrs)
        c_fexecve(fd, l_args, l_env)

        rffi.free_charpp(l_env)
        rffi.free_charpp(l_args)
        raise OSError(get_saved_errno(), "execve failed")

if HAVE_LINKAT:
    c_linkat = external(
        'linkat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.CCHARP, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def linkat(src, dst, src_dir_fd=AT_FDCWD, dst_dir_fd=AT_FDCWD,
            follow_symlinks=True):
        """Thin wrapper around linkat(2) with an interface similar to
        Python3's os.link()
        """
        if follow_symlinks:
            flag = 0
        else:
            flag = AT_SYMLINK_NOFOLLOW
        error = c_linkat(src_dir_fd, src, dst_dir_fd, dst, flag)
        handle_posix_error('linkat', error)

if HAVE_FUTIMENS:
    c_futimens = external('futimens', [rffi.INT, TIMESPEC2P], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)

    def futimens(fd, atime, atime_ns, mtime, mtime_ns):
        l_times = lltype.malloc(TIMESPEC2P.TO, 2, flavor='raw')
        rffi.setintfield(l_times[0], 'c_tv_sec', atime)
        rffi.setintfield(l_times[0], 'c_tv_nsec', atime_ns)
        rffi.setintfield(l_times[1], 'c_tv_sec', mtime)
        rffi.setintfield(l_times[1], 'c_tv_nsec', mtime_ns)
        error = c_futimens(fd, l_times)
        lltype.free(l_times, flavor='raw')
        handle_posix_error('futimens', error)

if HAVE_UTIMENSAT:
    c_utimensat = external(
        'utimensat',
        [rffi.INT, rffi.CCHARP, TIMESPEC2P, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def utimensat(pathname, atime, atime_ns, mtime, mtime_ns,
            dir_fd=AT_FDCWD, follow_symlinks=True):
        """Wrapper around utimensat(2)

        To set access time to the current time, pass atime_ns=UTIME_NOW,
        atime is then ignored.

        To set modification time to the current time, pass mtime_ns=UTIME_NOW,
        mtime is then ignored.
        """
        l_times = lltype.malloc(TIMESPEC2P.TO, 2, flavor='raw')
        rffi.setintfield(l_times[0], 'c_tv_sec', atime)
        rffi.setintfield(l_times[0], 'c_tv_nsec', atime_ns)
        rffi.setintfield(l_times[1], 'c_tv_sec', mtime)
        rffi.setintfield(l_times[1], 'c_tv_nsec', mtime_ns)
        if follow_symlinks:
            flag = 0
        else:
            flag = AT_SYMLINK_NOFOLLOW
        error = c_utimensat(dir_fd, pathname, l_times, flag)
        lltype.free(l_times, flavor='raw')
        handle_posix_error('utimensat', error)

if HAVE_LUTIMES:
    c_lutimes = external('lutimes',
        [rffi.CCHARP, TIMEVAL2P], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    @specialize.argtype(1)
    def lutimes(pathname, times):
        if times is None:
            error = c_lutimes(pathname, lltype.nullptr(TIMEVAL2P.TO))
        else:
            with lltype.scoped_alloc(TIMEVAL2P.TO, 2) as l_timeval2p:
                times_to_timeval2p(times, l_timeval2p)
                error = c_lutimes(pathname, l_timeval2p)
        handle_posix_error('lutimes', error)

if HAVE_FUTIMES:
    c_futimes = external('futimes',
        [rffi.INT, TIMEVAL2P], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    @specialize.argtype(1)
    def futimes(fd, times):
        if times is None:
            error = c_futimes(fd, lltype.nullptr(TIMEVAL2P.TO))
        else:
            with lltype.scoped_alloc(TIMEVAL2P.TO, 2) as l_timeval2p:
                times_to_timeval2p(times, l_timeval2p)
                error = c_futimes(fd, l_timeval2p)
        handle_posix_error('futimes', error)

if HAVE_MKDIRAT:
    c_mkdirat = external('mkdirat',
        [rffi.INT, rffi.CCHARP, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def mkdirat(pathname, mode, dir_fd=AT_FDCWD):
        error = c_mkdirat(dir_fd, pathname, mode)
        handle_posix_error('mkdirat', error)

if HAVE_UNLINKAT:
    c_unlinkat = external('unlinkat',
        [rffi.INT, rffi.CCHARP, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def unlinkat(pathname, dir_fd=AT_FDCWD, removedir=False):
        flag = AT_REMOVEDIR if removedir else 0
        error = c_unlinkat(dir_fd, pathname, flag)
        handle_posix_error('unlinkat', error)

if HAVE_READLINKAT:
    c_readlinkat = external(
        'readlinkat',
        [rffi.INT, rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T], rffi.SSIZE_T,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def readlinkat(pathname, dir_fd=AT_FDCWD):
        pathname = _as_bytes0(pathname)
        bufsize = 1023
        while True:
            buf = lltype.malloc(rffi.CCHARP.TO, bufsize, flavor='raw')
            res = widen(c_readlinkat(dir_fd, pathname, buf, bufsize))
            if res < 0:
                lltype.free(buf, flavor='raw')
                error = get_saved_errno()    # failed
                raise OSError(error, "readlinkat failed")
            elif res < bufsize:
                break                       # ok
            else:
                # buf too small, try again with a larger buffer
                lltype.free(buf, flavor='raw')
                bufsize *= 4
        # convert the result to a string
        result = rffi.charp2strn(buf, res)
        lltype.free(buf, flavor='raw')
        return result

if HAVE_RENAMEAT:
    c_renameat = external(
        'renameat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.CCHARP], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def renameat(src, dst, src_dir_fd=AT_FDCWD, dst_dir_fd=AT_FDCWD):
        error = c_renameat(src_dir_fd, src, dst_dir_fd, dst)
        handle_posix_error('renameat', error)


if HAVE_SYMLINKAT:
    c_symlinkat = external('symlinkat',
        [rffi.CCHARP, rffi.INT, rffi.CCHARP], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def symlinkat(src, dst, dir_fd=AT_FDCWD):
        error = c_symlinkat(src, dir_fd, dst)
        handle_posix_error('symlinkat', error)

if HAVE_OPENAT:
    c_openat = external('openat',
        [rffi.INT, rffi.CCHARP, rffi.INT, rffi.MODE_T], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    @enforceargs(s_Str0, int, int, int, typecheck=False)
    def openat(path, flags, mode, dir_fd=AT_FDCWD):
        fd = c_openat(dir_fd, path, flags, mode)
        return handle_posix_error('open', fd)

if HAVE_MKFIFOAT:
    c_mkfifoat = external('mkfifoat',
        [rffi.INT, rffi.CCHARP, rffi.MODE_T], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def mkfifoat(path, mode, dir_fd=AT_FDCWD):
        error = c_mkfifoat(dir_fd, path, mode)
        handle_posix_error('mkfifoat', error)

if HAVE_MKNODAT:
    c_mknodat = external('mknodat',
        [rffi.INT, rffi.CCHARP, rffi.MODE_T, rffi.INT], rffi.INT,
        save_err=rffi.RFFI_SAVE_ERRNO)

    def mknodat(path, mode, device, dir_fd=AT_FDCWD):
        error = c_mknodat(dir_fd, path, mode, device)
        handle_posix_error('mknodat', error)


if not _WIN32:
    eci_inheritable = eci.merge(ExternalCompilationInfo(
        separate_module_sources=[r"""
#include <errno.h>
#include <sys/ioctl.h>

RPY_EXTERN
int rpy_set_inheritable(int fd, int inheritable)
{
    static int ioctl_works = -1;
    int flags;

    if (ioctl_works != 0) {
        int request = inheritable ? FIONCLEX : FIOCLEX;
        int err = ioctl(fd, request, NULL);
        if (!err) {
            ioctl_works = 1;
            return 0;
        }

        if (errno != ENOTTY && errno != EACCES) {
            return -1;
        }
        else {
            /* ENOTTY: The ioctl is declared but not supported by the
               kernel.  EACCES: SELinux policy, this can be the case on
               Android. */
            ioctl_works = 0;
        }
        /* fallback to fcntl() if ioctl() does not work */
    }

    flags = fcntl(fd, F_GETFD);
    if (flags < 0)
        return -1;

    if (inheritable)
        flags &= ~FD_CLOEXEC;
    else
        flags |= FD_CLOEXEC;
    return fcntl(fd, F_SETFD, flags);
}

RPY_EXTERN
int rpy_get_inheritable(int fd)
{
    int flags = fcntl(fd, F_GETFD, 0);
    if (flags == -1)
        return -1;
    return !(flags & FD_CLOEXEC);
}

RPY_EXTERN
int rpy_dup_noninheritable(int fd)
{
#ifdef F_DUPFD_CLOEXEC
    return fcntl(fd, F_DUPFD_CLOEXEC, 0);
#else
    fd = dup(fd);
    if (fd >= 0) {
        if (rpy_set_inheritable(fd, 0) != 0) {
            close(fd);
            return -1;
        }
    }
    return fd;
#endif
}

RPY_EXTERN
int rpy_dup2_noninheritable(int fd, int fd2)
{
#ifdef F_DUP2FD_CLOEXEC
    return fcntl(fd, F_DUP2FD_CLOEXEC, fd2);

#else
# if %(HAVE_DUP3)d   /* HAVE_DUP3 */
    static int dup3_works = -1;
    if (dup3_works != 0) {
        if (dup3(fd, fd2, O_CLOEXEC) >= 0)
            return 0;
        if (dup3_works == -1)
            dup3_works = (errno != ENOSYS);
        if (dup3_works)
            return -1;
    }
# endif
    if (dup2(fd, fd2) < 0)
        return -1;
    if (rpy_set_inheritable(fd2, 0) != 0) {
        close(fd2);
        return -1;
    }
    return 0;
#endif
}
        """ % {'HAVE_DUP3': HAVE_DUP3}],
        post_include_bits=['RPY_EXTERN int rpy_set_inheritable(int, int);\n'
                           'RPY_EXTERN int rpy_get_inheritable(int);\n'
                           'RPY_EXTERN int rpy_dup_noninheritable(int);\n'
                           'RPY_EXTERN int rpy_dup2_noninheritable(int, int);\n'
                           ]))

    _c_set_inheritable = external('rpy_set_inheritable', [rffi.INT, rffi.INT],
                                  rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                  compilation_info=eci_inheritable)
    _c_get_inheritable = external('rpy_get_inheritable', [rffi.INT],
                                  rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                  compilation_info=eci_inheritable)
    c_dup_noninheritable = external('rpy_dup_noninheritable', [rffi.INT],
                                    rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                    compilation_info=eci_inheritable)
    c_dup2_noninheritable = external('rpy_dup2_noninheritable', [rffi.INT,rffi.INT],
                                     rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                     compilation_info=eci_inheritable)

    def set_inheritable(fd, inheritable):
        result = _c_set_inheritable(fd, inheritable)
        handle_posix_error('set_inheritable', result)

    def get_inheritable(fd):
        res = _c_get_inheritable(fd)
        res = handle_posix_error('get_inheritable', res)
        return res != 0

else:
    # _WIN32
    from rpython.rlib.rwin32 import set_inheritable, get_inheritable
    from rpython.rlib.rwin32 import c_dup_noninheritable
    from rpython.rlib.rwin32 import c_dup2_noninheritable


class SetNonInheritableCache(object):
    """Make one prebuilt instance of this for each path that creates
    file descriptors, where you don't necessarily know if that function
    returns inheritable or non-inheritable file descriptors.
    """
    _immutable_fields_ = ['cached_inheritable?']
    cached_inheritable = -1    # -1 = don't know yet; 0 = off; 1 = on

    def set_non_inheritable(self, fd):
        if self.cached_inheritable == -1:
            self.cached_inheritable = get_inheritable(fd)
        if self.cached_inheritable == 1:
            # 'fd' is inheritable; we must manually turn it off
            set_inheritable(fd, False)

    def _cleanup_(self):
        self.cached_inheritable = -1

class ENoSysCache(object):
    """Cache whether a system call returns ENOSYS or not."""
    _immutable_fields_ = ['cached_nosys?']
    cached_nosys = -1      # -1 = don't know; 0 = no; 1 = yes, getting ENOSYS

    def attempt_syscall(self):
        return self.cached_nosys != 1

    def fallback(self, res):
        nosys = self.cached_nosys
        if nosys == -1:
            nosys = (res < 0 and get_saved_errno() == errno.ENOSYS)
            self.cached_nosys = nosys
        return nosys

    def _cleanup_(self):
        self.cached_nosys = -1

_pipe2_syscall = ENoSysCache()

post_include_bits=['RPY_EXTERN int rpy_cpu_count(void);']
# cpu count for linux, windows and mac (+ bsds)
# note that the code is copied from cpython and split up here
if sys.platform.startswith(('linux', 'gnu')):
    cpucount_eci = ExternalCompilationInfo(includes=["unistd.h"],
            separate_module_sources=["""
            RPY_EXTERN int rpy_cpu_count(void) {
                return sysconf(_SC_NPROCESSORS_ONLN);
            }
            """], post_include_bits=post_include_bits)
elif sys.platform == "win32":
    cpucount_eci = ExternalCompilationInfo(includes=["Windows.h"],
            separate_module_sources=["""
        RPY_EXTERN int rpy_cpu_count(void) {
            SYSTEM_INFO sysinfo;
            GetSystemInfo(&sysinfo);
            return sysinfo.dwNumberOfProcessors;
        }
        """], post_include_bits=post_include_bits)
else:
    cpucount_eci = ExternalCompilationInfo(includes=["sys/types.h", "sys/sysctl.h"],
            separate_module_sources=["""
            RPY_EXTERN int rpy_cpu_count(void) {
                int ncpu = 0;
            #if defined(__DragonFly__) || \
                defined(__OpenBSD__)   || \
                defined(__FreeBSD__)   || \
                defined(__NetBSD__)    || \
                defined(__APPLE__)
                int mib[2];
                size_t len = sizeof(ncpu);
                mib[0] = CTL_HW;
                mib[1] = HW_NCPU;
                if (sysctl(mib, 2, &ncpu, &len, NULL, 0) != 0)
                    ncpu = 0;
            #endif
                return ncpu;
            }
            """], post_include_bits=post_include_bits)

_cpu_count = rffi.llexternal('rpy_cpu_count', [], rffi.INT_real,
                            compilation_info=cpucount_eci)

def cpu_count():
    return rffi.cast(lltype.Signed, _cpu_count())

if not _WIN32:
    eci_status_flags = eci.merge(ExternalCompilationInfo(separate_module_sources=["""
    RPY_EXTERN
    int rpy_get_status_flags(int fd)
    {
        int flags;
        flags = fcntl(fd, F_GETFL, 0);
        return flags;
    }

    RPY_EXTERN
    int rpy_set_status_flags(int fd, int flags)
    {
        int res;
        res = fcntl(fd, F_SETFL, flags);
        return res;
    }
    """], post_include_bits=[
        "RPY_EXTERN int rpy_get_status_flags(int);\n"
        "RPY_EXTERN int rpy_set_status_flags(int, int);"]
    ))


    c_get_status_flags = external('rpy_get_status_flags', [rffi.INT],
                                rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                compilation_info=eci_status_flags)
    c_set_status_flags = external('rpy_set_status_flags', [rffi.INT, rffi.INT],
                                rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO,
                                compilation_info=eci_status_flags)

    def get_status_flags(fd):
        res = c_get_status_flags(fd)
        res = handle_posix_error('get_status_flags', res)
        return res

    def set_status_flags(fd, flags):
        res = c_set_status_flags(fd, flags)
        handle_posix_error('set_status_flags', res)

if sys.platform.startswith('linux'):
    sendfile_eci = ExternalCompilationInfo(includes=["sys/sendfile.h"])
    _OFF_PTR_T = rffi.CArrayPtr(OFF_T)
    c_sendfile = rffi.llexternal('sendfile',
            [rffi.INT, rffi.INT, _OFF_PTR_T, rffi.SIZE_T],
            rffi.SSIZE_T, save_err=rffi.RFFI_SAVE_ERRNO,
            compilation_info=sendfile_eci)

    def sendfile(out_fd, in_fd, offset, count):
        with lltype.scoped_alloc(_OFF_PTR_T.TO, 1) as p_offset:
            p_offset[0] = rffi.cast(OFF_T, offset)
            res = c_sendfile(out_fd, in_fd, p_offset, count)
        return handle_posix_error('sendfile', res)

    def sendfile_no_offset(out_fd, in_fd, count):
        """Passes offset==NULL; not support on all OSes"""
        res = c_sendfile(out_fd, in_fd, lltype.nullptr(_OFF_PTR_T.TO), count)
        return handle_posix_error('sendfile', res)

elif not _WIN32:
    # Neither on Windows nor on Linux, so probably a BSD derivative of
    # some sort. Please note that the implementation below is partial;
    # the VOIDP is an iovec for sending headers and trailers which
    # CPython uses for the headers and trailers argument, and it also
    # has a flags argument. None of these are currently supported.
    sendfile_eci = ExternalCompilationInfo(includes=["sys/socket.h"])
    _OFF_PTR_T = rffi.CArrayPtr(OFF_T)
    # NB: the VOIDP is an struct sf_hdtr for sending headers and trailers
    c_sendfile = rffi.llexternal('sendfile',
            [rffi.INT, rffi.INT, OFF_T, _OFF_PTR_T, rffi.VOIDP, rffi.INT],
            rffi.SSIZE_T, save_err=rffi.RFFI_SAVE_ERRNO,
            compilation_info=sendfile_eci)

    def sendfile(out_fd, in_fd, offset, count):
        with lltype.scoped_alloc(_OFF_PTR_T.TO, 1) as p_len:
            p_len[0] = rffi.cast(OFF_T, count)
            res = c_sendfile(in_fd, out_fd, offset, p_len, lltype.nullptr(rffi.VOIDP.TO), 0)
            if res != 0:
                return handle_posix_error('sendfile', res)
            res = p_len[0]
        return res


# ____________________________________________________________
# Support for *xattr functions

if sys.platform.startswith('linux'):

    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes=['sys/xattr.h', 'linux/limits.h'],)
        XATTR_SIZE_MAX = rffi_platform.DefinedConstantInteger('XATTR_SIZE_MAX')
        XATTR_CREATE = rffi_platform.DefinedConstantInteger('XATTR_CREATE')
        XATTR_REPLACE = rffi_platform.DefinedConstantInteger('XATTR_REPLACE')

    cConfig = rffi_platform.configure(CConfig)
    globals().update(cConfig)
    c_fgetxattr = external('fgetxattr',
        [rffi.INT, rffi.CCHARP, rffi.VOIDP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_getxattr = external('getxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.VOIDP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_lgetxattr = external('lgetxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.VOIDP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_fsetxattr = external('fsetxattr',
        [rffi.INT, rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T, rffi.INT],
        rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_setxattr = external('setxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T, rffi.INT],
        rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_lsetxattr = external('lsetxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T, rffi.INT],
        rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_fremovexattr = external('fremovexattr',
        [rffi.INT, rffi.CCHARP], rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_removexattr = external('removexattr',
        [rffi.CCHARP, rffi.CCHARP], rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_lremovexattr = external('lremovexattr',
        [rffi.CCHARP, rffi.CCHARP], rffi.INT,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_flistxattr = external('flistxattr',
        [rffi.INT, rffi.CCHARP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_listxattr = external('listxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    c_llistxattr = external('llistxattr',
        [rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T], rffi.SSIZE_T,
        compilation_info=CConfig._compilation_info_,
        save_err=rffi.RFFI_SAVE_ERRNO)
    buf_sizes = [256, XATTR_SIZE_MAX]

    def fgetxattr(fd, name):
        for size in buf_sizes:
            with rffi.scoped_alloc_buffer(size) as buf:
                void_buf = rffi.cast(rffi.VOIDP, buf.raw)
                res = c_fgetxattr(fd, name, void_buf, size)
                if res < 0:
                    err = get_saved_errno()
                    if err != errno.ERANGE:
                        raise OSError(err, 'fgetxattr failed')
                else:
                    return buf.str(res)
        else:
            raise OSError(errno.ERANGE, 'fgetxattr failed')

    def getxattr(path, name, follow_symlinks=True):
        for size in buf_sizes:
            with rffi.scoped_alloc_buffer(size) as buf:
                void_buf = rffi.cast(rffi.VOIDP, buf.raw)
                if follow_symlinks:
                    res = c_getxattr(path, name, void_buf, size)
                else:
                    res = c_lgetxattr(path, name, void_buf, size)
                if res < 0:
                    err = get_saved_errno()
                    if err != errno.ERANGE:
                        c_name = 'getxattr' if follow_symlinks else 'lgetxattr'
                        raise OSError(err, c_name + 'failed')
                else:
                    return buf.str(res)
        else:
            c_name = 'getxattr' if follow_symlinks else 'lgetxattr'
            raise OSError(errno.ERANGE, c_name + 'failed')

    def fsetxattr(fd, name, value, flags=0):
        return handle_posix_error(
            'fsetxattr', c_fsetxattr(fd, name, value, len(value), flags))

    def setxattr(path, name, value, flags=0, follow_symlinks=True):
        if follow_symlinks:
            return handle_posix_error(
                'setxattr', c_setxattr(path, name, value, len(value), flags))
        else:
            return handle_posix_error(
                'lsetxattr', c_lsetxattr(path, name, value, len(value), flags))

    def fremovexattr(fd, name):
        return handle_posix_error('fremovexattr', c_fremovexattr(fd, name))

    def removexattr(path, name, follow_symlinks=True):
        if follow_symlinks:
            return handle_posix_error('removexattr', c_removexattr(path, name))
        else:
            return handle_posix_error('lremovexattr', c_lremovexattr(path, name))

    def _unpack_attrs(attr_string):
        result = attr_string.split('\0')
        del result[-1]
        return result

    def flistxattr(fd):
        for size in buf_sizes:
            with rffi.scoped_alloc_buffer(size) as buf:
                res = c_flistxattr(fd, buf.raw, size)
                if res < 0:
                    err = get_saved_errno()
                    if err != errno.ERANGE:
                        raise OSError(err, 'flistxattr failed')
                else:
                    return _unpack_attrs(buf.str(res))
        else:
            raise OSError(errno.ERANGE, 'flistxattr failed')

    def listxattr(path, follow_symlinks=True):
        for size in buf_sizes:
            with rffi.scoped_alloc_buffer(size) as buf:
                if follow_symlinks:
                    res = c_listxattr(path, buf.raw, size)
                else:
                    res = c_llistxattr(path, buf.raw, size)
                if res < 0:
                    err = get_saved_errno()
                    if err != errno.ERANGE:
                        c_name = 'listxattr' if follow_symlinks else 'llistxattr'
                        raise OSError(err, c_name + 'failed')
                else:
                    return _unpack_attrs(buf.str(res))
        else:
            c_name = 'listxattr' if follow_symlinks else 'llistxattr'
            raise OSError(errno.ERANGE, c_name + 'failed')


# ____________________________________________________________
# Support for memfd_create function

if sys.platform.startswith('linux'):
    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            includes=['sys/mman.h'],)
        for name in """
                MFD_CLOEXEC
                MFD_ALLOW_SEALING
                MFD_HUGETLB
                MFD_HUGE_SHIFT
                MFD_HUGE_MASK
                MFD_HUGE_64KB
                MFD_HUGE_512KB
                MFD_HUGE_1MB
                MFD_HUGE_2MB
                MFD_HUGE_8MB
                MFD_HUGE_16MB
                MFD_HUGE_32MB
                MFD_HUGE_256MB
                MFD_HUGE_512MB
                MFD_HUGE_1GB
                MFD_HUGE_2GB
                MFD_HUGE_16GB
                """.split():
            locals()[name] = rffi_platform.DefinedConstantInteger(name)
        HAVE_MEMFD_CREATE = rffi_platform.Has('memfd_create')

    cConfig = rffi_platform.configure(CConfig)
    for key, value in cConfig.items():
        if value is not None and key.startswith("MFD_"):
            globals()[key] = value

    if cConfig['HAVE_MEMFD_CREATE']:
        c_memfd_create = external('memfd_create',
            [rffi.CCHARP, rffi.UINT], rffi.INT,
            compilation_info=CConfig._compilation_info_)
        def memfd_create(name, flags):
            return handle_posix_error(
                'memfd_create', c_memfd_create(name, flags))


