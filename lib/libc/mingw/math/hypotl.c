/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include <float.h>
#include <errno.h>

/*
This implementation is based largely on Cephes library
function cabsl (cmplxl.c), which bears the following notice:

Cephes Math Library Release 2.1:  January, 1989
Copyright 1984, 1987, 1989 by Stephen L. Moshier
Direct inquiries to 30 Frost Street, Cambridge, MA 02140
*/

/*
   Modified for use in libmingwex.a
   02 Sept 2002  Danny Smith  <dannysmith@users.sourceforege.net>
   Calls to ldexpl replaced by logbl and calls to frexpl replaced
   by scalbnl to avoid duplicated range checks.
*/

#define PRECL 32

long double
hypotl (long double x, long double y)
{
  int exx;
  int eyy;
  int  scale;
  long double xx =fabsl(x);
  long double yy =fabsl(y);
  if (!isfinite(xx) || !isfinite(yy))
    {
      /* Annex F.9.4.3, hypot returns +infinity if
         either component is an infinity, even when the
         other component is NaN.  */
      return (isinf(xx) || isinf(yy)) ? INFINITY : NAN;
    }

  if (xx == 0.0L)
     return yy;
  if (yy == 0.0L)
     return xx;

  /* Get exponents */
  exx =  logbl (xx);
  eyy =  logbl (yy);

  /* Check if large differences in scale */
  scale = exx - eyy;
  if ( scale > PRECL)
     return xx;
  if ( scale < -PRECL)
     return yy;

  /* Exponent of approximate geometric mean (x 2) */
  scale = (exx + eyy) >> 1;

  /*  Rescale: Geometric mean is now about 2 */  
  x = scalbnl(xx, -scale);
  y = scalbnl(yy, -scale);

  xx = sqrtl(x * x  + y * y);

  /* Check for overflow and underflow */
  exx = logbl(xx);   
  exx += scale;
    if (exx > LDBL_MAX_EXP)
    {
      errno = ERANGE; 
      return INFINITY;
    }
  if (exx < LDBL_MIN_EXP)
    return 0.0L;

  /* Undo scaling */
  return (scalbnl (xx, scale));
}
