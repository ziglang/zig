#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/wchar_s.h>

static errno_t __cdecl _int_wmemmove_s (wchar_t *, size_t, const wchar_t*, size_t);
static errno_t __cdecl _stub (wchar_t *, size_t, const wchar_t *, size_t);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(wmemmove_s))(wchar_t *, size_t, const wchar_t *, size_t) =
 _stub;

static errno_t __cdecl
_stub (wchar_t *d, size_t dn, const wchar_t *s, size_t n)
{
  errno_t __cdecl (*f)(wchar_t *, size_t, const wchar_t *, size_t) = __MINGW_IMP_SYMBOL(wmemmove_s);

  if (f == _stub)
    {
 f = (errno_t __cdecl (*)(wchar_t *, size_t, const wchar_t *, size_t))
    GetProcAddress (__mingw_get_msvcrt_handle (), "wmemmove_s");
 if (!f)
  f = _int_wmemmove_s;
 __MINGW_IMP_SYMBOL(wmemmove_s) = f;
    }
  return (*f)(d, dn, s, n);
}

errno_t __cdecl
wmemmove_s (wchar_t *d, size_t dn, const wchar_t *s, size_t n)
{
  return _stub (d, dn, s, n);
}

static errno_t __cdecl
_int_wmemmove_s (wchar_t *d, size_t dn, const wchar_t *s, size_t n)
{
  if (!n)
    return 0;

  if (!d || !s)
    {
      if (d)
        memset (d, 0, dn * sizeof (wchar_t));
      errno = EINVAL;
      return EINVAL;
    }

  if (dn < n)
    {
      memset (d, 0, dn * sizeof (wchar_t));

      errno = ERANGE;
      return ERANGE;
    }

  memmove (d, s, n * sizeof (wchar_t));

  return 0;
}
