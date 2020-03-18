#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <sec_api/conio_s.h>

int __cdecl (*__MINGW_IMP_SYMBOL(_cprintf_s))(const char *,...) = 
 _cprintf_s;

int __cdecl
_cprintf_s (const char *s, ...)
{
  va_list argp;
  int r;

  va_start (argp, s);
  r = _vcprintf_s (s, argp);
  va_end (argp);
  return r; 
}
