#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "mingw_swformat.h"

int
__mingw_vswscanf (const wchar_t *s, const wchar_t *format, va_list argp)
{
  _IFPW ifp;
  memset (&ifp, 0, sizeof (_IFPW));
  ifp.str = s;
  ifp.is_string = 1;
  return __mingw_swformat (&ifp, format, argp);
}
