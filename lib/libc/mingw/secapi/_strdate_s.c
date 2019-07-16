#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_strdate_s (char *, size_t);
static errno_t __cdecl _stub (char *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_strdate_s))(char *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (char *d, size_t dn)
{
  errno_t __cdecl (*f)(char *, size_t) = __MINGW_IMP_SYMBOL(_strdate_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(char *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_strdate_s");
	if (!f)
	  f = _int_strdate_s;
	__MINGW_IMP_SYMBOL(_strdate_s) = f;
    }
  return (*f)(d, dn);
}

errno_t __cdecl
_strdate_s (char *d, size_t dn)
{
  return _stub (d, dn);
}

static errno_t __cdecl
_int_strdate_s (char *d, size_t dn)
{
  SYSTEMTIME dt;

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

  d[0] = (char) (dt.wMonth / 10 + '0');
  d[1] = (char) (dt.wMonth % 10 + '0');
  d[2] = '/';
  d[3] = (char) (dt.wDay / 10 + '0');
  d[4] = (char) (dt.wDay % 10 + '0');
  d[5] = '/';
  d[6] = (char) (dt.wYear / 10 + '0');
  d[7] = (char) (dt.wYear % 10 + '0');
  d[8] = 0;

  return 0;
}
