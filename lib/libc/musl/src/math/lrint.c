#include <limits.h>
#include <fenv.h>
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
long lrint(double x)
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
#else
long lrint(double x)
{
	return rint(x);
}
#endif
