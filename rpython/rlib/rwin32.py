""" External functions accessing the win32 api.
Common types, functions from core win32 libraries, such as kernel32
"""

import os
import errno

from rpython.rlib.rposix_environ import make_env_impls
from rpython.rtyper.tool import rffi_platform
from rpython.tool.udir import udir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import CompilationError
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import intmask, r_longlong, widen
from rpython.rlib import jit

# This module can be imported on any platform,
# but most symbols are not usable...
WIN32 = os.name == "nt"

if WIN32:
    eci = ExternalCompilationInfo(
        includes = ['windows.h', 'stdio.h', 'stdlib.h', 'io.h'],
        libraries = ['kernel32'],
        )
else:
    eci = ExternalCompilationInfo()

class CConfig:
    _compilation_info_ = eci

    if WIN32:
        DWORD_PTR = rffi_platform.SimpleType("DWORD_PTR", rffi.UNSIGNED)
        WORD = rffi_platform.SimpleType("WORD", rffi.USHORT)
        DWORD = rffi_platform.SimpleType("DWORD", rffi.UINT)
        BOOL = rffi_platform.SimpleType("BOOL", rffi.LONG)
        BYTE = rffi_platform.SimpleType("BYTE", rffi.UCHAR)
        WCHAR = rffi_platform.SimpleType("WCHAR", rffi.UCHAR)
        INT = rffi_platform.SimpleType("INT", rffi.INT)
        LONG = rffi_platform.SimpleType("LONG", rffi.LONG)
        PLONG = rffi_platform.SimpleType("PLONG", rffi.LONGP)
        LPVOID = rffi_platform.SimpleType("LPVOID", rffi.INTP)
        LPCVOID = rffi_platform.SimpleType("LPCVOID", rffi.VOIDP)
        LPSTR = rffi_platform.SimpleType("LPSTR", rffi.CCHARP)
        LPCSTR = rffi_platform.SimpleType("LPCSTR", rffi.CCHARP)
        LPWSTR = rffi_platform.SimpleType("LPWSTR", rffi.CWCHARP)
        LPCWSTR = rffi_platform.SimpleType("LPCWSTR", rffi.CWCHARP)
        LPDWORD = rffi_platform.SimpleType("LPDWORD", rffi.UINTP)
        LPWORD = rffi_platform.SimpleType("LPWORD", rffi.USHORTP)
        LPBOOL = rffi_platform.SimpleType("LPBOOL", rffi.LONGP)
        LPBYTE = rffi_platform.SimpleType("LPBYTE", rffi.UCHARP)
        SIZE_T = rffi_platform.SimpleType("SIZE_T", rffi.SIZE_T)
        ULONG_PTR = rffi_platform.SimpleType("ULONG_PTR", rffi.UNSIGNED)

        HRESULT = rffi_platform.SimpleType("HRESULT", rffi.LONG)
        HLOCAL = rffi_platform.SimpleType("HLOCAL", rffi.VOIDP)

        FILETIME = rffi_platform.Struct('FILETIME',
                                        [('dwLowDateTime', rffi.UINT),
                                         ('dwHighDateTime', rffi.UINT)])
        SYSTEMTIME = rffi_platform.Struct('SYSTEMTIME',
                                          [])

        Struct = rffi_platform.Struct
        COORD = Struct("COORD",
                       [("X", rffi.SHORT),
                        ("Y", rffi.SHORT)])

        SMALL_RECT = Struct("SMALL_RECT",
                            [("Left", rffi.SHORT),
                             ("Top", rffi.SHORT),
                             ("Right", rffi.SHORT),
                             ("Bottom", rffi.SHORT)])

        CONSOLE_SCREEN_BUFFER_INFO = Struct("CONSOLE_SCREEN_BUFFER_INFO",
                                            [("dwSize", COORD),
                                             ("dwCursorPosition", COORD),
                                             ("wAttributes", WORD.ctype_hint),
                                             ("srWindow", SMALL_RECT),
                                             ("dwMaximumWindowSize", COORD)])

        OSVERSIONINFOEX = rffi_platform.Struct(
            'OSVERSIONINFOEX',
            [('dwOSVersionInfoSize', rffi.UINT),
             ('dwMajorVersion', rffi.UINT),
             ('dwMinorVersion', rffi.UINT),
             ('dwBuildNumber',  rffi.UINT),
             ('dwPlatformId',  rffi.UINT),
             ('szCSDVersion', rffi.CFixedArray(lltype.Char, 1)),
             ('wServicePackMajor', rffi.USHORT),
             ('wServicePackMinor', rffi.USHORT),
             ('wSuiteMask', rffi.USHORT),
             ('wProductType', rffi.UCHAR),
         ])

        LPSECURITY_ATTRIBUTES = rffi_platform.SimpleType(
            "LPSECURITY_ATTRIBUTES", rffi.CCHARP)

        DEFAULT_LANGUAGE = rffi_platform.ConstantInteger(
            "MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)")

        defines = """FORMAT_MESSAGE_ALLOCATE_BUFFER FORMAT_MESSAGE_FROM_SYSTEM
                       MAX_PATH _MAX_ENV FORMAT_MESSAGE_IGNORE_INSERTS
                       WAIT_OBJECT_0 WAIT_TIMEOUT INFINITE
                       ERROR_INVALID_HANDLE
                       DELETE READ_CONTROL SYNCHRONIZE WRITE_DAC
                       WRITE_OWNER PROCESS_ALL_ACCESS
                       PROCESS_CREATE_PROCESS PROCESS_CREATE_THREAD
                       PROCESS_DUP_HANDLE PROCESS_QUERY_INFORMATION
                       PROCESS_SET_QUOTA
                       PROCESS_SUSPEND_RESUME PROCESS_TERMINATE
                       PROCESS_VM_OPERATION PROCESS_VM_READ
                       PROCESS_VM_WRITE
                       CTRL_C_EVENT CTRL_BREAK_EVENT
                       MB_ERR_INVALID_CHARS ERROR_NO_UNICODE_TRANSLATION
                       WC_NO_BEST_FIT_CHARS STD_INPUT_HANDLE STD_OUTPUT_HANDLE
                       STD_ERROR_HANDLE HANDLE_FLAG_INHERIT FILE_TYPE_CHAR
                       LOAD_WITH_ALTERED_SEARCH_PATH CT_CTYPE3 C3_HIGHSURROGATE
                       CP_ACP CP_UTF8 CP_UTF7 CP_OEMCP MB_ERR_INVALID_CHARS
                       LOAD_LIBRARY_SEARCH_DEFAULT_DIRS SEM_FAILCRITICALERRORS
                       LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
                    """
        from rpython.translator.platform import host_factory
        static_platform = host_factory()
        if static_platform.name == 'msvc':
            defines += ' PROCESS_QUERY_LIMITED_INFORMATION'
        for name in defines.split():
            locals()[name] = rffi_platform.ConstantInteger(name)

for k, v in rffi_platform.configure(CConfig).items():
    globals()[k] = v

def winexternal(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           calling_conv='win', **kwds)

if WIN32:
    HANDLE = rffi.COpaquePtr(typedef='HANDLE')
    assert rffi.cast(HANDLE, -1) == rffi.cast(HANDLE, -1)

    LPHANDLE = rffi.CArrayPtr(HANDLE)
    HMODULE = HANDLE
    NULL_HANDLE = rffi.cast(HANDLE, 0)
    INVALID_HANDLE_VALUE = rffi.cast(HANDLE, -1)
    GENERIC_READ     = rffi.cast(DWORD, r_longlong(0x80000000))
    GENERIC_WRITE    = rffi.cast(DWORD, r_longlong(0x40000000))
    GENERIC_EXECUTE  = rffi.cast(DWORD, r_longlong(0x20000000))
    GENERIC_ALL      = rffi.cast(DWORD, r_longlong(0x10000000))
    FILE_SHARE_READ  = rffi.cast(DWORD, r_longlong(0x00000001))
    FILE_SHARE_WRITE = rffi.cast(DWORD, r_longlong(0x00000002))
    ALL_READ_WRITE   = rffi.cast(DWORD, r_longlong(0xC0000003))
    SHARE_READ_WRITE = rffi.cast(DWORD, r_longlong(0x00000003))

    PFILETIME = rffi.CArrayPtr(FILETIME)

    _GetLastError = winexternal('GetLastError', [], DWORD,
                                _nowrapper=True, sandboxsafe=True)
    _SetLastError = winexternal('SetLastError', [DWORD], lltype.Void,
                                _nowrapper=True, sandboxsafe=True)

    def GetLastError_saved():
        """Return the value of the "saved LastError".
        The C-level GetLastError() is saved there after a call to a C
        function, if that C function was declared with the flag
        llexternal(..., save_err=rffi.RFFI_SAVE_LASTERROR).
        Functions without that flag don't change the saved LastError.
        Alternatively, if the function was declared RFFI_SAVE_WSALASTERROR,
        then the value of the C-level WSAGetLastError() is saved instead
        (into the same "saved LastError" variable).
        """
        from rpython.rlib import rthread
        # extra cast to LONG to match CPython behaviour
        lasterror = rffi.cast(rffi.LONG, rthread.tlfield_rpy_lasterror.getraw())
        return rffi.cast(lltype.Signed, lasterror)

    def SetLastError_saved(err):
        """Set the value of the saved LastError.  This value will be used in
        a call to the C-level SetLastError() just before calling the
        following C function, provided it was declared
        llexternal(..., save_err=RFFI_READSAVED_LASTERROR).
        """
        from rpython.rlib import rthread
        rthread.tlfield_rpy_lasterror.setraw(rffi.cast(DWORD, err))

    def GetLastError_alt_saved():
        """Return the value of the "saved alt LastError".
        The C-level GetLastError() is saved there after a call to a C
        function, if that C function was declared with the flag
        llexternal(..., save_err=RFFI_SAVE_LASTERROR | RFFI_ALT_ERRNO).
        Functions without that flag don't change the saved LastError.
        Alternatively, if the function was declared
        RFFI_SAVE_WSALASTERROR | RFFI_ALT_ERRNO,
        then the value of the C-level WSAGetLastError() is saved instead
        (into the same "saved alt LastError" variable).
        """
        from rpython.rlib import rthread
        # extra cast to LONG to match CPython behaviour
        lasterror = rffi.cast(rffi.LONG, rthread.tlfield_alt_lasterror.getraw())
        return rffi.cast(lltype.Signed, lasterror)

    def SetLastError_alt_saved(err):
        """Set the value of the saved alt LastError.  This value will be used in
        a call to the C-level SetLastError() just before calling the
        following C function, provided it was declared
        llexternal(..., save_err=RFFI_READSAVED_LASTERROR | RFFI_ALT_ERRNO).
        """
        from rpython.rlib import rthread
        rthread.tlfield_alt_lasterror.setraw(rffi.cast(DWORD, err))

    # In tests, the first call to _GetLastError() is always wrong,
    # because error is hidden by operations in ll2ctypes.  Call it now.
    _GetLastError()

    GetModuleHandle = winexternal('GetModuleHandleA', [rffi.CCHARP], HMODULE)
    LoadLibrary = winexternal('LoadLibraryA', [rffi.CCHARP], HMODULE,
                              save_err=rffi.RFFI_SAVE_LASTERROR)
    def wrap_loadlibraryex(func):
        def loadlibrary(name, flags):
            # Requires a full path name with '/' -> '\\'
            return func(name, NULL_HANDLE, flags)
        return loadlibrary

    _LoadLibraryExA = winexternal('LoadLibraryExA',
                                [rffi.CCHARP, HANDLE, DWORD], HMODULE,
                                save_err=rffi.RFFI_SAVE_LASTERROR)
    LoadLibraryExA = wrap_loadlibraryex(_LoadLibraryExA)
    LoadLibraryW = winexternal('LoadLibraryW', [rffi.CWCHARP], HMODULE,
                              save_err=rffi.RFFI_SAVE_LASTERROR)
    _LoadLibraryExW = winexternal('LoadLibraryExW',
                                [rffi.CWCHARP, HANDLE, DWORD], HMODULE,
                                save_err=rffi.RFFI_SAVE_LASTERROR)
    LoadLibraryExW = wrap_loadlibraryex(_LoadLibraryExW)
    GetProcAddress = winexternal('GetProcAddress',
                                 [HMODULE, rffi.CCHARP],
                                 rffi.VOIDP)
    FreeLibrary = winexternal('FreeLibrary', [HMODULE], BOOL, releasegil=False)

    LocalFree = winexternal('LocalFree', [HLOCAL], HLOCAL)
    CloseHandle = winexternal('CloseHandle', [HANDLE], BOOL, releasegil=False,
                              save_err=rffi.RFFI_SAVE_LASTERROR)
    CloseHandle_no_err = winexternal('CloseHandle', [HANDLE], BOOL,
                                     releasegil=False)

    FormatMessage = winexternal(
        'FormatMessageA',
        [DWORD, rffi.VOIDP, DWORD, DWORD, rffi.CCHARP, DWORD, rffi.VOIDP],
        DWORD)
    FormatMessageW = winexternal(
        'FormatMessageW',
        [DWORD, rffi.VOIDP, DWORD, DWORD, rffi.CWCHARP, DWORD, rffi.VOIDP],
        DWORD)

    _get_osfhandle = rffi.llexternal('_get_osfhandle', [rffi.INT], rffi.INTP)

    def get_osfhandle(fd):
        from rpython.rlib.rposix import SuppressIPH
        with SuppressIPH():
            handle = rffi.cast(HANDLE, _get_osfhandle(fd))
        if handle == INVALID_HANDLE_VALUE:
            raise WindowsError(ERROR_INVALID_HANDLE, "Invalid file handle")
        return handle

    _open_osfhandle = rffi.llexternal('_open_osfhandle', [rffi.INTP, rffi.INT], rffi.INT)

    def open_osfhandle(handle, flags):
        from rpython.rlib.rposix import SuppressIPH
        fd = _open_osfhandle(handle, flags)
        with SuppressIPH():
            return fd

    wcsncpy_s = rffi.llexternal('wcsncpy_s',
                    [rffi.CWCHARP, rffi.SIZE_T, rffi.CWCHARP, rffi.SIZE_T], rffi.INT)

    def build_winerror_to_errno():
        """Build a dictionary mapping windows error numbers to POSIX errno.
        The function returns the dict, and the default value for codes not
        in the dict."""
        # Prior to Visual Studio 8, the MSVCRT dll doesn't export the
        # _dosmaperr() function, which is available only when compiled
        # against the static CRT library. After Visual Studio 9, this
        # private function seems to be gone, so use a static map, from
        # CPython PC/errmap.h
        errors = {
                2: 2, 3: 2, 4: 24, 5: 13, 6: 9, 7: 12, 8: 12, 9: 12, 10: 7,
                11: 8, 15: 2, 16: 13, 17: 18, 18: 2, 19: 13, 20: 13, 21: 13,
                22: 13, 23: 13, 24: 13, 25: 13, 26: 13, 27: 13, 28: 13,
                29: 13, 30: 13, 31: 13, 32: 13, 33: 13, 34: 13, 35: 13,
                36: 13, 53: 2, 65: 13, 67: 2, 80: 17, 82: 13, 83: 13, 89: 11,
                108: 13, 109: 32, 112: 28, 114: 9, 128: 10, 129: 10, 130: 9,
                132: 13, 145: 41, 158: 13, 161: 2, 164: 11, 167: 13, 183: 17,
                188: 8, 189: 8, 190: 8, 191: 8, 192: 8, 193: 8, 194: 8,
                195: 8, 196: 8, 197: 8, 198: 8, 199: 8, 200: 8, 201: 8,
                202: 8, 206: 2, 215: 11, 232: 32, 267: 20, 1816: 12,
                }
        return errors, errno.EINVAL

    # A bit like strerror...
    def FormatError(code):
        return llimpl_FormatError(code)
    def FormatErrorW(code):
        """
        returns utf8, n_codepoints
        """
        return llimpl_FormatErrorW(code)

    def llimpl_FormatError(code):
        "Return a message corresponding to the given Windows error code."
        buf = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        buf[0] = lltype.nullptr(rffi.CCHARP.TO)
        try:
            msglen = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER |
                                   FORMAT_MESSAGE_FROM_SYSTEM |
                                   FORMAT_MESSAGE_IGNORE_INSERTS,
                                   None,
                                   rffi.cast(DWORD, code),
                                   DEFAULT_LANGUAGE,
                                   rffi.cast(rffi.CCHARP, buf),
                                   0, None)
            buflen = intmask(msglen)

            # remove trailing cr/lf and dots
            s_buf = buf[0]
            while buflen > 0 and (s_buf[buflen - 1] <= ' ' or
                                  s_buf[buflen - 1] == '.'):
                buflen -= 1

            if buflen <= 0:
                result = 'Windows Error %d' % (code,)
            else:
                result = rffi.charpsize2str(s_buf, buflen)
        finally:
            LocalFree(rffi.cast(rffi.VOIDP, buf[0]))
            lltype.free(buf, flavor='raw')

        return result

    def llimpl_FormatErrorW(code):
        "Return a utf8-encoded msg and its length"
        buf = lltype.malloc(rffi.CWCHARPP.TO, 1, flavor='raw')
        buf[0] = lltype.nullptr(rffi.CWCHARP.TO)
        try:
            msglen = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER |
                                    FORMAT_MESSAGE_FROM_SYSTEM |
                                    FORMAT_MESSAGE_IGNORE_INSERTS,
                                    None,
                                    rffi.cast(DWORD, code),
                                    DEFAULT_LANGUAGE,
                                    rffi.cast(rffi.CWCHARP, buf),
                                    0, None)
            buflen = intmask(msglen)

            # remove trailing cr/lf and dots
            s_buf = buf[0]
            while buflen > 0 and (ord(s_buf[buflen - 1]) <= ord(' ') or
                                  s_buf[buflen - 1] == u'.'):
                buflen -= 1

            if buflen <= 0:
                msg = 'Windows Error %d' % (code,)
                result = msg, len(msg)
            else:
                result = rffi.wcharpsize2utf8(s_buf, buflen), buflen
        finally:
            LocalFree(rffi.cast(rffi.VOIDP, buf[0]))
            lltype.free(buf, flavor='raw')

        return result

    def lastSavedWindowsError(context="Windows Error"):
        code = GetLastError_saved()
        return WindowsError(code, context)

    def FAILED(hr):
        # XXX convert to int before checking result
        #     because 32-bit arithmetic is unimplemented on win64
        #     this is fine since HRESULT is defined as (signed) LONG
        return int(rffi.cast(HRESULT, hr)) < 0

    _GetModuleFileName = winexternal('GetModuleFileNameA',
                                     [HMODULE, rffi.CCHARP, DWORD],
                                     DWORD)

    def GetModuleFileName(module):
        size = MAX_PATH
        buf = lltype.malloc(rffi.CCHARP.TO, size, flavor='raw')
        try:
            res = _GetModuleFileName(module, buf, size)
            if not res:
                return ''
            else:
                return ''.join([buf[i] for i in range(res)])
        finally:
            lltype.free(buf, flavor='raw')

    _GetVersionEx = winexternal('GetVersionExA',
                                [lltype.Ptr(OSVERSIONINFOEX)],
                                DWORD,
                                save_err=rffi.RFFI_SAVE_LASTERROR)

    @jit.dont_look_inside
    def GetVersionEx():
        info = lltype.malloc(OSVERSIONINFOEX, flavor='raw')
        rffi.setintfield(info, 'c_dwOSVersionInfoSize',
                         rffi.sizeof(OSVERSIONINFOEX))
        try:
            if not _GetVersionEx(info):
                raise lastSavedWindowsError()
            return (rffi.cast(lltype.Signed, info.c_dwMajorVersion),
                    rffi.cast(lltype.Signed, info.c_dwMinorVersion),
                    rffi.cast(lltype.Signed, info.c_dwBuildNumber),
                    rffi.cast(lltype.Signed, info.c_dwPlatformId),
                    rffi.charp2str(rffi.cast(rffi.CCHARP,
                                             info.c_szCSDVersion)),
                    rffi.cast(lltype.Signed, info.c_wServicePackMajor),
                    rffi.cast(lltype.Signed, info.c_wServicePackMinor),
                    rffi.cast(lltype.Signed, info.c_wSuiteMask),
                    rffi.cast(lltype.Signed, info.c_wProductType))
        finally:
            lltype.free(info, flavor='raw')

    _WaitForSingleObject = winexternal(
        'WaitForSingleObject', [HANDLE, DWORD], DWORD,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    def WaitForSingleObject(handle, timeout):
        """Return values:
        - WAIT_OBJECT_0 when the object is signaled
        - WAIT_TIMEOUT when the timeout elapsed"""
        res = _WaitForSingleObject(handle, timeout)
        if res == rffi.cast(DWORD, -1):
            raise lastSavedWindowsError("WaitForSingleObject")
        return res

    _WaitForMultipleObjects = winexternal(
        'WaitForMultipleObjects', [
            DWORD, rffi.CArrayPtr(HANDLE), BOOL, DWORD], DWORD,
            save_err=rffi.RFFI_SAVE_LASTERROR)

    def WaitForMultipleObjects(handles, waitall=False, timeout=INFINITE):
        """Return values:
        - WAIT_OBJECT_0 + index when an object is signaled
        - WAIT_TIMEOUT when the timeout elapsed"""
        nb = len(handles)
        handle_array = lltype.malloc(rffi.CArrayPtr(HANDLE).TO, nb,
                                     flavor='raw')
        try:
            for i in range(nb):
                handle_array[i] = handles[i]
            res = _WaitForMultipleObjects(nb, handle_array, waitall, timeout)
            if res == rffi.cast(DWORD, -1):
                raise lastSavedWindowsError("WaitForMultipleObjects")
            return res
        finally:
            lltype.free(handle_array, flavor='raw')

    _CreateEvent = winexternal(
        'CreateEventA', [rffi.VOIDP, BOOL, BOOL, LPCSTR], HANDLE,
        save_err=rffi.RFFI_SAVE_LASTERROR)
    def CreateEvent(*args):
        handle = _CreateEvent(*args)
        if handle == NULL_HANDLE:
            raise lastSavedWindowsError("CreateEvent")
        return handle
    SetEvent = winexternal(
        'SetEvent', [HANDLE], BOOL)
    ResetEvent = winexternal(
        'ResetEvent', [HANDLE], BOOL)
    _OpenProcess = winexternal(
        'OpenProcess', [DWORD, BOOL, DWORD], HANDLE,
        save_err=rffi.RFFI_SAVE_LASTERROR)
    def OpenProcess(*args):
        ''' OpenProcess( dwDesiredAccess, bInheritHandle, dwProcessId)
        where dwDesiredAccess is a combination of the flags:
        DELETE (0x00010000L)
        READ_CONTROL (0x00020000L)
        SYNCHRONIZE (0x00100000L)
        WRITE_DAC (0x00040000L)
        WRITE_OWNER (0x00080000L)

        PROCESS_ALL_ACCESS
        PROCESS_CREATE_PROCESS (0x0080)
        PROCESS_CREATE_THREAD (0x0002)
        PROCESS_DUP_HANDLE (0x0040)
        PROCESS_QUERY_INFORMATION (0x0400)
        PROCESS_QUERY_LIMITED_INFORMATION (0x1000)
        PROCESS_SET_QUOTA (0x0100)
        PROCESS_SUSPEND_RESUME (0x0800)
        PROCESS_TERMINATE (0x0001)
        PROCESS_VM_OPERATION (0x0008)
        PROCESS_VM_READ (0x0010)
        PROCESS_VM_WRITE (0x0020)
        SYNCHRONIZE (0x00100000L)
        '''
        handle = _OpenProcess(*args)
        if handle == NULL_HANDLE:
            raise lastSavedWindowsError("OpenProcess")
        return handle
    TerminateProcess = winexternal(
        'TerminateProcess', [HANDLE, rffi.UINT], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)
    GenerateConsoleCtrlEvent = winexternal(
        'GenerateConsoleCtrlEvent', [DWORD, DWORD], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)
    _GetCurrentProcessId = winexternal(
        'GetCurrentProcessId', [], DWORD)
    def GetCurrentProcessId():
        return rffi.cast(lltype.Signed, _GetCurrentProcessId())

    _GetConsoleCP = winexternal('GetConsoleCP', [], DWORD)
    _GetConsoleOutputCP = winexternal('GetConsoleOutputCP', [], DWORD)
    def GetConsoleCP():
        return rffi.cast(lltype.Signed, _GetConsoleCP())
    def GetConsoleOutputCP():
        return rffi.cast(lltype.Signed, _GetConsoleOutputCP())

    _wenviron_items, _wgetenv, _wputenv = make_env_impls(win32=True)


    _GetStdHandle = winexternal(
        'GetStdHandle', [DWORD], HANDLE)

    def GetStdHandle(handle_id):
        return _GetStdHandle(handle_id)
    CONSOLE_SCREEN_BUFFER_INFO_P = lltype.Ptr(CONSOLE_SCREEN_BUFFER_INFO)
    GetConsoleScreenBufferInfo = winexternal(
        "GetConsoleScreenBufferInfo", [HANDLE, CONSOLE_SCREEN_BUFFER_INFO_P], BOOL)

    _GetHandleInformation = winexternal(
        'GetHandleInformation', [HANDLE, LPDWORD], BOOL)
    _SetHandleInformation = winexternal(
        'SetHandleInformation', [HANDLE, DWORD, DWORD], BOOL)

    def set_inheritable(fd, inheritable):
        handle = get_osfhandle(fd)
        set_handle_inheritable(handle, inheritable)

    def set_handle_inheritable(handle, inheritable):
        assert lltype.typeOf(handle) is HANDLE
        if inheritable:
            flags = HANDLE_FLAG_INHERIT
        else:
            flags = 0
        if not _SetHandleInformation(handle, HANDLE_FLAG_INHERIT, flags):
            raise lastSavedWindowsError("SetHandleInformation")

    def get_inheritable(fd):
        handle = get_osfhandle(fd)
        return get_handle_inheritable(handle)

    def get_handle_inheritable(handle):
        assert lltype.typeOf(handle) is HANDLE
        pflags = lltype.malloc(LPDWORD.TO, 1, flavor='raw')
        try:
            if not _GetHandleInformation(handle, pflags):
                raise lastSavedWindowsError("GetHandleInformation")
            flags = widen(pflags[0])
        finally:
            lltype.free(pflags, flavor='raw')
        return (flags & HANDLE_FLAG_INHERIT) != 0

    _GetFileType = winexternal('GetFileType', [HANDLE], DWORD)

    def c_dup_noninheritable(fd1):
        from rpython.rlib.rposix import c_dup

        ftype = _GetFileType(get_osfhandle(fd1))
        fd2 = c_dup(fd1)     # the inheritable version
        if fd2 >= 0 and ftype != FILE_TYPE_CHAR:
            try:
                set_inheritable(fd2, False)
            except:
                os.close(fd2)
                raise
        return fd2

    def c_dup2_noninheritable(fd1, fd2):
        from rpython.rlib.rposix import c_dup2

        ftype = _GetFileType(get_osfhandle(fd1))
        res = c_dup2(fd1, fd2)     # the inheritable version
        if res >= 0 and ftype != FILE_TYPE_CHAR:
            try:
                set_inheritable(fd2, False)
            except:
                os.close(fd2)
                raise
        return res

    GetConsoleMode = winexternal(
        'GetConsoleMode', [HANDLE, LPDWORD], BOOL)

    GetNumberOfConsoleInputEvents = winexternal(
        'GetNumberOfConsoleInputEvents', [HANDLE, LPDWORD], BOOL)

    ERROR_INSUFFICIENT_BUFFER = 122
    ERROR_OPERATION_ABORTED   = 995
    CP_UTF8 = 65001

    ReadConsoleW = winexternal(
        'ReadConsoleW', [HANDLE, LPWSTR, DWORD, LPDWORD, LPVOID], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    WriteConsoleW = winexternal(
        'WriteConsoleW', [HANDLE, LPVOID, DWORD, LPDWORD, LPVOID], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    GetStringTypeW = winexternal(
        'GetStringTypeW', [DWORD, rffi.CWCHARP, rffi.INT, LPWORD], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    _SetEnvironmentVariableW = winexternal(
        'SetEnvironmentVariableW', [LPWSTR, LPWSTR], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    def SetEnvironmentVariableW(name, value):
        with rffi.scoped_unicode2wcharp(name) as nameWbuf:
            with rffi.scoped_unicode2wcharp(value) as valueWbuf:
                return _SetEnvironmentVariableW(nameWbuf, valueWbuf)

    _AddDllDirectory = winexternal('AddDllDirectory', [LPWSTR], rffi.VOIDP,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    def AddDllDirectory(path, length):
        with rffi.scoped_utf82wcharp(path, length) as pathW:
            return _AddDllDirectory(pathW)

    RemoveDllDirectory = winexternal('RemoveDllDirectory', [rffi.VOIDP], BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    # Don't save the err since this is called before checking err in rdynload
    SetErrorMode = winexternal('SetErrorMode', [rffi.UINT], rffi.UINT) 
