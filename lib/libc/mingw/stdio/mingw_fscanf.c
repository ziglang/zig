#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

extern int __mingw_vfscanf (FILE *stream, const char *format, va_list argp);

int __mingw_fscanf (FILE *stream, const char *format, ...);

int
__mingw_fscanf (FILE *stream, const char *format, ...)
{
  va_list argp;
  int r;

  va_start (argp, format);
  r = __mingw_vfscanf (stream, format, argp);
  va_end (argp);

  return r;
}

