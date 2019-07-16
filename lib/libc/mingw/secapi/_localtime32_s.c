#include <windows.h>
#include <malloc.h>
#include <time.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_localtime32_s (struct tm *, const __time32_t *);
static errno_t __cdecl _stub (struct tm *, const __time32_t *);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_localtime32_s))(struct tm *, const __time32_t *) = 
 _stub;

static errno_t __cdecl
_stub (struct tm *ptm, const __time32_t *pt)
{
  errno_t __cdecl (*f)(struct tm *, const __time32_t *) = __MINGW_IMP_SYMBOL(_localtime32_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(struct tm *, const __time32_t *))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_localtime32_s");
	if (!f)
	  f = _int_localtime32_s;
	__MINGW_IMP_SYMBOL(_localtime32_s) = f;
    }
  return (*f)(ptm, pt);
}

errno_t __cdecl
_localtime32_s (struct tm *ptm, const __time32_t *pt)
{
  return _stub (ptm, pt);
}

static errno_t __cdecl
_int_localtime32_s (struct tm *ptm, const __time32_t *pt)
{
  struct tm *ltm;

  if (ptm)
    memset (ptm, 0xff, sizeof (*ptm));
  if (!ptm || !pt)
     {
        errno = EINVAL;
	return EINVAL;
     }
  if ((ltm = _localtime32 (pt)) == NULL)
    return errno;
  *ptm = *ltm;
  return 0;
}
