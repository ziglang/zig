""" This file makes open() and friends RPython. Note that RFile should not
be used directly and instead it's magically appearing each time you call
python builtin open()
"""

import os, stat, errno, sys
from rpython.rlib import rposix, rgc
from rpython.rlib.objectmodel import enforceargs
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.rstring import StringBuilder
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform as platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo

includes = ['stdio.h', 'sys/types.h']
if os.name == "posix":
    includes += ['unistd.h']
    ftruncate = 'ftruncate'
    fileno = 'fileno'
else:
    ftruncate = '_chsize'
    fileno = '_fileno'
eci = ExternalCompilationInfo(includes=includes)


class CConfig(object):
    _compilation_info_ = eci

    off_t = platform.SimpleType('off_t')

    _IONBF = platform.DefinedConstantInteger('_IONBF')
    _IOLBF = platform.DefinedConstantInteger('_IOLBF')
    _IOFBF = platform.DefinedConstantInteger('_IOFBF')
    BUFSIZ = platform.DefinedConstantInteger('BUFSIZ')
    EOF = platform.DefinedConstantInteger('EOF')

config = platform.configure(CConfig)

FILEP = rffi.COpaquePtr("FILE")
OFF_T = config['off_t']

_IONBF = config['_IONBF']
_IOLBF = config['_IOLBF']
_IOFBF = config['_IOFBF']
BUFSIZ = config['BUFSIZ']
EOF = config['EOF']

BASE_BUF_SIZE = 4096
BASE_LINE_SIZE = 100

NEWLINE_UNKNOWN = 0
NEWLINE_CR = 1
NEWLINE_LF = 2
NEWLINE_CRLF = 4


def llexternal(*args, **kwargs):
    return rffi.llexternal(*args, compilation_info=eci, **kwargs)

c_fopen = llexternal('fopen', [rffi.CCHARP, rffi.CCHARP], FILEP,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_popen = llexternal('popen', [rffi.CCHARP, rffi.CCHARP], FILEP,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_fdopen = llexternal(('_' if os.name == 'nt' else '') + 'fdopen',
                      [rffi.INT, rffi.CCHARP], FILEP,
                      save_err=rffi.RFFI_SAVE_ERRNO)
c_tmpfile = llexternal('tmpfile', [], FILEP,
                       save_err=rffi.RFFI_SAVE_ERRNO)

c_setvbuf = llexternal('setvbuf', [FILEP, rffi.CCHARP, rffi.INT, rffi.SIZE_T],
                       rffi.INT)

c_fclose = llexternal('fclose', [FILEP], rffi.INT,
                      save_err=rffi.RFFI_SAVE_ERRNO)
c_pclose = llexternal('pclose', [FILEP], rffi.INT,
                      save_err=rffi.RFFI_SAVE_ERRNO)

def wrap_fclose(filep):
    with rposix.SuppressIPH():
        return c_fclose(filep)

def wrap_pclose(filep):
    with rposix.SuppressIPH():
        return c_fclose(filep)

# Note: the following two functions are called from __del__ methods,
# so must be 'releasegil=False'.  Otherwise, a program using both
# threads and the RFile class cannot translate.  See c684bf704d1f
c_fclose_in_del = llexternal('fclose', [FILEP], rffi.INT, releasegil=False)
c_pclose_in_del = llexternal('pclose', [FILEP], rffi.INT, releasegil=False)

def wrap_fclose_in_del(filep):
    with rposix.SuppressIPH_del():
        return c_fclose_in_del(filep)

def wrap_pclose_in_del(filep):
    with rposix.SuppressIPH_del():
        return c_pclose_in_del(filep)

_fclose2 = (wrap_fclose, wrap_fclose_in_del)
_pclose2 = (wrap_pclose, wrap_pclose_in_del)

c_getc = llexternal('getc', [FILEP], rffi.INT, macro=True)
c_ungetc = llexternal('ungetc', [rffi.INT, FILEP], rffi.INT)
c_fgets = llexternal('fgets', [rffi.CCHARP, rffi.INT, FILEP], rffi.CCHARP)
c_fread = llexternal('fread', [rffi.CCHARP, rffi.SIZE_T, rffi.SIZE_T, FILEP],
                     rffi.SIZE_T)

c_fwrite = llexternal('fwrite', [rffi.CCHARP, rffi.SIZE_T, rffi.SIZE_T, FILEP],
                      rffi.SIZE_T, save_err=rffi.RFFI_SAVE_ERRNO)
c_fflush = llexternal('fflush', [FILEP], rffi.INT,
                      save_err=rffi.RFFI_SAVE_ERRNO)
c_ftruncate = llexternal(ftruncate, [rffi.INT, OFF_T], rffi.INT, macro=True,
                         save_err=rffi.RFFI_SAVE_ERRNO)

c_fseek = llexternal('fseek', [FILEP, rffi.LONG, rffi.INT], rffi.INT,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_ftell = llexternal('ftell', [FILEP], rffi.LONG,
                     save_err=rffi.RFFI_SAVE_ERRNO)
c_fileno = llexternal(fileno, [FILEP], rffi.INT)

c_feof = llexternal('feof', [FILEP], rffi.INT)
c_ferror = llexternal('ferror', [FILEP], rffi.INT)
c_clearerr = llexternal('clearerr', [FILEP], lltype.Void)

c_stdin = rffi.CExternVariable(FILEP, 'stdin', eci, c_type='FILE*',
                               getter_only=True, declare_as_extern=False)
c_stdout = rffi.CExternVariable(FILEP, 'stdout', eci, c_type='FILE*',
                                getter_only=True, declare_as_extern=False)
c_stderr = rffi.CExternVariable(FILEP, 'stderr', eci, c_type='FILE*',
                                getter_only=True, declare_as_extern=False)


def _error(ll_file):
    err = c_ferror(ll_file)
    c_clearerr(ll_file)
    raise IOError(err, os.strerror(err))


def _dircheck(ll_file):
    try:
        st = os.fstat(c_fileno(ll_file))
    except OSError:
        pass
    else:
        if stat.S_ISDIR(st[0]):
            err = errno.EISDIR
            raise IOError(err, os.strerror(err))


def _sanitize_mode(mode):
    if len(mode) == 0:
        raise ValueError("empty mode string")
    upos = mode.find('U')
    if upos >= 0:
        mode = mode[:upos] + mode[upos+1:]
        first = mode[0:1]
        if first == 'w' or first == 'a':
            raise ValueError("universal newline mode can only be used with "
                             "modes starting with 'r'")
        if first != 'r':
            mode = 'r' + mode
        if 'b' not in mode:
            mode = mode[0] + 'b' + mode[1:]
    elif mode[0] != 'r' and mode[0] != 'w' and mode[0] != 'a':
        raise ValueError("mode string must begin with one of 'r', 'w', 'a' "
                         "or 'U', not '%s'" % mode)
    return mode


def create_file(filename, mode="r", buffering=-1):
    newmode = _sanitize_mode(mode)
    ll_name = rffi.str2charp(filename)
    try:
        ll_mode = rffi.str2charp(newmode)
        try:
            ll_file = c_fopen(ll_name, ll_mode)
            if not ll_file:
                errno = rposix.get_saved_errno()
                raise IOError(errno, os.strerror(errno))
        finally:
            lltype.free(ll_mode, flavor='raw')
    finally:
        lltype.free(ll_name, flavor='raw')
    _dircheck(ll_file)
    f = RFile(ll_file, mode)
    f._setbufsize(buffering)
    return f


def create_fdopen_rfile(fd, mode="r", buffering=-1):
    newmode = _sanitize_mode(mode)
    ll_mode = rffi.str2charp(newmode)
    try:
        with rposix.SuppressIPH():
            ll_file = c_fdopen(fd, ll_mode)
        if not ll_file:
            errno = rposix.get_saved_errno()
            raise OSError(errno, os.strerror(errno))
    finally:
        lltype.free(ll_mode, flavor='raw')
    _dircheck(ll_file)
    f = RFile(ll_file, mode)
    f._setbufsize(buffering)
    return f


def create_temp_rfile():
    res = c_tmpfile()
    if not res:
        errno = rposix.get_saved_errno()
        raise OSError(errno, os.strerror(errno))
    return RFile(res)


def create_popen_file(command, type):
    ll_command = rffi.str2charp(command)
    try:
        ll_type = rffi.str2charp(type)
        try:
            ll_file = c_popen(ll_command, ll_type)
            if not ll_file:
                errno = rposix.get_saved_errno()
                raise OSError(errno, os.strerror(errno))
        finally:
            lltype.free(ll_type, flavor='raw')
    finally:
        lltype.free(ll_command, flavor='raw')
    return RFile(ll_file, close2=_pclose2)


def create_stdio():
    close2 = (None, None)
    stdin = RFile(c_stdin(), close2=close2)
    stdout = RFile(c_stdout(), close2=close2)
    stderr = RFile(c_stderr(), close2=close2)
    return stdin, stdout, stderr


def write_int(f, l):
    if sys.maxint == 2147483647:
        f.write(chr(l & 0xff) +
                chr((l >> 8) & 0xff) +
                chr((l >> 16) & 0xff) +
                chr((l >> 24) & 0xff))
    else:
        f.write(chr(l & 0xff) + 
                chr((l >> 8) & 0xff) +
                chr((l >> 16) & 0xff) +
                chr((l >> 24) & 0xff) +
                chr((l >> 32) & 0xff) +
                chr((l >> 40) & 0xff) +
                chr((l >> 48) & 0xff) +
                chr((l >> 56) & 0xff))

class RFile(object):
    _setbuf = lltype.nullptr(rffi.CCHARP.TO)
    _univ_newline = False
    _newlinetypes = NEWLINE_UNKNOWN
    _skipnextlf = False

    def __init__(self, ll_file, mode=None, close2=_fclose2):
        self._ll_file = ll_file
        if mode is not None:
            self._univ_newline = 'U' in mode
        self._close2 = close2

    def _setbufsize(self, bufsize):
        if bufsize >= 0:
            if bufsize == 0:
                mode = _IONBF
            elif bufsize == 1:
                mode = _IOLBF
                bufsize = BUFSIZ
            else:
                mode = _IOFBF
            if self._setbuf:
                lltype.free(self._setbuf, flavor='raw')
            if mode == _IONBF:
                self._setbuf = lltype.nullptr(rffi.CCHARP.TO)
            else:
                self._setbuf = lltype.malloc(rffi.CCHARP.TO, bufsize, flavor='raw')
            c_setvbuf(self._ll_file, self._setbuf, mode, bufsize)

    def __del__(self):
        """Closes the described file when the object's last reference
        goes away.  Unlike an explicit call to close(), this is meant
        as a last-resort solution and cannot release the GIL or return
        an error code."""
        ll_file = self._ll_file
        if ll_file:
            do_close = self._close2[1]
            if do_close:
                do_close(ll_file)       # return value ignored
            if self._setbuf:
                lltype.free(self._setbuf, flavor='raw')

    def _cleanup_(self):
        self._ll_file = lltype.nullptr(FILEP.TO)

    def close(self):
        """Closes the described file.

        Attention! Unlike Python semantics, `close' does not return `None' upon
        success but `0', to be able to return an exit code for popen'ed files.

        The actual return value may be determined with os.WEXITSTATUS.
        """
        res = 0
        ll_file = self._ll_file
        if ll_file:
            # double close is allowed
            self._ll_file = lltype.nullptr(FILEP.TO)
            rgc.may_ignore_finalizer(self)
            do_close = self._close2[0]
            try:
                if do_close:
                    res = do_close(ll_file)
                    if res == -1:
                        errno = rposix.get_saved_errno()
                        raise IOError(errno, os.strerror(errno))
            finally:
                if self._setbuf:
                    lltype.free(self._setbuf, flavor='raw')
                    self._setbuf = lltype.nullptr(rffi.CCHARP.TO)
        return res

    def _check_closed(self):
        if not self._ll_file:
            raise ValueError("I/O operation on closed file")

    @property
    def closed(self):
        return not self._ll_file

    def _fread(self, buf, n, stream):
        if not self._univ_newline:
            return c_fread(buf, 1, n, stream)

        i = 0
        dst = buf
        newlinetypes = self._newlinetypes
        skipnextlf = self._skipnextlf
        while n:
            nread = c_fread(dst, 1, n, stream)
            if nread == 0:
                break

            src = dst
            n -= nread
            shortread = n != 0
            while nread:
                nread -= 1
                c = src[0]
                src = rffi.ptradd(src, 1)
                if c == '\r':
                    dst[0] = '\n'
                    dst = rffi.ptradd(dst, 1)
                    i += 1
                    skipnextlf = True
                elif skipnextlf and c == '\n':
                    skipnextlf = False
                    newlinetypes |= NEWLINE_CRLF
                    n += 1
                else:
                    if c == '\n':
                        newlinetypes |= NEWLINE_LF
                    elif skipnextlf:
                        newlinetypes |= NEWLINE_CR
                    dst[0] = c
                    dst = rffi.ptradd(dst, 1)
                    i += 1
                    skipnextlf = False
            if shortread:
                if skipnextlf and c_feof(stream):
                    newlinetypes |= NEWLINE_CR
                break
        self._newlinetypes = newlinetypes
        self._skipnextlf = skipnextlf
        return i

    def read(self, size=-1):
        # XXX CPython uses a more delicate logic here
        self._check_closed()
        ll_file = self._ll_file
        if size == 0:
            return ""
        elif size < 0:
            # read the entire contents
            buf = lltype.malloc(rffi.CCHARP.TO, BASE_BUF_SIZE, flavor='raw')
            try:
                s = StringBuilder()
                while True:
                    returned_size = self._fread(buf, BASE_BUF_SIZE, ll_file)
                    returned_size = intmask(returned_size)  # is between 0 and BASE_BUF_SIZE
                    if returned_size == 0:
                        if c_feof(ll_file):
                            # ok, finished
                            return s.build()
                        raise _error(ll_file)
                    s.append_charpsize(buf, returned_size)
            finally:
                lltype.free(buf, flavor='raw')
        else:  # size > 0
            with rffi.scoped_alloc_buffer(size) as buf:
                returned_size = self._fread(buf.raw, size, ll_file)
                returned_size = intmask(returned_size)  # is between 0 and size
                if returned_size == 0:
                    if not c_feof(ll_file):
                        raise _error(ll_file)
                s = buf.str(returned_size)
                assert s is not None
            return s

    def _readline1(self, raw_buf):
        ll_file = self._ll_file
        for i in range(BASE_LINE_SIZE):
            raw_buf[i] = '\n'

        result = c_fgets(raw_buf, BASE_LINE_SIZE, ll_file)
        if not result:
            if c_feof(ll_file):   # ok
                return 0
            raise _error(ll_file)

        # Assume that fgets() works as documented, and additionally
        # never writes beyond the final \0, which the CPython
        # fileobject.c says appears to be the case everywhere.
        # The only case where the buffer was not big enough is the
        # case where the buffer is full, ends with \0, and doesn't
        # end with \n\0.

        p = 0
        while raw_buf[p] != '\n':
            p += 1
            if p == BASE_LINE_SIZE:
                # fgets read whole buffer without finding newline
                return -1
        # p points to first \n

        if p + 1 < BASE_LINE_SIZE and raw_buf[p + 1] == '\0':
            # \n followed by \0, fgets read and found newline
            return p + 1
        else:
            # \n not followed by \0, fgets read but didnt find newline
            assert p > 0 and raw_buf[p - 1] == '\0'
            return p - 1

    def readline(self, size=-1):
        self._check_closed()
        if size == 0:
            return ""
        elif size < 0 and not self._univ_newline:
            with rffi.scoped_alloc_buffer(BASE_LINE_SIZE) as buf:
                c = self._readline1(buf.raw)
                if c >= 0:
                    return buf.str(c)

                # this is the rare case: the line is longer than BASE_LINE_SIZE
                s = StringBuilder()
                while True:
                    s.append_charpsize(buf.raw, BASE_LINE_SIZE - 1)
                    c = self._readline1(buf.raw)
                    if c >= 0:
                        break
                s.append_charpsize(buf.raw, c)
            return s.build()
        else:  # size > 0 or self._univ_newline
            ll_file = self._ll_file
            c = 0
            s = StringBuilder()
            if self._univ_newline:
                newlinetypes = self._newlinetypes
                skipnextlf = self._skipnextlf
                while size < 0 or s.getlength() < size:
                    c = c_getc(ll_file)
                    if c == EOF:
                        break
                    if skipnextlf:
                        skipnextlf = False
                        if c == ord('\n'):
                            newlinetypes |= NEWLINE_CRLF
                            c = c_getc(ll_file)
                            if c == EOF:
                                break
                        else:
                            newlinetypes |= NEWLINE_CR
                    if c == ord('\r'):
                        skipnextlf = True
                        c = ord('\n')
                    elif c == ord('\n'):
                        newlinetypes |= NEWLINE_LF
                    s.append(chr(c))
                    if c == ord('\n'):
                        break
                if c == EOF:
                    if skipnextlf:
                        newlinetypes |= NEWLINE_CR
                self._newlinetypes = newlinetypes
                self._skipnextlf = skipnextlf
            else:
                while s.getlength() < size:
                    c = c_getc(ll_file)
                    if c == EOF:
                        break
                    s.append(chr(c))
                    if c == ord('\n'):
                        break
            if c == EOF:
                if c_ferror(ll_file):
                    raise _error(ll_file)
            return s.build()

    @enforceargs(None, str)
    def write(self, value):
        self._check_closed()
        with rffi.scoped_nonmovingbuffer(value) as ll_value:
            # note that since we got a nonmoving buffer, it is either raw
            # or already cannot move, so the arithmetics below are fine
            length = len(value)
            bytes = c_fwrite(ll_value, 1, length, self._ll_file)
            if bytes != length:
                errno = rposix.get_saved_errno()
                c_clearerr(self._ll_file)
                raise IOError(errno, os.strerror(errno))

    def flush(self):
        self._check_closed()
        res = c_fflush(self._ll_file)
        if res != 0:
            errno = rposix.get_saved_errno()
            raise IOError(errno, os.strerror(errno))

    def truncate(self, arg=-1):
        self._check_closed()
        if arg == -1:
            arg = self.tell()
        self.flush()
        res = c_ftruncate(self.fileno(), arg)
        if res == -1:
            errno = rposix.get_saved_errno()
            raise IOError(errno, os.strerror(errno))

    def seek(self, pos, whence=0):
        self._check_closed()
        res = c_fseek(self._ll_file, pos, whence)
        if res == -1:
            errno = rposix.get_saved_errno()
            raise IOError(errno, os.strerror(errno))
        self._skipnextlf = False

    def tell(self):
        self._check_closed()
        res = intmask(c_ftell(self._ll_file))
        if res == -1:
            errno = rposix.get_saved_errno()
            raise IOError(errno, os.strerror(errno))
        if self._skipnextlf:
            c = c_getc(self._ll_file)
            if c == ord('\n'):
                self._newlinetypes |= NEWLINE_CRLF
                res += 1
                self._skipnextlf = False
            elif c != EOF:
                c_ungetc(c, self._ll_file)
        return res

    def fileno(self):
        self._check_closed()
        return intmask(c_fileno(self._ll_file))

    def isatty(self):
        self._check_closed()
        return os.isatty(c_fileno(self._ll_file))

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
