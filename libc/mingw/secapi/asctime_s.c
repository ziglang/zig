#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_asctime_s (char *, size_t, const struct tm *);
static errno_t __cdecl _stub (char *, size_t, const struct tm *);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(asctime_s))(char *, size_t, const struct tm *) = 
 _stub;

static errno_t __cdecl
_stub (char *d, size_t dn, const struct tm *pt)
{
  errno_t __cdecl (*f)(char *, size_t, const struct tm *) = __MINGW_IMP_SYMBOL(asctime_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(char *, size_t, const struct tm *))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "asctime_s");
	if (!f)
	  f = _int_asctime_s;
	__MINGW_IMP_SYMBOL(asctime_s) = f;
    }
  return (*f)(d, dn, pt);
}

errno_t __cdecl
asctime_s (char *d, size_t dn, const struct tm *pt)
{
  return _stub (d, dn, pt);
}

static errno_t __cdecl
_int_asctime_s (char *d, size_t dn, const struct tm *pt)
{
  char *tmp;
  size_t i;

  if (d && dn)
    d[0] = 0;
  if (!d || dn < 26 || !pt || (tmp = asctime (pt)) == NULL)
     {
        errno = EINVAL;
	return EINVAL;
     }
  for (i = 0; tmp[i] != 0; i++)
    d[i] = tmp[i];
  d[i] = 0;
  return 0;
}
