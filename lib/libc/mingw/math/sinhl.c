/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"
#include <errno.h>

#ifdef UNK
static uLD P[] = {
  { { 1.7550769032975377032681E-6L } },
  { { 4.1680702175874268714539E-4L } },
  { { 3.0993532520425419002409E-2L } },
  { { 9.9999999999999999998002E-1L } }
};
static long double Q[] = {
  { { 1.7453965448620151484660E-8L } },
  { { -5.9116673682651952419571E-6L } },
  { { 1.0599252315677389339530E-3L } },
  { { -1.1403880487744749056675E-1L } },
  { { 6.0000000000000000000200E0L } }
};
#endif

#ifdef IBMPC
static const uLD P[] = {
  { { 0xec6a,0xd942,0xfbb3,0xeb8f,0x3feb, 0, 0, 0 } },
  { { 0x365e,0xb30a,0xe437,0xda86,0x3ff3, 0, 0, 0 } },
  { { 0x8890,0x01f6,0x2612,0xfde6,0x3ff9, 0, 0, 0 } },
  { { 0x0000,0x0000,0x0000,0x8000,0x3fff, 0, 0, 0 } }
};
static const uLD Q[] = {
  { { 0x4edd,0x4c21,0xad09,0x95ed,0x3fe5, 0, 0, 0 } },
  { { 0x4376,0x9b70,0xd605,0xc65c,0xbfed, 0, 0, 0 } },
  { { 0xc8ad,0x5d21,0x3069,0x8aed,0x3ff5, 0, 0, 0 } },
  { { 0x9c32,0x6374,0x2d4b,0xe98d,0xbffb, 0, 0, 0 } },
  { { 0x0000,0x0000,0x0000,0xc000,0x4001, 0, 0, 0 } }
};
#endif

#ifdef MIEEE
static uLD P[] = {
  { { 0x3feb0000,0xeb8ffbb3,0xd942ec6a, 0 } },
  { { 0x3ff30000,0xda86e437,0xb30a365e, 0 } },
  { { 0x3ff90000,0xfde62612,0x01f68890, 0 } },
  { { 0x3fff0000,0x80000000,0x00000000, 0 } }
};
static uLD Q[] = {
  { { 0x3fe50000,0x95edad09,0x4c214edd, 0 } },
  { { 0xbfed0000,0xc65cd605,0x9b704376, 0 } },
  { { 0x3ff50000,0x8aed3069,0x5d21c8ad, 0 } },
  { { 0xbffb0000,0xe98d2d4b,0x63749c32, 0 } },
  { { 0x40010000,0xc0000000,0x00000000, 0 } }
};
#endif

long double sinhl(long double x)
{
  long double a;
  int x_class = fpclassify (x);

  if (x_class == FP_NAN)
    {
      errno = EDOM;
      return x;
    }
  if (x_class == FP_ZERO)
    return x;
  if (x_class == FP_INFINITE ||
      (fabsl (x) > (MAXLOGL + LOGE2L)))
  {
    errno = ERANGE;
#ifdef INFINITIES
    return (signbit (x) ? -INFINITYL : INFINITYL);
#else
    return (signbit (x) ? -MAXNUML : MAXNUML);
#endif
  }
  a = fabsl (x);
  if (a > 1.0L)
  {
    if (a >= (MAXLOGL - LOGE2L))
    {
      a = expl(0.5L*a);
      a = (0.5L * a) * a;
      if (x < 0.0L)
	a = -a;
      return (a);
    }
    a = expl(a);
    a = 0.5L*a - (0.5L/a);
    if (x < 0.0L)
      a = -a;
    return (a);
  }

  a *= a;
  return (x + x * a * (polevll(a,P,3)/polevll(a,Q,4)));
}

