#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_strtime_s (char *, size_t);
static errno_t __cdecl _stub (char *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_strtime_s))(char *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (char *d, size_t dn)
{
  errno_t __cdecl (*f)(char *, size_t) = __MINGW_IMP_SYMBOL(_strtime_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(char *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_strtime_s");
	if (!f)
	  f = _int_strtime_s;
	__MINGW_IMP_SYMBOL(_strtime_s) = f;
    }
  return (*f)(d, dn);
}

errno_t __cdecl
_strtime_s (char *d, size_t dn)
{
  return _stub (d, dn);
}

static errno_t __cdecl
_int_strtime_s (char *d, size_t dn)
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
  dt.wYear %= 100;

  hours = dt.wHour;
  minutes = dt.wMinute;
  seconds = dt.wSecond;

  d[2] = d[5] = ':';
  d[0] = (char) (hours / 10 + '0');
  d[1] = (char) (hours % 10 + '0');
  d[3] = (char) (minutes / 10 + '0');
  d[4] = (char) (minutes % 10 + '0');
  d[6] = (char) (seconds / 10 + '0');
  d[7] = (char) (seconds % 10 + '0');
  d[8] = 0;

  return 0;
}
