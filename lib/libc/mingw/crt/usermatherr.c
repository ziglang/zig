/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

typedef int (__cdecl *fUserMathErr)(struct _exception *);
static fUserMathErr stUserMathErr;

void __mingw_raise_matherr (int typ, const char *name, double a1, double a2,
			    double rslt)
{
  struct _exception ex;
  if (!stUserMathErr)
    return;
  ex.type = typ;
  ex.name = (char*)name;
  ex.arg1 = a1;
  ex.arg2 = a2;
  ex.retval = rslt;
  (*stUserMathErr)(&ex);
}

#undef __setusermatherr

void __mingw_setusermatherr (int (__cdecl *f)(struct _exception *))
{
  stUserMathErr = f;
  __setusermatherr (f);
}
