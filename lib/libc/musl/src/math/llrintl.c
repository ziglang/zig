#include <limits.h>
#include <fenv.h>
#include "libm.h"


#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long long llrintl(long double x)
{
	return llrint(x);
}
#elif defined(FE_INEXACT)
/*
see comments in lrint.c

Note that if LLONG_MAX == 0x7fffffffffffffff && LDBL_MANT_DIG == 64
then x == 2**63 - 0.5 is the only input that overflows and
raises inexact (with tonearest or upward rounding mode)
*/
long long llrintl(long double x)
{
	#pragma STDC FENV_ACCESS ON
	int e;

	e = fetestexcept(FE_INEXACT);
	x = rintl(x);
	if (!e && (x > LLONG_MAX || x < LLONG_MIN))
		feclearexcept(FE_INEXACT);
	/* conversion */
	return x;
}
#else
long long llrintl(long double x)
{
	return rintl(x);
}
#endif
