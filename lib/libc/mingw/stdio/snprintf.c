/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdarg.h>
#include <stdio.h>

int __cdecl __ms_snprintf(char* buffer, size_t n, const char *format, ...)
{
  int retval;
  va_list argptr;
         
  va_start(argptr, format);

  /* _vsnprintf() does not work with zero length buffer
   * so count number of character by _vscprintf() call */
  if (n == 0 || !buffer)
  {
    retval = _vscprintf(format, argptr);
    va_end(argptr);
    return retval;
  }

  retval = _vsnprintf (buffer, n, format, argptr);

  /* _vsnprintf() returns negative number if buffer is too small
   * so count number of character by _vscprintf() call */
  if (retval < 0)
    retval = _vscprintf(format, argptr);

  /* _vsnprintf() does not fill trailing null byte if there is not place for it */
  if ((size_t)retval >= n)
    buffer[n-1] = '\0';

  va_end(argptr);
  return retval;
}
