#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

extern int __mingw_vfscanf (FILE *stream, const char *format, va_list argp);

int __mingw_scanf (const char *format, ...);
int __mingw_vscanf (const char *format, va_list argp);

int
__mingw_scanf (const char *format, ...)
{
  va_list argp;
  int r;

  va_start (argp, format);
  r = __mingw_vfscanf (stdin, format, argp);
  va_end (argp);

  return r;
}

int
__mingw_vscanf (const char *format, va_list argp)
{
  return __mingw_vfscanf (stdin, format, argp);
}

