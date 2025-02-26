#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "mingw_swformat.h"

int
__mingw_vfwscanf (FILE *s, const wchar_t *format, va_list argp)
{
  _IFPW ifp;
  memset (&ifp, 0, sizeof (_IFPW));
  ifp.fp = s;
  return __mingw_swformat (&ifp, format, argp);
}
