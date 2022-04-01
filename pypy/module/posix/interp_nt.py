from rpython.rlib import rwin32
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rwin32file import make_win32_traits
from rpython.rlib._os_support import UnicodeTraits
from rpython.translator import cdir
from rpython.translator.tool.cbuild import ExternalCompilationInfo


# XXX: pypy_GetFinalPathNameByHandle is needed to call the dynamically
# found GetFinalPathNameByHandle function with a non-standard calling
# convention. currently FuncType pointer calls w/ non-standard calling
# conventions don't work after translation
separate_module_source = """\
DWORD
pypy_GetFinalPathNameByHandle(FARPROC address, HANDLE hFile,
                              LPTSTR lpszFilePath, DWORD cchFilePath,
                              DWORD dwFlags) {
    DWORD (WINAPI *func)(HANDLE, LPTSTR, DWORD, DWORD);
    *(FARPROC*)&func = address;
    return func(hFile, lpszFilePath, cchFilePath, dwFlags);
}
"""
eci = ExternalCompilationInfo(
    includes=['windows.h'],
    include_dirs=[cdir],
    post_include_bits=[
        "RPY_EXTERN DWORD "
        "pypy_GetFinalPathNameByHandle(FARPROC, HANDLE, LPTSTR, DWORD, DWORD);"],
    separate_module_sources=[separate_module_source])
pypy_GetFinalPathNameByHandle = rffi.llexternal(
    'pypy_GetFinalPathNameByHandle',
    [rffi.VOIDP, rwin32.HANDLE, rffi.CWCHARP, rwin32.DWORD, rwin32.DWORD],
    rwin32.DWORD, compilation_info=eci)


# plain NotImplementedError is invalid RPython
class LLNotImplemented(Exception):

    def __init__(self, msg):
        self.msg = msg


def make_traits(traits):
    win32traits = make_win32_traits(traits)

    class NTTraits(win32traits):

        GetFinalPathNameByHandle_HANDLE = lltype.nullptr(rffi.VOIDP.TO)

        def check_GetFinalPathNameByHandle(self):
            if (self.GetFinalPathNameByHandle_HANDLE !=
                lltype.nullptr(rffi.VOIDP.TO)):
                return True

            from rpython.rlib.rdynload import GetModuleHandle, dlsym
            hKernel32 = GetModuleHandle("KERNEL32")
            try:
                func = dlsym(hKernel32, 'GetFinalPathNameByHandleW')
            except KeyError:
                return False

            self.GetFinalPathNameByHandle_HANDLE = func
            return True

        def GetFinalPathNameByHandle(self, *args):
            assert (self.GetFinalPathNameByHandle_HANDLE !=
                    lltype.nullptr(rffi.VOIDP.TO))
            return pypy_GetFinalPathNameByHandle(
                self.GetFinalPathNameByHandle_HANDLE, *args)

    return NTTraits()


def make__getfileinformation_impl(traits):
    win32traits = make_traits(traits)

    def _getfileinformation_llimpl(fd):
        hFile = rwin32.get_osfhandle(fd)
        with lltype.scoped_alloc(
            win32traits.BY_HANDLE_FILE_INFORMATION) as info:
            if win32traits.GetFileInformationByHandle(hFile, info) == 0:
                raise rwin32.lastSavedWindowsError("_getfileinformation")
            return (rffi.cast(lltype.Signed, info.c_dwVolumeSerialNumber),
                    rffi.cast(lltype.Signed, info.c_nFileIndexHigh),
                    rffi.cast(lltype.Signed, info.c_nFileIndexLow))

    return _getfileinformation_llimpl


def make__getfinalpathname_impl(traits):
    assert traits.str is unicode, 'Currently only handles unicode paths'
    win32traits = make_traits(traits)

    @specialize.argtype(0)
    def _getfinalpathname_llimpl(path):
        if not win32traits.check_GetFinalPathNameByHandle():
            raise LLNotImplemented("GetFinalPathNameByHandle not available on "
                                   "this platform")

        hFile = win32traits.CreateFile(traits.as_str0(path), 0, 0, None,
                                       win32traits.OPEN_EXISTING,
                                       win32traits.FILE_FLAG_BACKUP_SEMANTICS,
                                       rwin32.NULL_HANDLE)
        if hFile == rwin32.INVALID_HANDLE_VALUE:
            raise rwin32.lastSavedWindowsError("CreateFile")

        VOLUME_NAME_DOS = rffi.cast(rwin32.DWORD, win32traits.VOLUME_NAME_DOS)
        try:
            usize = win32traits.GetFinalPathNameByHandle(
                hFile,
                lltype.nullptr(traits.CCHARP.TO),
                rffi.cast(rwin32.DWORD, 0),
                VOLUME_NAME_DOS)
            if usize == 0:
                raise rwin32.lastSavedWindowsError("GetFinalPathNameByHandle")

            size = rffi.cast(lltype.Signed, usize)
            with rffi.scoped_alloc_unicodebuffer(size + 1) as buf:
                result = win32traits.GetFinalPathNameByHandle(
                    hFile,
                    buf.raw,
                    usize,
                    VOLUME_NAME_DOS)
                if result == 0:
                    raise rwin32.lastSavedWindowsError("GetFinalPathNameByHandle")
                res = buf.str(rffi.cast(lltype.Signed, result))
                return res.encode('utf8'), len(res)
        finally:
            rwin32.CloseHandle(hFile)

    return _getfinalpathname_llimpl


_getfileinformation = make__getfileinformation_impl(UnicodeTraits())
_getfinalpathname = make__getfinalpathname_impl(UnicodeTraits())
