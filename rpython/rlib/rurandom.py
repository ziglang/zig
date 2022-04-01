"""The urandom() function, suitable for cryptographic use.
"""

from __future__ import with_statement
import os, sys
import errno

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.objectmodel import not_rpython
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.tool import rffi_platform


if sys.platform == 'win32':
    from rpython.rlib import rwin32

    eci = ExternalCompilationInfo(
        includes = ['windows.h', 'wincrypt.h'],
        libraries = ['advapi32'],
        )

    class CConfig:
        _compilation_info_ = eci
        PROV_RSA_FULL = rffi_platform.ConstantInteger(
            "PROV_RSA_FULL")
        CRYPT_VERIFYCONTEXT = rffi_platform.ConstantInteger(
            "CRYPT_VERIFYCONTEXT")

    globals().update(rffi_platform.configure(CConfig))

    HCRYPTPROV = rwin32.ULONG_PTR

    CryptAcquireContext = rffi.llexternal(
        'CryptAcquireContextA',
        [rffi.CArrayPtr(HCRYPTPROV),
         rwin32.LPCSTR, rwin32.LPCSTR, rwin32.DWORD, rwin32.DWORD],
        rwin32.BOOL,
        calling_conv='win',
        compilation_info=eci,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    CryptGenRandom = rffi.llexternal(
        'CryptGenRandom',
        [HCRYPTPROV, rwin32.DWORD, rffi.CArrayPtr(rwin32.BYTE)],
        rwin32.BOOL,
        calling_conv='win',
        compilation_info=eci,
        save_err=rffi.RFFI_SAVE_LASTERROR)

    @not_rpython
    def init_urandom():
        """
        Return an array of one HCRYPTPROV, initialized to NULL.
        It is filled automatically the first time urandom() is called.
        """
        return lltype.malloc(rffi.CArray(HCRYPTPROV), 1,
                             immortal=True, zero=True)

    def urandom(context, n, signal_checker=None):
        # NOTE: no dictionaries here: rsiphash24 calls this to
        # initialize the random seed of string hashes
        provider = context[0]
        if not provider:
            # This handle is never explicitly released. The operating
            # system will release it when the process terminates.
            if not CryptAcquireContext(
                context, None, None,
                PROV_RSA_FULL, CRYPT_VERIFYCONTEXT):
                raise rwin32.lastSavedWindowsError("CryptAcquireContext")
            provider = context[0]
        # TODO(win64) This is limited to 2**31
        with lltype.scoped_alloc(rffi.CArray(rwin32.BYTE), n,
                                 zero=True, # zero seed
                                 ) as buf:
            if not CryptGenRandom(provider, n, buf):
                raise rwin32.lastSavedWindowsError("CryptGenRandom")

            return rffi.charpsize2str(rffi.cast(rffi.CCHARP, buf), n)

else:  # Posix implementation
    @not_rpython
    def init_urandom():
        return None

    SYS_getrandom = None

    if sys.platform.startswith('linux'):
        eci = ExternalCompilationInfo(includes=['sys/syscall.h'])
        class CConfig:
            _compilation_info_ = eci
            SYS_getrandom = rffi_platform.DefinedConstantInteger(
                'SYS_getrandom')
        globals().update(rffi_platform.configure(CConfig))

    if SYS_getrandom is not None:
        from rpython.rlib.rposix import get_saved_errno, handle_posix_error
        import errno

        eci = eci.merge(ExternalCompilationInfo(includes=['linux/random.h']))
        class CConfig:
            _compilation_info_ = eci
            GRND_NONBLOCK = rffi_platform.DefinedConstantInteger(
                'GRND_NONBLOCK')
        globals().update(rffi_platform.configure(CConfig))
        if GRND_NONBLOCK is None:
            GRND_NONBLOCK = 0x0001      # from linux/random.h

        # On Linux, use the syscall() function because the GNU libc doesn't
        # expose the Linux getrandom() syscall yet.
        syscall = rffi.llexternal(
            'syscall',
            [lltype.Signed, rffi.CCHARP, rffi.LONG, rffi.INT],
            lltype.Signed,
            compilation_info=eci,
            save_err=rffi.RFFI_SAVE_ERRNO)

        class Works:
            status = True
        getrandom_works = Works()

        def _getrandom(n, result, signal_checker):
            if not getrandom_works.status:
                return n
            while n > 0:
                with rffi.scoped_alloc_buffer(n) as buf:
                    got = syscall(SYS_getrandom, buf.raw, n, GRND_NONBLOCK)
                    if got >= 0:
                        s = buf.str(got)
                        result.append(s)
                        n -= len(s)
                        continue
                err = get_saved_errno()
                if (err == errno.ENOSYS or err == errno.EPERM or
                        err == errno.EAGAIN):   # see CPython 3.5
                    getrandom_works.status = False
                    return n
                if err == errno.EINTR:
                    if signal_checker is not None:
                        signal_checker()
                    continue
                handle_posix_error("getrandom", got)
                raise AssertionError("unreachable")
            return n

    def urandom(context, n, signal_checker=None):
        "Read n bytes from /dev/urandom."
        # NOTE: no dictionaries here: rsiphash24 calls this to
        # initialize the random seed of string hashes
        result = []
        if SYS_getrandom is not None:
            n = _getrandom(n, result, signal_checker)
        if n <= 0:
            return ''.join(result)

        # XXX should somehow cache the file descriptor.  It's a mess.
        # CPython has a 99% solution and hopes for the remaining 1%
        # not to occur.  For now, we just don't cache the file
        # descriptor (any more... 6810f401d08e).
        fd = os.open("/dev/urandom", os.O_RDONLY, 0777)
        try:
            while n > 0:
                try:
                    data = os.read(fd, n)
                except OSError as e:
                    if e.errno != errno.EINTR:
                        raise
                    data = ''
                result.append(data)
                n -= len(data)
        finally:
            os.close(fd)
        return ''.join(result)
