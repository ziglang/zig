#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_wstrtime_s (wchar_t *, size_t);
static errno_t __cdecl _stub (wchar_t *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_wstrtime_s))(wchar_t *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (wchar_t *d, size_t dn)
{
  errno_t __cdecl (*f)(wchar_t *, size_t) = __MINGW_IMP_SYMBOL(_wstrtime_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(wchar_t *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_wstrtime_s");
	if (!f)
	  f = _int_wstrtime_s;
	__MINGW_IMP_SYMBOL(_wstrtime_s) = f;
    }
  return (*f)(d, dn);
}

errno_t __cdecl
_wstrtime_s (wchar_t *d, size_t dn)
{
  return _stub (d, dn);
}

static errno_t __cdecl
_int_wstrtime_s (wchar_t *d, size_t dn)
{
  SYSTEMTIME dt;
  int hours, minutes, seconds;

  if (!d || !dn)
    {
      errno = EINVAL;
      return EINVAL;
    }

  d[0] = 0;

  if (dn < 9)
    {
      errno = ERANGE;
      return ERANGE;
    }

  GetLocalTime (&dt);

  hours = dt.wHour;
  minutes = dt.wMinute;
  seconds = dt.wSecond;

  d[2] = d[5] = ':';
  d[0] = (wchar_t) (hours / 10 + '0');
  d[1] = (wchar_t) (hours % 10 + '0');
  d[3] = (wchar_t) (minutes / 10 + '0');
  d[4] = (wchar_t) (minutes % 10 + '0');
  d[6] = (wchar_t) (seconds / 10 + '0');
  d[7] = (wchar_t) (seconds % 10 + '0');
  d[8] = 0;

  return 0;
}
