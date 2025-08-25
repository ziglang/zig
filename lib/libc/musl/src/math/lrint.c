#include <limits.h>
#include <fenv.h>
#include <math.h>
#include "libm.h"

/*
If the result cannot be represented (overflow, nan), then
lrint raises the invalid exception.

Otherwise if the input was not an integer then the inexact
exception is raised.

C99 is a bit vague about whether inexact exception is
allowed to be raised when invalid is raised.
(F.9 explicitly allows spurious inexact exceptions, F.9.6.5
does not make it clear if that rule applies to lrint, but
IEEE 754r 7.8 seems to forbid spurious inexact exception in
the ineger conversion functions)

So we try to make sure that no spurious inexact exception is
raised in case of an overflow.

If the bit size of long > precision of double, then there
cannot be inexact rounding in case the result overflows,
otherwise LONG_MAX and LONG_MIN can be represented exactly
as a double.
*/

#if LONG_MAX < 1U<<53 && defined(FE_INEXACT)
#include <float.h>
#include <stdint.h>
#if FLT_EVAL_METHOD==0 || FLT_EVAL_METHOD==1
#define EPS DBL_EPSILON
#elif FLT_EVAL_METHOD==2
#define EPS LDBL_EPSILON
#endif
#ifdef __GNUC__
/* avoid stack frame in lrint */
__attribute__((noinline))
#endif
static long lrint_slow(double x)
{
	#pragma STDC FENV_ACCESS ON
	int e;

	e = fetestexcept(FE_INEXACT);
	x = rint(x);
	if (!e && (x > LONG_MAX || x < LONG_MIN))
		feclearexcept(FE_INEXACT);
	/* conversion */
	return x;
}

long lrint(double x)
{
	uint32_t abstop = asuint64(x)>>32 & 0x7fffffff;
	uint64_t sign = asuint64(x) & (1ULL << 63);

	if (abstop < 0x41dfffff) {
		/* |x| < 0x7ffffc00, no overflow */
		double_t toint = asdouble(asuint64(1/EPS) | sign);
		double_t y = x + toint - toint;
		return (long)y;
	}
	return lrint_slow(x);
}
#else
long lrint(double x)
{
	return rint(x);
}
#endif
