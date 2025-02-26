#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "mingw_sformat.h"

int
__mingw_vfscanf (FILE *s, const char *format, va_list argp)
{
  _IFP ifp;
  memset (&ifp, 0, sizeof (_IFP));
  ifp.fp = s;
  return __mingw_sformat (&ifp, format, argp);
}
