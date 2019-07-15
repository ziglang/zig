#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_ctime64_s (char *, size_t, const __time64_t *);
static errno_t __cdecl _stub (char *, size_t, const __time64_t *);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_ctime64_s))(char *, size_t, const __time64_t *) = 
 _stub;

static errno_t __cdecl
_stub (char *d, size_t dn, const __time64_t *pt)
{
  errno_t __cdecl (*f)(char *, size_t, const __time64_t *) = __MINGW_IMP_SYMBOL(_ctime64_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(char *, size_t, const __time64_t *))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_ctime64_s");
	if (!f)
	  f = _int_ctime64_s;
	__MINGW_IMP_SYMBOL(_ctime64_s) = f;
    }
  return (*f)(d, dn, pt);
}

errno_t __cdecl
_ctime64_s (char *d, size_t dn, const __time64_t *pt)
{
  return _stub (d, dn, pt);
}

static errno_t __cdecl
_int_ctime64_s (char *d, size_t dn, const __time64_t *pt)
{
  struct tm ltm;
  errno_t e;

  if (!d || !dn)
     {
        errno = EINVAL;
	return EINVAL;
     }
  d[0] = 0;
  if (!pt)
     {
	errno = EINVAL;
	return EINVAL;
     }

  if ((e = _localtime64_s (&ltm, pt)) != 0)
    return e;  
  return asctime_s (d, dn, &ltm);
}
