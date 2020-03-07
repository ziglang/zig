#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/wchar_s.h>

static errno_t __cdecl _int_waccess_s (const wchar_t *, int);
static errno_t __cdecl _stub (const wchar_t *, int);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_waccess_s))(const wchar_t *, int) = 
 _stub;

static errno_t __cdecl
_stub (const wchar_t *s, int m)
{
  errno_t __cdecl (*f)(const wchar_t *, int) = __MINGW_IMP_SYMBOL(_waccess_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(const wchar_t *, int))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_waccess_s");
	if (!f)
	  f = _int_waccess_s;
	__MINGW_IMP_SYMBOL(_waccess_s) = f;
    }
  return (*f)(s, m);
}

errno_t __cdecl
_waccess_s (const wchar_t *s, int m)
{
  return _stub (s, m);
}

static errno_t __cdecl
_int_waccess_s (const wchar_t *s, int m)
{
  if (!s || (m & ~6) != 0)
    {
      _waccess (NULL, m);
      return EINVAL;
    }
  if (!_waccess (s, m))
    return 0;
  return errno;
}
