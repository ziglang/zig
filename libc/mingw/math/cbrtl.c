/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"

static const long double CBRT2  = 1.2599210498948731647672L;
static const long double CBRT4  = 1.5874010519681994747517L;
static const long double CBRT2I = 0.79370052598409973737585L;
static const long double CBRT4I = 0.62996052494743658238361L;

extern long double ldexpl(long double,int);

long double cbrtl(long double x)
{
	int e, rem, sign;
	long double z;

	if (!isfinite (x) || x == 0.0L)
		return (x);

	if (x > 0)
		sign = 1;
	else
	{
		sign = -1;
		x = -x;
	}

	z = x;
	/* extract power of 2, leaving
	 * mantissa between 0.5 and 1
	 */
	x = frexpl(x, &e);

	/* Approximate cube root of number between .5 and 1,
	 * peak relative error = 1.2e-6
	 */
	x = (((( 1.3584464340920900529734e-1L * x
	       - 6.3986917220457538402318e-1L) * x
	       + 1.2875551670318751538055e0L) * x
	       - 1.4897083391357284957891e0L) * x
	       + 1.3304961236013647092521e0L) * x
	       + 3.7568280825958912391243e-1L;

	/* exponent divided by 3 */
	if (e >= 0)
	{
		rem = e;
		e /= 3;
		rem -= 3*e;
		if (rem == 1)
			x *= CBRT2;
		else if (rem == 2)
			x *= CBRT4;
	}
	else
	{ /* argument less than 1 */
		e = -e;
		rem = e;
		e /= 3;
		rem -= 3*e;
		if (rem == 1)
			x *= CBRT2I;
		else if (rem == 2)
			x *= CBRT4I;
		e = -e;
	}

	/* multiply by power of 2 */
	x = ldexpl(x, e);

	/* Newton iteration */

	x -= ( x - (z/(x*x)) )*0.3333333333333333333333L;
	x -= ( x - (z/(x*x)) )*0.3333333333333333333333L;

	if (sign < 0)
		x = -x;
	return (x);
}
