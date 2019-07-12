#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <io.h>

static errno_t __cdecl _int_access_s (const char *, int);
static errno_t __cdecl _stub (const char *, int);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_access_s))(const char *, int) = 
 _stub;

static errno_t __cdecl
_stub (const char *s, int m)
{
  errno_t __cdecl (*f)(const char *, int) = __MINGW_IMP_SYMBOL(_access_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(const char *, int))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_access_s");
	if (!f)
	  f = _int_access_s;
	__MINGW_IMP_SYMBOL(_access_s) = f;
    }
  return (*f)(s, m);
}

errno_t __cdecl
_access_s (const char *s, int m)
{
  return _stub (s, m);
}

static errno_t __cdecl
_int_access_s (const char *s, int m)
{
  if (!s || (m & ~6) != 0)
    {
      _access (NULL, m);
      return EINVAL;
    }
  if (!_access (s, m))
    return 0;
  return errno;
}
