#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/conio_s.h>

int __cdecl (*__MINGW_IMP_SYMBOL(_cwprintf_s))(const wchar_t *,...) = 
 _cwprintf_s;

int __cdecl
_cwprintf_s (const wchar_t *s, ...)
{
  va_list argp;
  int r;

  va_start (argp, s);
  r = _vcwprintf_s (s, argp);
  va_end (argp);
  return r; 
}
