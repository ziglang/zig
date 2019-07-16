#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <io.h>

static errno_t __cdecl _int_mktemp_s (char *, size_t);
static errno_t __cdecl _stub (char *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_mktemp_s))(char *, size_t) = 
 _stub;

static errno_t __cdecl
_stub (char *d, size_t dn)
{
  errno_t __cdecl (*f)(char *, size_t) = __MINGW_IMP_SYMBOL(_mktemp_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(char *, size_t))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_mktemp_s");
	if (!f)
	  f = _int_mktemp_s;
	__MINGW_IMP_SYMBOL(_mktemp_s) = f;
    }
  return (*f)(d, dn);
}

errno_t __cdecl
_mktemp_s (char *d, size_t dn)
{
  return _stub (d, dn);
}

static errno_t __cdecl
_int_mktemp_s (char *d, size_t dn)
{
  size_t sz;
  if (!d || !dn)
    {
      _mktemp (NULL);
      return EINVAL;
    }
  sz = strnlen (d, dn);
  if (sz >= dn || sz < 6)
    {
      d[0] = 0;
      _mktemp (NULL);
      return EINVAL;
    }
  if (_mktemp (d) != NULL)
    return 0;
  return errno;
}
