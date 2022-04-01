"""Interp-level mmap-like object.

Note that all the methods assume that the mmap is valid (or writable, for
writing methods).  You have to call check_valid() from the higher-level API,
as well as maybe check_writeable().  In the case of PyPy, this is done from
pypy/module/mmap/.
"""

from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib import rposix
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.nonconst import NonConstant
from rpython.rlib.rarithmetic import intmask

import sys
import os
import platform
import stat

_POSIX = os.name == "posix"
_MS_WINDOWS = os.name == "nt"
_64BIT = "64bit" in platform.architecture()[0]
_CYGWIN = "cygwin" == sys.platform

class RMMapError(Exception):
    def __init__(self, message):
        self.message = message

class RValueError(RMMapError):
    pass

class RTypeError(RMMapError):
    pass

includes = ["sys/types.h"]
if _POSIX:
    includes += ['unistd.h', 'sys/mman.h']
elif _MS_WINDOWS:
    includes += ['winsock2.h', 'windows.h']

class CConfig:
    _compilation_info_ = ExternalCompilationInfo(
        includes=includes,
        #pre_include_bits=['#ifndef _GNU_SOURCE\n' +
        #                  '#define _GNU_SOURCE\n' +
        #                  '#endif']
        # ^^^ _GNU_SOURCE is always defined by the ExternalCompilationInfo now
    )
    size_t = rffi_platform.SimpleType("size_t", rffi.LONG)
    off_t = rffi_platform.SimpleType("off_t", rffi.LONG)

constants = {}
if _POSIX:
    # constants, look in sys/mman.h and platform docs for the meaning
    # some constants are linux only so they will be correctly exposed outside
    # depending on the OS
    constant_names = ['MAP_SHARED', 'MAP_PRIVATE', 'MAP_FIXED',
                      'PROT_READ', 'PROT_WRITE',
                      'MS_SYNC']
    opt_constant_names = ['MAP_ANON', 'MAP_ANONYMOUS', 'MAP_NORESERVE',
                          'PROT_EXEC',
                          'MAP_DENYWRITE', 'MAP_EXECUTABLE']
    for name in constant_names:
        setattr(CConfig, name, rffi_platform.ConstantInteger(name))
    for name in opt_constant_names:
        setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))

    CConfig.MREMAP_MAYMOVE = (
        rffi_platform.DefinedConstantInteger("MREMAP_MAYMOVE"))
    CConfig.has_mremap = rffi_platform.Has('mremap(NULL, 0, 0, 0)')
    CConfig.has_madvise = rffi_platform.Has('madvise(NULL, 0, 0)')
    # ^^ both are a dirty hack, this is probably a macro

    CConfig.MADV_DONTNEED = (
        rffi_platform.DefinedConstantInteger('MADV_DONTNEED'))
    CConfig.MADV_FREE = (
        rffi_platform.DefinedConstantInteger('MADV_FREE'))

    madv_constant_names = [
        "MADV_NORMAL",
        "MADV_RANDOM",
        "MADV_SEQUENTIAL",
        "MADV_WILLNEED",

        #Linux-specific
        "MADV_REMOVE",
        "MADV_DONTFORK",
        "MADV_DOFORK",
        "MADV_HWPOISON",
        "MADV_MERGEABLE",
        "MADV_UNMERGEABLE",
        "MADV_SOFT_OFFLINE",
        "MADV_HUGEPAGE",
        "MADV_NOHUGEPAGE",
        "MADV_DONTDUMP",
        "MADV_DODUMP",

        # FreeBSD-specific
        "MADV_NOSYNC",
        "MADV_AUTOSYNC",
        "MADV_NOCORE",
        "MADV_CORE",
        "MADV_PROTECT",
    ]
    for name in madv_constant_names:
        setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))


elif _MS_WINDOWS:
    constant_names = ['PAGE_READONLY', 'PAGE_READWRITE', 'PAGE_WRITECOPY',
                      'FILE_MAP_READ', 'FILE_MAP_WRITE', 'FILE_MAP_COPY',
                      'DUPLICATE_SAME_ACCESS', 'MEM_COMMIT', 'MEM_RESERVE',
                      'MEM_RELEASE', 'PAGE_EXECUTE_READWRITE', 'PAGE_NOACCESS',
                      'MEM_RESET']
    for name in constant_names:
        setattr(CConfig, name, rffi_platform.ConstantInteger(name))

    from rpython.rlib import rwin32

    from rpython.rlib.rwin32 import HANDLE, LPHANDLE
    from rpython.rlib.rwin32 import NULL_HANDLE, INVALID_HANDLE_VALUE
    from rpython.rlib.rwin32 import DWORD, WORD, DWORD_PTR, LPDWORD
    from rpython.rlib.rwin32 import BOOL, LPVOID, LPCSTR, SIZE_T
    from rpython.rlib.rwin32 import LONG, PLONG

# export the constants inside and outside. see __init__.py
cConfig = rffi_platform.configure(CConfig)
constants.update(cConfig)

if _POSIX:
    # MAP_ANONYMOUS is not always present but it's always available at CPython level
    if constants["MAP_ANONYMOUS"] is None:
        constants["MAP_ANONYMOUS"] = constants["MAP_ANON"]
    assert constants["MAP_ANONYMOUS"] is not None
    constants["MAP_ANON"] = constants["MAP_ANONYMOUS"]

locals().update(constants)

_ACCESS_DEFAULT, ACCESS_READ, ACCESS_WRITE, ACCESS_COPY = range(4)

if rffi.sizeof(off_t) > rffi.sizeof(lltype.Signed):
    HAVE_LARGEFILE_SUPPORT = True
else:
    HAVE_LARGEFILE_SUPPORT = False

def external(name, args, result, save_err_on_unsafe=0, save_err_on_safe=0,
             **kwargs):
    unsafe = rffi.llexternal(name, args, result,
                             compilation_info=CConfig._compilation_info_,
                             save_err=save_err_on_unsafe,
                             **kwargs)
    safe = rffi.llexternal(name, args, result,
                           compilation_info=CConfig._compilation_info_,
                           sandboxsafe=True, releasegil=False,
                           save_err=save_err_on_safe,
                           **kwargs)
    return unsafe, safe

def winexternal(name, args, result, **kwargs):
    unsafe = rffi.llexternal(name, args, result,
                           compilation_info=CConfig._compilation_info_,
                           calling_conv='win',
                           **kwargs)
    safe = rffi.llexternal(name, args, result,
                           compilation_info=CConfig._compilation_info_,
                           calling_conv='win',
                           sandboxsafe=True, releasegil=False,
                           **kwargs)
    return unsafe, safe

PTR = rffi.CCHARP

if _CYGWIN:
    # XXX: macro=True hack for newer versions of Cygwin (as of 12/2012)
    _, c_malloc_safe = external('malloc', [size_t], PTR, macro=True)
    _, c_free_safe = external('free', [PTR], lltype.Void, macro=True)

c_memmove, _ = external('memmove', [PTR, PTR, size_t], lltype.Void)

if _POSIX:
    has_mremap = cConfig['has_mremap']
    has_madvise = cConfig['has_madvise']
    c_mmap, c_mmap_safe = external('mmap', [PTR, size_t, rffi.INT, rffi.INT,
                                   rffi.INT, off_t], PTR, macro=True,
                                   save_err_on_unsafe=rffi.RFFI_SAVE_ERRNO)
    # 'mmap' on linux32 is a macro that calls 'mmap64'
    _, c_munmap_safe = external('munmap', [PTR, size_t], rffi.INT)
    c_msync, _ = external('msync', [PTR, size_t, rffi.INT], rffi.INT,
                          save_err_on_unsafe=rffi.RFFI_SAVE_ERRNO)
    if has_mremap:
        c_mremap, _ = external('mremap',
                               [PTR, size_t, size_t, rffi.ULONG], PTR)
    if has_madvise:
        _, c_madvise_safe = external('madvise', [PTR, size_t, rffi.INT],
                                     rffi.INT, _nowrapper=True)

    # this one is always safe
    _pagesize = rffi_platform.getintegerfunctionresult('getpagesize',
                                                       includes=includes)
    _get_allocation_granularity = _get_page_size = lambda: _pagesize

elif _MS_WINDOWS:

    class ComplexCConfig:
        _compilation_info_ = CConfig._compilation_info_

        SYSINFO_STRUCT = rffi.CStruct(
            'SYSINFO_STRUCT',
                ("wProcessorArchitecture", WORD),
                ("wReserved", WORD),
        )

        SYSINFO_UNION = rffi.CStruct(
            'union SYSINFO_UNION',
                ("dwOemId", DWORD),
                ("_struct_", SYSINFO_STRUCT),
        )
        # sorry, I can't find a way to insert the above
        # because the union field has no name
        SYSTEM_INFO = rffi_platform.Struct(
            'SYSTEM_INFO', [
                ## ("_union_", SYSINFO_UNION),
                ## instead, we put the smaller fields, here
                ("wProcessorArchitecture", WORD),
                ("wReserved", WORD),
                ## should be a union. dwOemId is obsolete, anyway
                ("dwPageSize", DWORD),
                ("lpMinimumApplicationAddress", LPVOID),
                ("lpMaximumApplicationAddress", LPVOID),
                ("dwActiveProcessorMask", DWORD_PTR),
                ("dwNumberOfProcessors", DWORD),
                ("dwProcessorType", DWORD),
                ("dwAllocationGranularity", DWORD),
                ("wProcessorLevel", WORD),
                ("wProcessorRevision", WORD),
            ])

    config = rffi_platform.configure(ComplexCConfig)
    SYSTEM_INFO = config['SYSTEM_INFO']
    SYSTEM_INFO_P = lltype.Ptr(SYSTEM_INFO)

    GetSystemInfo, _ = winexternal('GetSystemInfo', [SYSTEM_INFO_P], lltype.Void)
    GetFileSize, _ = winexternal('GetFileSize', [HANDLE, LPDWORD], DWORD,
                                 save_err=rffi.RFFI_SAVE_LASTERROR)
    GetCurrentProcess, _ = winexternal('GetCurrentProcess', [], HANDLE)
    DuplicateHandle, _ = winexternal('DuplicateHandle',
                                     [HANDLE, HANDLE, HANDLE, LPHANDLE, DWORD,
                                      BOOL, DWORD], BOOL,
                                     save_err=rffi.RFFI_SAVE_LASTERROR)
    CreateFileMapping, _ = winexternal('CreateFileMappingA',
                                       [HANDLE, rwin32.LPSECURITY_ATTRIBUTES,
                                        DWORD, DWORD, DWORD, LPCSTR], HANDLE,
                                       save_err=rffi.RFFI_SAVE_LASTERROR)
    MapViewOfFile, _ = winexternal('MapViewOfFile', [HANDLE, DWORD, DWORD,
                                                     DWORD, SIZE_T], LPCSTR,
                                   save_err=rffi.RFFI_SAVE_LASTERROR) ##!!LPVOID
    _, UnmapViewOfFile_safe = winexternal('UnmapViewOfFile', [LPCSTR], BOOL)
    FlushViewOfFile, _ = winexternal('FlushViewOfFile', [LPCSTR, SIZE_T], BOOL)
    SetFilePointer, _ = winexternal('SetFilePointer', [HANDLE, LONG, PLONG, DWORD], DWORD)
    SetEndOfFile, _ = winexternal('SetEndOfFile', [HANDLE], BOOL)
    VirtualAlloc, VirtualAlloc_safe = winexternal('VirtualAlloc',
                               [rffi.VOIDP, rffi.SIZE_T, DWORD, DWORD],
                               rffi.VOIDP)
    _, _VirtualAlloc_safe_no_wrapper = winexternal('VirtualAlloc',
                               [rffi.VOIDP, rffi.SIZE_T, DWORD, DWORD],
                               rffi.VOIDP, _nowrapper=True)
    _, _VirtualProtect_safe = winexternal('VirtualProtect',
                                  [rffi.VOIDP, rffi.SIZE_T, DWORD, LPDWORD],
                                  BOOL)
    @specialize.ll()
    def VirtualProtect(addr, size, mode, oldmode_ptr):
        return _VirtualProtect_safe(addr,
                               rffi.cast(rffi.SIZE_T, size),
                               rffi.cast(DWORD, mode),
                               oldmode_ptr)
    VirtualFree, VirtualFree_safe = winexternal('VirtualFree',
                              [rffi.VOIDP, rffi.SIZE_T, DWORD], BOOL)

    def _get_page_size():
        try:
            si = rffi.make(SYSTEM_INFO)
            GetSystemInfo(si)
            return int(si.c_dwPageSize)
        finally:
            lltype.free(si, flavor="raw")

    def _get_allocation_granularity():
        try:
            si = rffi.make(SYSTEM_INFO)
            GetSystemInfo(si)
            return int(si.c_dwAllocationGranularity)
        finally:
            lltype.free(si, flavor="raw")

    def _get_file_size(handle):
        # XXX use native Windows types like WORD
        high_ref = lltype.malloc(LPDWORD.TO, 1, flavor='raw')
        try:
            low = GetFileSize(handle, high_ref)
            low = rffi.cast(lltype.Signed, low)
            # XXX should be propagate the real type, allowing
            # for 2*sys.maxint?
            high = high_ref[0]
            high = rffi.cast(lltype.Signed, high)
            # low might just happen to have the value INVALID_FILE_SIZE
            # so we need to check the last error also
            INVALID_FILE_SIZE = -1
            if low == INVALID_FILE_SIZE:
                err = rwin32.GetLastError_saved()
                if err:
                    raise WindowsError(err, "mmap")
            return low, high
        finally:
            lltype.free(high_ref, flavor='raw')

    INVALID_HANDLE = INVALID_HANDLE_VALUE
    has_madvise = False

PAGESIZE = _get_page_size()
ALLOCATIONGRANULARITY = _get_allocation_granularity()
NULL = lltype.nullptr(PTR.TO)
NODATA = lltype.nullptr(PTR.TO)

class MMap(object):
    def __init__(self, access, offset):
        self.size = 0
        self.pos = 0
        self.access = access
        self.offset = offset

        if _MS_WINDOWS:
            self.map_handle = NULL_HANDLE
            self.file_handle = NULL_HANDLE
            self.tagname = ""
        elif _POSIX:
            self.fd = -1
            self.closed = False

    def check_valid(self):
        if _MS_WINDOWS:
            to_close = self.map_handle == INVALID_HANDLE
        elif _POSIX:
            to_close = self.closed

        if to_close:
            raise RValueError("map closed or invalid")

    def check_writeable(self):
        if not (self.access != ACCESS_READ):
            raise RTypeError("mmap can't modify a readonly memory map.")

    def check_resizeable(self):
        if not (self.access == ACCESS_WRITE or self.access == _ACCESS_DEFAULT):
            raise RTypeError("mmap can't resize a readonly or copy-on-write memory map.")

    def setdata(self, data, size):
        """Set the internal data and map size from a PTR."""
        assert size >= 0
        self.data = data
        self.size = size

    def unmap(self):
        if _MS_WINDOWS:
            UnmapViewOfFile_safe(self.getptr(0))
        elif _POSIX:
            self.unmap_range(0, self.size)

    if _POSIX:
        def unmap_range(self, offset, size):
            """Unmap (a portion of) the mapped range.

            Per munmap(1), the offset must be a multiple of the page size,
            and the size will be rounded up to a multiple of the page size.
            """
            c_munmap_safe(self.getptr(offset), size)

    def close(self):
        if _MS_WINDOWS:
            if self.size > 0:
                self.unmap()
                self.setdata(NODATA, 0)
            if self.map_handle != INVALID_HANDLE:
                rwin32.CloseHandle_no_err(self.map_handle)
                self.map_handle = INVALID_HANDLE
            if self.file_handle != INVALID_HANDLE:
                rwin32.CloseHandle_no_err(self.file_handle)
                self.file_handle = INVALID_HANDLE
        elif _POSIX:
            self.closed = True
            if self.fd != -1:
                # XXX this is buggy - raising in an RPython del is not a good
                #     idea, we should swallow the exception or ignore the
                #     underlaying close error code
                os.close(self.fd)
                self.fd = -1
            if self.size > 0:
                self.unmap()
                self.setdata(NODATA, 0)

    def __del__(self):
        self.close()

    def read_byte(self):
        if self.pos < self.size:
            value = self.data[self.pos]
            self.pos += 1
            return value
        else:
            raise RValueError("read byte out of range")

    def readline(self):
        data = self.data
        for pos in xrange(self.pos, self.size):
            if data[pos] == '\n':
                eol = pos + 1 # we're interested in the position after new line
                break
        else: # no '\n' found
            eol = self.size

        res = self.getslice(self.pos, eol - self.pos)
        self.pos += len(res)
        return res

    def read(self, num=-1):
        if num < 0:
            # read all
            eol = self.size
        else:
            eol = self.pos + num
            # silently adjust out of range requests
            if eol > self.size:
                eol = self.size

        res = self.getslice(self.pos, eol - self.pos)
        self.pos += len(res)
        return res

    def find(self, tofind, start, end, reverse=False):
        # XXX naive! how can we reuse the rstr algorithm?
        if start < 0:
            start += self.size
            if start < 0:
                start = 0
        if end < 0:
            end += self.size
            if end < 0:
                end = 0
        elif end > self.size:
            end = self.size
        #
        upto = end - len(tofind)
        if not reverse:
            step = 1
            p = start
            if p > upto:
                return -1      # failure (empty range to search)
        else:
            step = -1
            p = upto
            upto = start
            if p < upto:
                return -1      # failure (empty range to search)
        #
        data = self.data
        while True:
            assert p >= 0
            for q in range(len(tofind)):
                if data[p+q] != tofind[q]:
                    break     # position 'p' is not a match
            else:
                # full match
                return p
            #
            if p == upto:
                return -1   # failure
            p += step

    def seek(self, pos, whence=0):
        dist = pos
        how = whence

        if how == 0: # relative to start
            where = dist
        elif how == 1: # relative to current position
            where = self.pos + dist
        elif how == 2: # relative to the end
            where = self.size + dist
        else:
            raise RValueError("unknown seek type")

        if not (0 <= where <= self.size):
            raise RValueError("seek out of range")

        self.pos = intmask(where)

    def tell(self):
        return self.pos

    def file_size(self):
        size = self.size
        if _MS_WINDOWS:
            if self.file_handle != INVALID_HANDLE:
                low, high = _get_file_size(self.file_handle)
                if not high and low <= sys.maxint:
                    return low
                # not so sure if the signed/unsigned strictness is a good idea:
                high = rffi.cast(lltype.Unsigned, high)
                low = rffi.cast(lltype.Unsigned, low)
                size = (high << 32) + low
                size = rffi.cast(lltype.Signed, size)
        elif _POSIX:
            st = os.fstat(self.fd)
            size = st[stat.ST_SIZE]
        return size

    def write(self, data):
        data_len = len(data)
        start = self.pos
        if start + data_len > self.size:
            raise RValueError("data out of range")

        self.setslice(start, data)
        self.pos = start + data_len
        return data_len

    def write_byte(self, byte):
        if len(byte) != 1:
            raise RTypeError("write_byte() argument must be char")

        if self.pos >= self.size:
            raise RValueError("write byte out of range")

        self.data[self.pos] = byte[0]
        self.pos += 1

    def getptr(self, offset):
        return rffi.ptradd(self.data, offset)

    def getslice(self, start, length):
        if length < 0:
            return ''
        return rffi.charpsize2str(self.getptr(start), length)

    def setslice(self, start, newdata):
        internaldata = self.data
        for i in range(len(newdata)):
            internaldata[start+i] = newdata[i]

    def flush(self, offset=0, size=0):
        if size == 0:
            size = self.size
        if offset < 0 or size < 0 or offset + size > self.size:
            raise RValueError("flush values out of range")
        else:
            start = self.getptr(offset)
            if _MS_WINDOWS:
                res = FlushViewOfFile(start, size)
                # XXX res == 0 means that an error occurred, but in CPython
                # this is not checked
                return res
            elif _POSIX:
                res = c_msync(start, size, MS_SYNC)
                if res == -1:
                    errno = rposix.get_saved_errno()
                    raise OSError(errno, os.strerror(errno))

        return 0

    def move(self, dest, src, count):
        # check boundings
        if (src < 0 or dest < 0 or count < 0 or
                src + count > self.size or dest + count > self.size):
            raise RValueError("source or destination out of range")

        datasrc = self.getptr(src)
        datadest = self.getptr(dest)
        c_memmove(datadest, datasrc, count)

    def resize(self, newsize):
        if _POSIX:
            if not has_mremap:
                raise RValueError("mmap: resizing not available--no mremap()")

            # resize the underlying file first, if there is one
            if self.fd >= 0:
                os.ftruncate(self.fd, self.offset + newsize)

            # now resize the mmap
            newdata = c_mremap(self.getptr(0), self.size, newsize,
                               MREMAP_MAYMOVE or 0)
            self.setdata(newdata, newsize)
        elif _MS_WINDOWS:
            # disconnect the mapping
            self.unmap()
            rwin32.CloseHandle_no_err(self.map_handle)

            # move to the desired EOF position
            if _64BIT:
                newsize_high = (self.offset + newsize) >> 32
                newsize_low = (self.offset + newsize) & 0xFFFFFFFF
                offset_high = self.offset >> 32
                offset_low = self.offset & 0xFFFFFFFF
            else:
                newsize_high = 0
                newsize_low = self.offset + newsize
                offset_high = 0
                offset_low = self.offset

            FILE_BEGIN = 0
            high_ref = lltype.malloc(PLONG.TO, 1, flavor='raw')
            try:
                high_ref[0] = rffi.cast(LONG, newsize_high)
                SetFilePointer(self.file_handle, newsize_low, high_ref,
                               FILE_BEGIN)
            finally:
                lltype.free(high_ref, flavor='raw')
            # resize the file
            SetEndOfFile(self.file_handle)
            # create another mapping object and remap the file view
            res = CreateFileMapping(self.file_handle, NULL, PAGE_READWRITE,
                                    newsize_high, newsize_low, self.tagname)
            self.map_handle = res

            if self.map_handle:
                data = MapViewOfFile(self.map_handle, FILE_MAP_WRITE,
                                     offset_high, offset_low, newsize)
                if data:
                    # XXX we should have a real LPVOID which must always be casted
                    charp = rffi.cast(LPCSTR, data)
                    self.setdata(charp, newsize)
                    return
            winerror = rwin32.lastSavedWindowsError()
            if self.map_handle:
                rwin32.CloseHandle_no_err(self.map_handle)
            self.map_handle = INVALID_HANDLE
            raise winerror

    def len(self):
        return self.size

    def getitem(self, index):
        # simplified version, for rpython
        self.check_valid()
        if index < 0:
            index += self.size
        return self.data[index]

    def setitem(self, index, value):
        if len(value) != 1:
            raise RValueError("mmap assignment must be "
                              "single-character string")
        if index < 0:
            index += self.size
        self.data[index] = value[0]

    if has_madvise:
        def madvise(self, flags, start, end):
            res = c_madvise_safe(rffi.cast(PTR, rffi.ptradd(self.data, + start)),
                                 rffi.cast(size_t, end),
                                 rffi.cast(rffi.INT, flags))
            if rffi.cast(lltype.Signed, res) == 0:
                return
            errno = rposix.get_saved_errno()
            raise OSError(errno, os.strerror(errno))

def _check_map_size(size):
    if size < 0:
        raise RTypeError("memory mapped size must be positive")

if _POSIX:
    def mmap(fileno, length, flags=MAP_SHARED,
             prot=PROT_WRITE | PROT_READ, access=_ACCESS_DEFAULT, offset=0):

        fd = fileno

        # check access is not there when flags and prot are there
        if access != _ACCESS_DEFAULT and ((flags != MAP_SHARED) or
                                          (prot != (PROT_WRITE | PROT_READ))):
            raise RValueError("mmap can't specify both access and flags, prot.")

        # check size boundaries
        _check_map_size(length)
        map_size = length
        if offset < 0:
            raise RValueError("negative offset")

        if access == ACCESS_READ:
            flags = MAP_SHARED
            prot = PROT_READ
        elif access == ACCESS_WRITE:
            flags = MAP_SHARED
            prot = PROT_READ | PROT_WRITE
        elif access == ACCESS_COPY:
            flags = MAP_PRIVATE
            prot = PROT_READ | PROT_WRITE
        elif access == _ACCESS_DEFAULT:
            # map prot to access type
            if prot & PROT_READ and prot & PROT_WRITE:
                pass  # _ACCESS_DEFAULT
            elif prot & PROT_WRITE:
                access = ACCESS_WRITE
            else:
                access = ACCESS_READ
        else:
            raise RValueError("mmap invalid access parameter.")

        # check file size
        try:
            st = os.fstat(fd)
        except OSError:
            pass     # ignore errors and trust map_size
        else:
            mode = st[stat.ST_MODE]
            size = st[stat.ST_SIZE]
            if stat.S_ISREG(mode):
                if map_size == 0:
                    if size == 0:
                        raise RValueError("cannot mmap an empty file")
                    if offset > size:
                        raise RValueError(
                            "mmap offset is greater than file size")
                    map_size = int(size - offset)
                    if map_size != size - offset:
                        raise RValueError("mmap length is too large")
                elif offset + map_size > size:
                    raise RValueError("mmap length is greater than file size")

        m = MMap(access, offset)
        if fd == -1:
            # Assume the caller wants to map anonymous memory.
            # This is the same behaviour as Windows.  mmap.mmap(-1, size)
            # on both Windows and Unix map anonymous memory.
            m.fd = -1

            flags |= MAP_ANONYMOUS

        else:
            m.fd = os.dup(fd)

        # XXX if we use hintp below in alloc, the NonConstant
        #     is necessary since we want a general version of c_mmap
        #     to be annotated with a non-constant pointer.
        res = c_mmap(NonConstant(NULL), map_size, prot, flags, fd, offset)
        if res == rffi.cast(PTR, -1):
            errno = rposix.get_saved_errno()
            raise OSError(errno, os.strerror(errno))

        m.setdata(res, map_size)
        return m

    def alloc_hinted(hintp, map_size):
        flags = MAP_PRIVATE | MAP_ANONYMOUS
        prot = PROT_EXEC | PROT_READ | PROT_WRITE
        if we_are_translated():
            flags = NonConstant(flags)
            prot = NonConstant(prot)
        return c_mmap_safe(hintp, map_size, prot, flags, -1, 0)

    def clear_large_memory_chunk_aligned(addr, map_size):
        addr = rffi.cast(PTR, addr)
        flags = MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS
        prot = PROT_READ | PROT_WRITE
        if we_are_translated():
            flags = NonConstant(flags)
            prot = NonConstant(prot)
        res = c_mmap_safe(addr, map_size, prot, flags, -1, 0)
        return res == addr

    # XXX is this really necessary?
    class Hint:
        pos = -0x4fff0000   # for reproducible results
    hint = Hint()

    def alloc(map_size):
        """Allocate memory.  This is intended to be used by the JIT,
        so the memory has the executable bit set and gets allocated
        internally in case of a sandboxed process.
        """
        from errno import ENOMEM
        from rpython.rlib import debug

        if _CYGWIN:
            # XXX: JIT memory should be using mmap MAP_PRIVATE with
            #      PROT_EXEC but Cygwin's fork() fails.  mprotect()
            #      cannot be used, but seems to be unnecessary there.
            res = c_malloc_safe(map_size)
            if res == rffi.cast(PTR, 0):
                raise MemoryError
            return res
        res = alloc_hinted(rffi.cast(PTR, hint.pos), map_size)
        if res == rffi.cast(PTR, -1):
            # some systems (some versions of OS/X?) complain if they
            # are passed a non-zero address.  Try again.
            res = alloc_hinted(rffi.cast(PTR, 0), map_size)
            if res == rffi.cast(PTR, -1):
                # ENOMEM simply raises MemoryError, but other errors are fatal
                if rposix.get_saved_errno() != ENOMEM:
                    debug.fatalerror_notb(
                        "Got an unexpected error trying to allocate some "
                        "memory for the JIT (tried to do mmap() with "
                        "PROT_EXEC|PROT_READ|PROT_WRITE).  This can be caused "
                        "by a system policy like PAX.  You need to find how "
                        "to work around the policy on your system.")
                raise MemoryError
        else:
            hint.pos += map_size
        return res
    alloc._annenforceargs_ = (int,)

    if _CYGWIN:
        free = c_free_safe
    else:
        free = c_munmap_safe

    if sys.platform.startswith('linux'):
        assert has_madvise
        assert MADV_DONTNEED is not None
        if MADV_FREE is None:
            MADV_FREE = 8     # from the kernel sources of Linux >= 4.5
        class CanUseMadvFree:
            ok = -1
        can_use_madv_free = CanUseMadvFree()
        def madvise_free(addr, map_size):
            # We don't know if we are running on a recent enough kernel
            # that supports MADV_FREE.  Check that at runtime: if the
            # first call to madvise(MADV_FREE) fails, we assume it's
            # because of EINVAL and we fall back to MADV_DONTNEED.
            if can_use_madv_free.ok != 0:
                res = c_madvise_safe(rffi.cast(PTR, addr),
                                     rffi.cast(size_t, map_size),
                                     rffi.cast(rffi.INT, MADV_FREE))
                if can_use_madv_free.ok == -1:
                    can_use_madv_free.ok = (rffi.cast(lltype.Signed, res) == 0)
            if can_use_madv_free.ok == 0:
                c_madvise_safe(rffi.cast(PTR, addr),
                               rffi.cast(size_t, map_size),
                               rffi.cast(rffi.INT, MADV_DONTNEED))
    elif has_madvise and not (MADV_FREE is MADV_DONTNEED is None):
        use_flag = MADV_FREE if MADV_FREE is not None else MADV_DONTNEED
        def madvise_free(addr, map_size):
            c_madvise_safe(rffi.cast(PTR, addr),
                           rffi.cast(size_t, map_size),
                           rffi.cast(rffi.INT, use_flag))
    else:
        def madvise_free(addr, map_size):
            "No madvise() on this platform"

elif _MS_WINDOWS:
    def mmap(fileno, length, tagname="", access=_ACCESS_DEFAULT, offset=0):
        # XXX flags is or-ed into access by now.
        flags = 0
        # check size boundaries
        _check_map_size(length)
        map_size = length
        if offset < 0:
            raise RValueError("negative offset")

        flProtect = 0
        dwDesiredAccess = 0
        fh = NULL_HANDLE

        if access == ACCESS_READ:
            flProtect = PAGE_READONLY
            dwDesiredAccess = FILE_MAP_READ
        elif access == _ACCESS_DEFAULT or access == ACCESS_WRITE:
            flProtect = PAGE_READWRITE
            dwDesiredAccess = FILE_MAP_WRITE
        elif access == ACCESS_COPY:
            flProtect = PAGE_WRITECOPY
            dwDesiredAccess = FILE_MAP_COPY
        else:
            raise RValueError("mmap invalid access parameter.")

        # assume -1 and 0 both mean invalid file descriptor
        # to 'anonymously' map memory.
        if fileno != -1 and fileno != 0:
            fh = rffi.cast(HANDLE, rwin32.get_osfhandle(fileno))
            # Win9x appears to need us seeked to zero
            # SEEK_SET = 0
            # libc._lseek(fileno, 0, SEEK_SET)

            # check file size
            try:
                low, high = _get_file_size(fh)
            except OSError:
                pass     # ignore non-seeking files and errors and trust map_size
            else:
                if not high and low <= sys.maxint:
                    size = low
                else:
                    # not so sure if the signed/unsigned strictness is a good idea:
                    high = rffi.cast(lltype.Unsigned, high)
                    low = rffi.cast(lltype.Unsigned, low)
                    size = (high << 32) + low
                    size = rffi.cast(lltype.Signed, size)
                if map_size == 0:
                    if size == 0:
                        raise RValueError("cannot mmap an empty file")
                    if offset > size:
                        raise RValueError(
                            "mmap offset is greater than file size")
                    map_size = int(size - offset)
                    if map_size != size - offset:
                        raise RValueError("mmap length is too large")
                elif offset + map_size > size:
                    raise RValueError("mmap length is greater than file size")

        m = MMap(access, offset)
        m.file_handle = INVALID_HANDLE
        m.map_handle = INVALID_HANDLE
        if fh:
            # it is necessary to duplicate the handle, so the
            # Python code can close it on us
            handle_ref = lltype.malloc(LPHANDLE.TO, 1, flavor='raw')
            handle_ref[0] = m.file_handle
            try:
                res = DuplicateHandle(GetCurrentProcess(), # source process handle
                                      fh, # handle to be duplicated
                                      GetCurrentProcess(), # target process handle
                                      handle_ref, # result
                                      0, # access - ignored due to options value
                                      False, # inherited by child procs?
                                      DUPLICATE_SAME_ACCESS) # options
                if not res:
                    raise rwin32.lastSavedWindowsError()
                m.file_handle = handle_ref[0]
            finally:
                lltype.free(handle_ref, flavor='raw')

            if not map_size:
                low, high = _get_file_size(fh)
                if _64BIT:
                    map_size = (low << 32) + 1
                else:
                    if high:
                        # file is too large to map completely
                        map_size = -1
                    else:
                        map_size = low

        if tagname:
            m.tagname = tagname

        # DWORD is a 4-byte int. If int > 4-byte it must be divided
        if _64BIT:
            size_hi = (map_size + offset) >> 32
            size_lo = (map_size + offset) & 0xFFFFFFFF
            offset_hi = offset >> 32
            offset_lo = offset & 0xFFFFFFFF
        else:
            size_hi = 0
            size_lo = map_size + offset
            offset_hi = 0
            offset_lo = offset

        flProtect |= flags
        m.map_handle = CreateFileMapping(m.file_handle, NULL, flProtect,
                                         size_hi, size_lo, m.tagname)

        if m.map_handle:
            data = MapViewOfFile(m.map_handle, dwDesiredAccess,
                                 offset_hi, offset_lo, length)
            if data:
                # XXX we should have a real LPVOID which must always be casted
                charp = rffi.cast(LPCSTR, data)
                m.setdata(charp, map_size)
                return m
        winerror = rwin32.lastSavedWindowsError()
        if m.map_handle:
            rwin32.CloseHandle_no_err(m.map_handle)
        m.map_handle = INVALID_HANDLE
        raise winerror

    class Hint:
        pos = -0x4fff0000   # for reproducible results
    hint = Hint()
    # XXX this has no effect on windows

    def alloc(map_size):
        """Allocate memory.  This is intended to be used by the JIT,
        so the memory has the executable bit set.
        XXX implement me: it should get allocated internally in
        case of a sandboxed process
        """
        null = lltype.nullptr(rffi.VOIDP.TO)
        res = VirtualAlloc_safe(null, map_size, MEM_COMMIT | MEM_RESERVE,
                           PAGE_EXECUTE_READWRITE)
        if not res:
            raise MemoryError
        arg = lltype.malloc(LPDWORD.TO, 1, zero=True, flavor='raw')
        VirtualProtect(res, map_size, PAGE_EXECUTE_READWRITE, arg)
        lltype.free(arg, flavor='raw')
        # ignore errors, just try
        return res
    alloc._annenforceargs_ = (int,)

    def free(ptr, map_size):
        VirtualFree_safe(ptr, 0, MEM_RELEASE)

    def madvise_free(addr, map_size):
        r = _VirtualAlloc_safe_no_wrapper(
            rffi.cast(rffi.VOIDP, addr),
            rffi.cast(rffi.SIZE_T, map_size),
            rffi.cast(DWORD, MEM_RESET),
            rffi.cast(DWORD, PAGE_READWRITE))
        #from rpython.rlib import debug
        #debug.debug_print("madvise_free:", r)
