/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include "cephes_mconf.h"

static const double CBRT2  = 1.2599210498948731647672;
static const double CBRT4  = 1.5874010519681994747517;
static const double CBRT2I = 0.79370052598409973737585;
static const double CBRT4I = 0.62996052494743658238361;

#ifndef __MINGW32__
extern double frexp ( double, int * );
extern double ldexp ( double, int );
extern int isnan ( double );
extern int isfinite ( double );
#endif

double cbrt(double x)
{
	int e, rem, sign;
	double z;

#ifdef __MINGW32__
	if (!isfinite (x) || x == 0)
		return x;
#else
#ifdef NANS
	if (isnan(x))
		return x;
#endif
#ifdef INFINITIES
	if (!isfinite(x))
		return x;
#endif
	if (x == 0)
		return (x);
#endif /* __MINGW32__ */

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
	x = frexp(x, &e);

	/* Approximate cube root of number between .5 and 1,
	 * peak relative error = 9.2e-6
	 */
	x = (((-1.3466110473359520655053e-1  * x
	      + 5.4664601366395524503440e-1) * x
	      - 9.5438224771509446525043e-1) * x
	      + 1.1399983354717293273738e0 ) * x
	      + 4.0238979564544752126924e-1;

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
	/* argument less than 1 */
	else
	{
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
	x = ldexp(x, e);

	/* Newton iteration */
	x -= ( x - (z/(x*x)) )*0.33333333333333333333;
#ifdef DEC
	x -= ( x - (z/(x*x)) )/3.0;
#else
	x -= ( x - (z/(x*x)) )*0.33333333333333333333;
#endif

	if (sign < 0)
		x = -x;
	return (x);
}
