#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/wchar_s.h>

static int __cdecl _int_vcwprintf_s_l (const wchar_t *, _locale_t, va_list);
static int __cdecl _stub (const wchar_t *, _locale_t, va_list);

int __cdecl (*__MINGW_IMP_SYMBOL(_vcwprintf_s_l))(const wchar_t *, _locale_t, va_list) = 
 _stub;

static int __cdecl
_stub (const wchar_t *s, _locale_t loc, va_list argp)
{
  int __cdecl (*f)(const wchar_t *, _locale_t, va_list) = __MINGW_IMP_SYMBOL(_vcwprintf_s_l);

  if (f == _stub)
    {
	f = (int __cdecl (*)(const wchar_t *, _locale_t, va_list))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_vcwprintf_s_l");
	if (!f)
	  f = _int_vcwprintf_s_l;
	__MINGW_IMP_SYMBOL(_vcwprintf_s_l) = f;
    }
  return (*f)(s, loc, argp);
}

int __cdecl
_vcwprintf_s_l (const wchar_t *s, _locale_t loc, va_list argp)
{
  return _stub (s, loc, argp);
}

static int __cdecl
_int_vcwprintf_s_l (const wchar_t *s, _locale_t loc, va_list argp)
{
  return _vcwprintf_l (s, loc, argp);
}
