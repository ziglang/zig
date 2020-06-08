#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/wchar_s.h>

static int __cdecl _int_vcwprintf_s (const wchar_t *, va_list);
static int __cdecl _stub (const wchar_t *, va_list);

int __cdecl (*__MINGW_IMP_SYMBOL(_vcwprintf_s))(const wchar_t *, va_list) = 
 _stub;

static int __cdecl
_stub (const wchar_t *s, va_list argp)
{
  int __cdecl (*f)(const wchar_t *, va_list) = __MINGW_IMP_SYMBOL(_vcwprintf_s);

  if (f == _stub)
    {
	f = (int __cdecl (*)(const wchar_t *, va_list))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_vcwprintf_s");
	if (!f)
	  f = _int_vcwprintf_s;
	__MINGW_IMP_SYMBOL(_vcwprintf_s) = f;
    }
  return (*f)(s, argp);
}

int __cdecl
_vcwprintf_s (const wchar_t *s, va_list argp)
{
  return _stub (s, argp);
}

static int __cdecl
_int_vcwprintf_s (const wchar_t *s, va_list argp)
{
  return _vcwprintf (s, argp);
}
