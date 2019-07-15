#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

extern int __mingw_vfwscanf (FILE *stream, const wchar_t *format, va_list argp);

int __mingw_fwscanf (FILE *stream, const wchar_t *format, ...);

int
__mingw_fwscanf (FILE *stream, const wchar_t *format, ...)
{
  va_list argp;
  int r;

  va_start (argp, format);
  r = __mingw_vfwscanf (stream, format, argp);
  va_end (argp);

  return r;
}

