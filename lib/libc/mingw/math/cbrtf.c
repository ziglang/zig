/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <math.h>
#include "cephes_mconf.h"

static const float CBRT2 = 1.25992104989487316477;
static const float CBRT4 = 1.58740105196819947475;

float cbrtf (float x)
{
	int e, rem, sign;
	float z;
	if (!isfinite (x) || x == 0.0F)
		return x;
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
	x = frexpf(x, &e);

	/* Approximate cube root of number between .5 and 1,
	 * peak relative error = 9.2e-6
	 */
	x = (((-0.13466110473359520655053  * x
	      + 0.54664601366395524503440 ) * x
	      - 0.95438224771509446525043 ) * x
	      + 1.1399983354717293273738  ) * x
	      + 0.40238979564544752126924;

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
			x /= CBRT2;
		else if (rem == 2)
			x /= CBRT4;
		e = -e;
	}

	/* multiply by power of 2 */
	x = ldexpf(x, e);

	/* Newton iteration */
	x -= ( x - (z/(x*x)) ) * 0.333333333333;

	if (sign < 0)
		x = -x;
	return (x);
}
