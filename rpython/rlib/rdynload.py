""" Various rpython-level functions for dlopen
"""

from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import we_are_translated, not_rpython
from rpython.rlib.rarithmetic import r_uint
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import platform

import sys, os, string

# maaaybe isinstance here would be better. Think
_MSVC = platform.name == "msvc"
_MINGW = platform.name == "mingw32"
_WIN32 = _MSVC or _MINGW
_MAC_OS = platform.name == "darwin"
_FREEBSD = sys.platform.startswith("freebsd")
_NETBSD = sys.platform.startswith("netbsd")

if _WIN32:
    from rpython.rlib import rwin32
    includes = ['windows.h']
else:
    includes = ['dlfcn.h']

if _MAC_OS:
    pre_include_bits = ['#define MACOSX']
else:
    pre_include_bits = []

if _FREEBSD or _NETBSD or _WIN32:
    libraries = []
else:
    libraries = ['dl']

# this 'eci' is also used in pypy/module/sys/initpath.py
eci = ExternalCompilationInfo(
    pre_include_bits = pre_include_bits,
    includes = includes,
    libraries = libraries,
)

class CConfig:
    _compilation_info_ = eci

    RTLD_LOCAL = rffi_platform.DefinedConstantInteger('RTLD_LOCAL')
    RTLD_GLOBAL = rffi_platform.DefinedConstantInteger('RTLD_GLOBAL')
    RTLD_NOW = rffi_platform.DefinedConstantInteger('RTLD_NOW')
    RTLD_LAZY = rffi_platform.DefinedConstantInteger('RTLD_LAZY')
    RTLD_NODELETE = rffi_platform.DefinedConstantInteger('RTLD_NODELETE')
    RTLD_NOLOAD = rffi_platform.DefinedConstantInteger('RTLD_NOLOAD')
    RTLD_DEEPBIND = rffi_platform.DefinedConstantInteger('RTLD_DEEPBIND')

class cConfig:
    pass

for k, v in rffi_platform.configure(CConfig).items():
    setattr(cConfig, k, v)

def external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci, **kwds)

class DLOpenError(Exception):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return repr(self.msg)


if not _WIN32:
    c_dlopen = external('dlopen', [rffi.CCHARP, rffi.INT], rffi.VOIDP)
    c_dlclose = external('dlclose', [rffi.VOIDP], rffi.INT, releasegil=False)
    c_dlerror = external('dlerror', [], rffi.CCHARP)
    c_dlsym = external('dlsym', [rffi.VOIDP, rffi.CCHARP], rffi.VOIDP)

    DLLHANDLE = rffi.VOIDP

    RTLD_LOCAL = cConfig.RTLD_LOCAL
    RTLD_GLOBAL = cConfig.RTLD_GLOBAL
    RTLD_NOW = cConfig.RTLD_NOW
    RTLD_LAZY = cConfig.RTLD_LAZY

    def dlerror():
        # XXX this would never work on top of ll2ctypes, because
        # ctypes are calling dlerror itself, unsure if I can do much in this
        # area (nor I would like to)
        if not we_are_translated():
            return "error info not available, not translated"
        res = c_dlerror()
        if not res:
            return ""
        return rffi.charp2str(res)

    @not_rpython
    def _dlerror_on_dlopen_untranslated(name):
        # aaargh
        import ctypes
        name = rffi.charp2str(name)
        try:
            ctypes.CDLL(name)
        except OSError as e:
            # common case: ctypes fails too, with the real dlerror()
            # message in str(e).  Return that error message.
            return str(e)
        else:
            # uncommon case: may happen if 'name' is a linker script
            # (which the C-level dlopen() can't handle) and we are
            # directly running on pypy (whose implementation of ctypes
            # or cffi will resolve linker scripts).  In that case, 
            # unsure what we can do.
            return ("opening %r with ctypes.CDLL() works, "
                    "but not with c_dlopen()??" % (name,))

    def _retry_as_ldscript(err, mode):
        """ ld scripts are fairly straightforward to parse (the library we want
        is in a form like 'GROUP ( <actual-filepath.so>'. A simple state machine
        can parse that out (avoids regexes)."""

        parts = err.split(":")
        if len(parts) != 2:
            return lltype.nullptr(rffi.VOIDP.TO)
        fullpath = parts[0]
        actual = ""
        last_five = "     "
        state = 0
        ldscript = os.open(fullpath, os.O_RDONLY, 0777)
        c = os.read(ldscript, 1)
        while c != "":
            if state == 0:
                last_five += c
                last_five = last_five[1:6]
                if last_five == "GROUP":
                    state = 1
            elif state == 1:
                if c == "(":
                    state = 2
            elif state == 2:
                if c not in string.whitespace:
                    actual += c
                    state = 3
            elif state == 3:
                if c in string.whitespace or c == ")":
                    break
                else:
                    actual += c
            c = os.read(ldscript, 1)
        os.close(ldscript)
        if actual != "":
            a = rffi.str2charp(actual)
            lib = c_dlopen(a, rffi.cast(rffi.INT, mode))
            rffi.free_charp(a)
            return lib
        else:
            return lltype.nullptr(rffi.VOIDP.TO)

    def _dlopen_default_mode():
        """ The default dlopen mode if it hasn't been changed by the user.
        """
        mode = RTLD_NOW
        if RTLD_LOCAL is not None:
            mode |= RTLD_LOCAL
        return mode

    def dlopen(name, mode=-1):
        """ Wrapper around C-level dlopen
        """
        if mode == -1:
            mode = _dlopen_default_mode()
        elif (mode & (RTLD_LAZY | RTLD_NOW)) == 0:
            mode |= RTLD_NOW
        #
        # haaaack for 'pypy py.test -A' if libm.so is a linker script
        # (see reason in _dlerror_on_dlopen_untranslated())
        must_free = False
        if not we_are_translated() and platform.name == "linux":
            if name and rffi.charp2str(name) == 'libm.so':
                name = rffi.str2charp('libm.so.6')
                must_free = True
        #
        res = c_dlopen(name, rffi.cast(rffi.INT, mode))
        if must_free:
            rffi.free_charp(name)
        if not res:
            if not we_are_translated():
                err = _dlerror_on_dlopen_untranslated(name)
            else:
                err = dlerror()
            if platform.name == "linux" and 'invalid ELF header' in err:
                # some linux distros put ld linker scripts in .so files
                # to load libraries more dynamically. The error contains the
                # full path to something that is probably a script to load
                # the library we want.
                res = _retry_as_ldscript(err, mode)
                if not res:
                    raise DLOpenError(err)
                return res
            else:
                raise DLOpenError(err)
        return res

    dlclose = c_dlclose

    def dlsym(libhandle, name):
        """ Wrapper around C-level dlsym
        """
        res = c_dlsym(libhandle, name)
        if not res:
            raise KeyError(name)
        # XXX rffi.cast here...
        return res

    def dlsym_byordinal(handle, index):
        # Never called
        raise KeyError(index)

else:  # _WIN32
    DLLHANDLE = rwin32.HMODULE
    RTLD_GLOBAL = None

    def _dlopen_default_mode():
        """ The default dlopen mode if it hasn't been changed by the user.
        """
        return 0

    def dlopen(name, mode=-1):
        # mode is unused on windows, but a consistant signature
        res = rwin32.LoadLibrary(name)
        if not res:
            err = rwin32.GetLastError_saved()
            ustr, lgt = rwin32.FormatErrorW(err)
            raise DLOpenError(ustr)
        return res

    def dlopenex(name, flags=rwin32.LOAD_WITH_ALTERED_SEARCH_PATH):
        # Don't display a message box when Python can't load a DLL */
        old_mode = rwin32.SetErrorMode(rwin32.SEM_FAILCRITICALERRORS)
        res = rwin32.LoadLibraryExA(name, flags)
        rwin32.SetErrorMode(old_mode)
        if not res:
            err = rwin32.GetLastError_saved()
            ustr, lgt = rwin32.FormatErrorW(err)
            raise DLOpenError(ustr)
        return res

    def dlopenU(name, mode=-1):
        # mode is unused on windows, but a consistant signature
        res = rwin32.LoadLibraryW(name)
        if not res:
            err = rwin32.GetLastError_saved()
            ustr, lgt = rwin32.FormatErrorW(err)
            raise DLOpenError(ustr)
        return res

    def dlclose(handle):
        res = rwin32.FreeLibrary(handle)
        if res:
            return 0    # success
        else:
            return -1   # error

    def dlsym(handle, name):
        res = rwin32.GetProcAddress(handle, name)
        if not res:
            raise KeyError(name)
        # XXX rffi.cast here...
        return res

    def dlsym_byordinal(handle, index):
        # equivalent to MAKEINTRESOURCEA
        intresource = rffi.cast(rffi.CCHARP, r_uint(index) & 0xFFFF)
        res = rwin32.GetProcAddress(handle, intresource)
        if not res:
            raise KeyError(index)
        # XXX rffi.cast here...
        return res

    LoadLibrary = rwin32.LoadLibrary
    GetModuleHandle = rwin32.GetModuleHandle
