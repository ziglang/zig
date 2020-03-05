#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>

static errno_t __cdecl _int_memmove_s (void *, size_t, const void *, size_t);
static errno_t __cdecl _stub (void *, size_t, const void *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(memmove_s))(void *, size_t, const void *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (void *d, size_t dn, const void *s, size_t n)
{
  errno_t __cdecl (*f)(void *, size_t, const void *, size_t) = __MINGW_IMP_SYMBOL(memmove_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(void *, size_t, const void *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "memmove_s");
	if (!f)
	  f = _int_memmove_s;
	__MINGW_IMP_SYMBOL(memmove_s) = f;
    }
  return (*f)(d, dn, s, n);
}

errno_t __cdecl
memmove_s (void *d, size_t dn, const void *s, size_t n)
{
  return _stub (d, dn, s, n);
}

static errno_t __cdecl
_int_memmove_s (void *d, size_t dn, const void *s, size_t n)
{
  if (!n)
    return 0;

  if (!d || !s)
    {
      if (d)
        memset (d, 0, dn);
      errno = EINVAL;
      return EINVAL;
    }

  if (dn < n)
    {
      memset (d, 0, dn);

      errno = ERANGE;
      return ERANGE;
    }

  memmove (d, s, n);

  return 0;
}
