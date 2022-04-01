import sys
import os

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import (
    TypeDef, generic_new_descr, GetSetProperty)
from pypy.interpreter.gateway import WrappedDefault, interp2app, unwrap_spec
from pypy.module._io.interp_iobase import (W_RawIOBase, convert_size,
        DEFAULT_BUFFER_SIZE)
from pypy.module.time.interp_time import sleep
from pypy.interpreter.unicodehelper import (fsdecode, str_decode_utf_16,
        utf8_encode_utf_16)
from pypy.module._codecs.interp_codecs import CodecState
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib._os_support import _preferred_traits
from rpython.rlib import rwin32
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.runicode import WideCharToMultiByte, MultiByteToWideChar
from rpython.rlib.rwin32file import make_win32_traits
from rpython.rlib.buffer import ByteBuffer
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.rposix import getfullpathname

# SMALLBUF determines how many utf-8 characters will be
# buffered within the stream, in order to support reads
# of less than one character
SMALLBUF = 4
# BUFMAX determines how many bytes can be read in one go.
# BUFSIZ is compiler/platform dependant and defined in stdio.h,
# but the actual values don't matter all that much
BUFMAX = (32*1024*1024)
BUFSIZ = 512

def err_closed(space):
    return oefmt(space.w_ValueError,
                "I/O operation on closed file")

def err_mode(space, state):
    # TODO sort out the state
    return oefmt(space.w_ValueError,
                "I/O operation on closed file")

def read_console_wide(space, handle, maxlen):
    """ 
    Make a blocking call to ReadConsoleW, returns wchar-encoded bytes
    """
    err = 0
    sig = 0
    # Windows uses a 16-bit wchar_t, we mimic that with bytes
    buf = ByteBuffer((maxlen + 2) * 2)
    addr = buf.get_raw_address()
    off = 0  # offset from the beginning of buf, in wchar
    # readlen is in 16 bits, readlen_b is in 8-bit bytes
    readlen = readlen_b = 0
    bufsize = BUFSIZ
    with lltype.scoped_alloc(rwin32.LPDWORD.TO, 1) as n:
        while readlen_b < maxlen:
            neg_one = rffi.cast(rwin32.DWORD, -1)
            n[0] = neg_one
            length = min(maxlen - off, bufsize)
            rwin32.SetLastError_saved(0)
            res = rwin32.ReadConsoleW(handle,
                             rffi.cast(rwin32.LPWSTR, rffi.ptradd(addr, readlen_b)),
                             length, n, rffi.cast(rwin32.LPVOID, 0))
            nread = intmask(n[0])
            err = rwin32.GetLastError_saved()
            if not res:
                break

            if nread == -1 and err == rwin32.ERROR_OPERATION_ABORTED:
                break

                
            if nread == 0:
                if err != rwin32.ERROR_OPERATION_ABORTED:
                    break
                err = 0
                # This will only catch CTRL-C on the main thread
                sleep(space, space.newfloat(0.1))
                continue
            readlen += nread
            readlen_b = 2 * readlen
            
            # We didn't manage to read the whole buffer
            # don't try again as it will just block
            if nread < length:
                break
                
            if buf.getitem(readlen_b - 2) == '\n':
                # We read a new line
                break
            
            # If the buffer ends with a high surrogate, take an extra character. 
            if (readlen_b + 1) >= maxlen:
                with lltype.scoped_alloc(rwin32.LPWORD.TO, 1) as char_type:
                    ptr = rffi.cast(rffi.CWCHARP, rffi.ptradd(addr,  + 1))
                    rwin32.GetStringTypeW(rwin32.CT_CTYPE3, ptr, 1, char_type)
                    if intmask(char_type[0]) == intmask(rwin32.C3_HIGHSURROGATE):
                        readlen_b += 2
                break
    if err:
        raise OperationError(space.w_WindowsError, space.newint(err))
    if readlen_b <=0 or buf.getitem(0) == '\x1a':
        return ''
    else:
        return buf.getslice(0, 1, readlen_b)


def _get_console_type(handle):
    mode = lltype.malloc(rwin32.LPDWORD.TO,0,flavor='raw')
    peek_count = lltype.malloc(rwin32.LPDWORD.TO,0,flavor='raw')
    try:
        if handle == rwin32.INVALID_HANDLE_VALUE:
            return '\0'

        if not rwin32.GetConsoleMode(handle, mode):
            return '\0'

        # Peek at the handle to see whether it is an input or output handle
        if rwin32.GetNumberOfConsoleInputEvents(handle, peek_count):
            return 'r'
        return 'w'
    finally:
        lltype.free(mode, flavor='raw')
        lltype.free(peek_count, flavor='raw')

def _pyio_get_console_type(space, w_path_or_fd):

    # XXX 2021-01-10 Disable WinConsoleIO (again) it is flaky. Some interaction
    # with pytest in running numpy's tests makes the handle invalid.
    # TODO: refactor the w_path_or_fd handling to be more like interp_posix
    #       and use the path_or_fd() unwrap_spec all through the _io module
    #       Then this will recieve a already-processed Path object
    # Another alternative to this whole mess would be to adapt the ctypes-based
    # https://pypi.org/project/win_unicode_console/ which also implements PEP 528

    return '\0'

    if space.isinstance_w(w_path_or_fd, space.w_int):
        fd = space.int_w(w_path_or_fd)
        handle = rwin32.get_osfhandle(fd)
        if handle == rwin32.INVALID_HANDLE_VALUE:
            return '\0'
        return _get_console_type(handle)

    decoded = space.fsdecode_w(w_path_or_fd)
    if not decoded:
        return '\0'
 
    m = '\0'

    # In CPython the _wcsicmp function is used to perform case insensitive comparison
    dlower = decoded.lower()
    if len(dlower) >=4:
        if dlower[:4] == '\\\\.\\' or dlower[:4] == '\\\\?\\':
            dlower = dlower[4:]
        if dlower[:4] == '//./' or dlower[:4] == '//?/':
            dlower = dlower[4:]
        elif dlower[:3] == 'c:\\':
            dlower = dlower[3:]
    if  dlower == 'conin$':
        m = 'r'
    elif dlower == 'conout$':
        m = 'w'
    elif dlower == 'con':
        m = 'x'
    if m != '\0':
        return m

    # Handle things like 'c:\users\user\appdata\local\temp\usession\CONOUT$
    dlower = getfullpathname(decoded).lower()
    if dlower[:4] == '\\\\.\\' or dlower[:4] == '\\\\?\\':
        dlower = dlower[4:]
    if  dlower == 'conin$':
        m = 'r'
    elif dlower == 'conout$':
        m = 'w'
    elif dlower == 'con':
        m = 'x'
    return m


class W_WinConsoleIO(W_RawIOBase):
    def __init__(self, space):
        W_RawIOBase.__init__(self, space)
        self.handle = rwin32.INVALID_HANDLE_VALUE
        self.fd = -1
        self.created = 0
        self.readable = False
        self.writable = False
        self.closehandle = False
        self.blksize = 0
        self.buf = ''

    def _dealloc_warn_w(self, space, w_source):
        buf = self.buf
        if buf:
            lltype.free(buf, flavor='raw')
        
    def _getbuffer(self, length):
        """ Get up to length wchar from self.buf
        """

        wlen = self._buflen()
        if wlen > length:
            wlen = length
        blen = wlen * 2
        if blen <= 0:
            return ''
        ret = self.buf[:blen]
        self.buf = self.buf[blen:]
        # trim out any leading '\x00'
        while self.buf and self.buf[0] == '\x00':
            self.buf == self.buf[2:]
        return ret

    def _buflen(self):
        """ get length of self.buf in wchar
        """
        wlen = len(self.buf) // 2
        for i in range(0, wlen * 2, 2):
            if self.buf[i] != '\x00':
                return i // 2
        return wlen

    @unwrap_spec(mode='text', closefd=int)
    def descr_init(self, space, w_nameobj, mode='r', closefd=True, w_opener=None):
        name = rffi.cast(rffi.CWCHARP, 0)
        self.fd = -1
        self.handle = rwin32.INVALID_HANDLE_VALUE
        self.readable = False
        self.writable = False
        self.blksize = 0
        rwa = False
        console_type = '\0'
        self.buf = ''

        if space.isinstance_w(w_nameobj, space.w_int): 
            self.fd = space.int_w(w_nameobj)
            if self.fd < 0:
                raise oefmt(space.w_ValueError,
                        "negative file descriptor")

        # make the flow analysis happy,otherwise it thinks w_path
        # is undefined later
        w_path = w_nameobj
        if self.fd < 0:
            from pypy.module.posix.interp_posix import fspath
            w_path = fspath(space, w_nameobj)
            console_type = _pyio_get_console_type(space, w_path)
            if not console_type:
                raise oefmt(space.w_ValueError,
                        "Invalid console type")
            if console_type == '\0':
                raise oefmt(space.w_ValueError,
                        "Cannot open non-console file")
        self.mode = 'u'
        for char in mode:
            if char in "+ax":
                # OK do nothing
                pass
            elif char == "b":
                self.mode = 'b'
            elif char == "r":
                if rwa:
                    raise oefmt(space.w_ValueError,
                            "invalid mode: %s", mode)
                rwa = True
                self.readable = True
                if console_type == "x":
                    console_type = "r"
            elif char == "w":
                if rwa:
                    raise oefmt(space.w_ValueError,
                            "invalid mode: %s", mode)
                rwa = True
                self.writable = True
                if console_type == 'x':
                    console_type = 'w'
            else:
                raise oefmt(space.w_ValueError,
                            "invalid mode: %s", mode)
        if not rwa:
            raise oefmt(space.w_ValueError,
                        "Must have exactly one of read or write mode")
        
        if self.fd >= 0:
            self.handle = rwin32.get_osfhandle(self.fd)
            self.closehandle = False
        else:
            access = rwin32.GENERIC_READ
            self.closehandle = True
            if not closefd:
                raise oefmt(space.w_ValueError,
                        "Cannot use closefd=False with a file name")
            if self.writable:
                access = rwin32.GENERIC_WRITE
        
            traits = _preferred_traits(space.realunicode_w(w_path))
            if not (traits.str is unicode):
                raise oefmt(space.w_ValueError,
                            "Non-unicode string name %s", traits.str)
            win32traits = make_win32_traits(traits)
            
            pathlen = space.len_w(w_path)
            name = rffi.utf82wcharp(space.utf8_w(w_path), pathlen)
            self.handle = win32traits.CreateFile(name, 
                rwin32.ALL_READ_WRITE, rwin32.SHARE_READ_WRITE,
                rffi.NULL, win32traits.OPEN_EXISTING,
                0, rffi.cast(rwin32.HANDLE, 0))
            if self.handle == rwin32.INVALID_HANDLE_VALUE:
                self.handle = win32traits.CreateFile(name, 
                    access,
                    rwin32.SHARE_READ_WRITE,
                    rffi.NULL, win32traits.OPEN_EXISTING,
                    0, rffi.cast(rwin32.HANDLE, 0))
            lltype.free(name, flavor='raw')
            
            if self.handle == rwin32.INVALID_HANDLE_VALUE:
                raise WindowsError(rwin32.GetLastError_saved(),
                                   "Failed to open handle")
        
        if console_type == '\0':
            console_type = _get_console_type(self.handle)

        if console_type == '\0': 
            raise oefmt(space.w_ValueError,
                        "Cannot open non-console file")
        
        if self.writable and console_type != 'w':
            raise oefmt(space.w_ValueError,
                        "Cannot open input buffer for writing")

        if self.readable and console_type != 'r':
            raise oefmt(space.w_ValueError,
                        "Cannot open output buffer for reading")

        self.blksize = DEFAULT_BUFFER_SIZE
    
    def readable_w(self, space):
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
        return space.newbool(self.readable)
    
    def writable_w(self, space):
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
        return space.newbool(self.writable)
    
    def isatty_w(self, space):
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
        return space.newbool(True)
    
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
            
    def fileno_w(self, space):
        traits = _preferred_traits(u"")
        win32traits = make_win32_traits(traits)
        if self.fd < 0 and self.handle != rwin32.INVALID_HANDLE_VALUE:
            if self.writable:
                self.fd = rwin32.open_osfhandle(rffi.cast(rffi.INTP, self.handle), win32traits._O_WRONLY | win32traits._O_BINARY)
            else:
                self.fd = rwin32.open_osfhandle(rffi.cast(rffi.INTP, self.handle), win32traits._O_RDONLY | win32traits._O_BINARY)
        if self.fd < 0:
            raise err_mode(space, "fileno")
        return space.newint(self.fd)
        
    def readinto_w(self, space, w_buffer):
        # Read wchar, convert to utf8, and put it into w_buffer.
        # We buffer left-over characters into self.buf
        rwbuffer = space.writebuf_w(w_buffer)
        length = rwbuffer.getlength()
        oldmode = self.mode
        self.mode = 'u'
        utf8, ulen = self.read(space, length)
        i = 0
        self.mode = oldmode
        while utf8[i] != '\x00' and i < len(utf8):
            rwbuffer[i] = utf8[i]
            i += 1
        return space.newint(i)


    def read(self, space, length):
        """ read from the console up to `length` utf-16 chars
        If mode is 'u', return `length` codepoints. If mode is `b`,
        return `length` bytes.`
        """
        
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
            
        if not self.readable:
            raise err_mode(space, "reading")
            
        if  length <= 0:
            return '', 0
            
        if length > BUFMAX:
            raise oefmt(space.w_ValueError,
                        "cannot read more than %d bytes", BUFMAX)
                        
        # first copy any remaining buffered utf16 data
        builder = StringBuilder(length)
        wbuf = self._getbuffer(length * 2)

        state = space.fromcache(CodecState)
        errh = state.decode_error_handler
        outlen = 0
        if len(wbuf) > 0:
            utf8, lgt, pos = str_decode_utf_16(wbuf, 'strict', final=True, errorhandler=errh)
            if self.mode == 'u':
                length -= lgt
                outlen += lgt
            else:
                length -= len(utf8)
                outlen += len(utf8)
            builder.append(utf8)
        
        if length > 0:
            wbuf = read_console_wide(space, self.handle, length)
            utf8, lgt, pos = str_decode_utf_16(wbuf, 'strict', final=True, errorhandler=errh)
            if 1 or self.mode == 'u':
                length -= lgt
                outlen += lgt
            else:
                length -= len(utf8)
                outlen += len(utf8)
            builder.append(utf8)

        res = builder.build()
        return res, outlen
            
    def read_w(self, space, w_size=None):
        size = convert_size(space, w_size)
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
        if not self.readable:
            raise err_mode(space,"reading")

        if size < 0:
            return self.readall_w(space)

        if size > BUFMAX:
             raise oefmt(space.w_ValueError,
                        "Cannot read more than %d bytes",
                        BUFMAX)

        # If self.mode is 'u', we want to return a unicode
        buf, length = self.read(space, size)
        if 1 or self.mode == 'u':
            return space.newtext(buf, length)
        else:
            return space.newbytes(buf)

    def readall_w(self, space):
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)

        # Read the wstr 16-bit data from the console as 8-byte bytes
        result = StringBuilder()
        while True:
            wbuf = read_console_wide(space, self.handle, BUFSIZ)
            if len(wbuf) == 0:
                break
            result.append(wbuf)
        
        wbuf = result.build()
        state = space.fromcache(CodecState)
        errh = state.decode_error_handler
        utf8, lgt, pos = str_decode_utf_16(wbuf, 'strict', final=True, errorhandler=errh)

        return space.newtext(utf8, lgt)

    def write_w(self, space, w_data):
        if self.handle == rwin32.INVALID_HANDLE_VALUE:
            raise err_closed(space)
        
        if not self.writable:
            raise err_mode(space,"writing")
        
        utf8 = space.utf8_w(w_data)
        if not len(utf8):
            return space.newint(0)
        
        # TODO: break up the encoding into chunks to save memory
        state = space.fromcache(CodecState)
        errh = state.encode_error_handler
        utf16 = utf8_encode_utf_16(utf8, 'strict', errh, allow_surrogates=False)
        wlen = len(utf16) // 2
    
        with lltype.scoped_alloc(rwin32.LPDWORD.TO, 1) as n:
            with rffi.scoped_nonmovingbuffer(utf16) as dataptr:
                # skip BOM, start at 1
                offset = 1
                while offset < wlen:
                    res = rwin32.WriteConsoleW(self.handle,
                            rffi.cast(rwin32.LPVOID, rffi.ptradd(dataptr, offset * 2)),
                            wlen - offset, n , rffi.cast(rwin32.LPVOID, 0))
                    if not res:
                        err = rwin32.GetLastError_saved()
                        raise OperationError(space.w_WindowsError, space.newint(err))
                    nwrote = intmask(n[0])
                    offset += nwrote
                return space.newint(offset - 1)
            
    def get_blksize(self,space):
        return space.newint(self.blksize)
        

W_WinConsoleIO.typedef = TypeDef(
    '_io.WinConsoleIO', W_RawIOBase.typedef,
    __new__  = generic_new_descr(W_WinConsoleIO),
    __init__  = interp2app(W_WinConsoleIO.descr_init),
    __repr__ = interp2app(W_WinConsoleIO.repr_w),
    
    readable = interp2app(W_WinConsoleIO.readable_w),
    writable = interp2app(W_WinConsoleIO.writable_w),
    isatty   = interp2app(W_WinConsoleIO.isatty_w),
    read     = interp2app(W_WinConsoleIO.read_w),
    readall  = interp2app(W_WinConsoleIO.readall_w),
    readinto = interp2app(W_WinConsoleIO.readinto_w),    
    fileno   = interp2app(W_WinConsoleIO.fileno_w),
    write    = interp2app(W_WinConsoleIO.write_w),   
    _blksize = GetSetProperty(W_WinConsoleIO.get_blksize),
    )
