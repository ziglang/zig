#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/wchar_s.h>

static errno_t __cdecl _int_wmktemp_s (wchar_t *, size_t);
static errno_t __cdecl _stub (wchar_t *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_wmktemp_s))(wchar_t *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (wchar_t *d, size_t dn)
{
  errno_t __cdecl (*f)(wchar_t *, size_t) = __MINGW_IMP_SYMBOL(_wmktemp_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(wchar_t *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_wmktemp_s");
	if (!f)
	  f = _int_wmktemp_s;
	__MINGW_IMP_SYMBOL(_wmktemp_s) = f;
    }
  return (*f)(d, dn);
}

errno_t __cdecl
_wmktemp_s (wchar_t *d, size_t dn)
{
  return _stub (d, dn);
}

static errno_t __cdecl
_int_wmktemp_s (wchar_t *d, size_t dn)
{
  size_t sz;
  if (!d || !dn)
    {
      _wmktemp (NULL);
      return EINVAL;
    }
  sz = wcsnlen (d, dn);
  if (sz >= dn || sz < 6)
    {
      d[0] = 0;
      _wmktemp (NULL);
      return EINVAL;
    }
  if (_wmktemp (d) != NULL)
    return 0;
  return errno;
}
