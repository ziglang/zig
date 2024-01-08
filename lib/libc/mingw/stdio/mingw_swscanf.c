#include <stdarg.h>
#include <stdlib.h>

extern int __mingw_vswscanf (const wchar_t *buf, const wchar_t *format, va_list argp);

int __mingw_swscanf (const wchar_t *buf, const wchar_t *format, ...);

int
__mingw_swscanf (const wchar_t *buf, const wchar_t *format, ...)
{
  va_list argp;
  int r;

  va_start (argp, format);
  r = __mingw_vswscanf (buf, format, argp);
  va_end (argp);

  return r;
}

