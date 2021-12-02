#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <stdio.h>
#include <sec_api/stdio_s.h>

static int __cdecl _int_vsprintf_s (char *, size_t, const char *, va_list);
static int __cdecl _stub (char *, size_t, const char *, va_list);

int __cdecl (*__MINGW_IMP_SYMBOL(vsprintf_s))(char *, size_t, const char *, va_list) = 
 _stub;

static int __cdecl
_stub (char *_DstBuf, size_t _Size, const char *_Format, va_list _ArgList)
{
  int __cdecl (*f)(char *, size_t, const char *, va_list) = __MINGW_IMP_SYMBOL(vsprintf_s);

  if (f == _stub)
    {
	f = (int __cdecl (*)(char *, size_t, const char *, va_list))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "vsprintf_s");
	if (!f)
	  f = _int_vsprintf_s;
	__MINGW_IMP_SYMBOL(vsprintf_s) = f;
    }
  return (*f)(_DstBuf, _Size, _Format, _ArgList);
}

int __cdecl
vsprintf_s (char *_DstBuf, size_t _Size, const char *_Format, va_list _ArgList)
{
  return _stub (_DstBuf, _Size, _Format, _ArgList);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-function-declaration"

static int __cdecl
_int_vsprintf_s (char *_DstBuf, size_t _Size, const char *_Format, va_list _ArgList)
{
  return __ms_vsnprintf (_DstBuf, _Size, _Format, _ArgList);
}

#pragma clang diagnostic pop
