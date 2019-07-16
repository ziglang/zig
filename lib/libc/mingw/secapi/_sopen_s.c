#include <windows.h>
#include <io.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_sopen_s(int *, const char *, int, int, int);
static errno_t __cdecl _stub(int *, const char *, int, int, int);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_sopen_s))(int *, const char *, int, int, int) = _stub;

static errno_t __cdecl
_stub (int* pfh, const char *filename, int oflag, int shflag, int pmode)
{
    errno_t __cdecl (*f)(int *, const char *, int, int, int) = __MINGW_IMP_SYMBOL(_sopen_s);

    if (f == _stub) {
        f = (errno_t __cdecl (*)(int *, const char *, int, int, int))
            GetProcAddress (__mingw_get_msvcrt_handle (), "_sopen_s");
        if (f == NULL)
            f = _int_sopen_s;
        __MINGW_IMP_SYMBOL(_sopen_s) = f;
    }

    return (*f)(pfh, filename, oflag, shflag, pmode);
}

static errno_t __cdecl _int_sopen_s(int* pfh, const char *filename, int oflag, int shflag, int pmode)
{
    if (pfh == NULL || filename == NULL) {
        if (pfh != NULL) *pfh = -1;
        errno = EINVAL;
        return EINVAL;
    }

    *pfh = _sopen(filename, oflag, shflag, pmode);
    return errno;
}

errno_t __cdecl _sopen_s(int* pfh, const char *filename, int oflag, int shflag, int pmode)
{
    return _stub (pfh, filename, oflag, shflag, pmode);
}
