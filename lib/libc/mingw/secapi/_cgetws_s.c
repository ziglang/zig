#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/conio_s.h>

static errno_t __cdecl _int_cgetws_s (wchar_t *, size_t, size_t *);
static errno_t __cdecl _stub (wchar_t *, size_t, size_t *);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_cgetws_s))(wchar_t *, size_t, size_t *) = 
 _stub;

static errno_t __cdecl
_stub (wchar_t *s, size_t l, size_t *r_len)
{
  errno_t __cdecl (*f)(wchar_t *, size_t, size_t *) = __MINGW_IMP_SYMBOL(_cgetws_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(wchar_t *, size_t, size_t *))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_cgetws_s");
	if (!f)
	  f = _int_cgetws_s;
	__MINGW_IMP_SYMBOL(_cgetws_s) = f;
    }
  return (*f)(s, l, r_len);
}

errno_t __cdecl
_cgetws_s (wchar_t *s, size_t l, size_t *r_len)
{
  return _stub (s, l, r_len);
}

static errno_t __cdecl
_int_cgetws_s (wchar_t *s, size_t l, size_t *r_len)
{
  wchar_t *h, *p;

  if (s && l)
    s[0] = 0;
  if (!s || !l || !r_len)
    {
      _cgetws (NULL);
      return EINVAL;
    }
  p = (wchar_t *) alloca ((l + 2) * sizeof (wchar_t));
  p[0] = l;
  h = _cgetws (s); 
  if (!h)
    return EINVAL;
  *r_len = (size_t) p[1];
  memcpy (s, &p[2], *r_len);
  return 0;
}
