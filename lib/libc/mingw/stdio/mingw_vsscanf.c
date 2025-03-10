#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "mingw_sformat.h"

int
__mingw_vsscanf (const char *s, const char *format, va_list argp)
{
  _IFP ifp;
  memset (&ifp, 0, sizeof (_IFP));
  ifp.str = s;
  ifp.is_string = 1;
  return __mingw_sformat (&ifp, format, argp);
}
