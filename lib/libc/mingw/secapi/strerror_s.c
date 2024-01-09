#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/stdio_s.h>

static errno_t __cdecl _int_strerror_s (char *, size_t, int);
static errno_t __cdecl _stub (char *, size_t, int);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(strerror_s))(char *, size_t, int) = _stub;

static errno_t __cdecl
_stub (char *buffer, size_t numberOfElements, int errnum)
{
  errno_t __cdecl (*f)(char *, size_t, int) = __MINGW_IMP_SYMBOL(strerror_s);

  if (f == _stub)
    {
      f = (errno_t __cdecl (*)(char *, size_t, int))
            GetProcAddress (__mingw_get_msvcrt_handle (), "strerror_s");
      if (!f)
      {
        f = _int_strerror_s;
      }
      __MINGW_IMP_SYMBOL(strerror_s) = f;
    }
  return (*f)(buffer, numberOfElements, errnum);
}

errno_t __cdecl
strerror_s (char *buffer, size_t numberOfElements, int errnum)
{
  return _stub (buffer, numberOfElements, errnum);
}

static errno_t __cdecl
_int_strerror_s (char *buffer, size_t numberOfElements, int errnum)
{
  char *errmsg = strerror(errnum);

  if (!errmsg || !buffer || numberOfElements == 0)
    {
      errno = EINVAL;
      return EINVAL;
    }

  if (sprintf_s(buffer, numberOfElements, "%s", errmsg) == -1)
    {
      errno = EINVAL;
      return EINVAL;
    }

  return 0;
}
