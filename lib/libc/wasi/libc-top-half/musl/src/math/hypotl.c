#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double hypotl(long double x, long double y)
{
	return hypot(x, y);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
#if LDBL_MANT_DIG == 64
#define SPLIT (0x1p32L+1)
#elif LDBL_MANT_DIG == 113
#define SPLIT (0x1p57L+1)
#endif

static void sq(long double *hi, long double *lo, long double x)
{
	long double xh, xl, xc;
	xc = x*SPLIT;
	xh = x - xc + xc;
	xl = x - xh;
	*hi = x*x;
	*lo = xh*xh - *hi + 2*xh*xl + xl*xl;
}

long double hypotl(long double x, long double y)
{
	union ldshape ux = {x}, uy = {y};
	int ex, ey;
	long double hx, lx, hy, ly, z;

	ux.i.se &= 0x7fff;
	uy.i.se &= 0x7fff;
	if (ux.i.se < uy.i.se) {
		ex = uy.i.se;
		ey = ux.i.se;
		x = uy.f;
		y = ux.f;
	} else {
		ex = ux.i.se;
		ey = uy.i.se;
		x = ux.f;
		y = uy.f;
	}

	if (ex == 0x7fff && isinf(y))
		return y;
	if (ex == 0x7fff || y == 0)
		return x;
	if (ex - ey > LDBL_MANT_DIG)
		return x + y;

	z = 1;
	if (ex > 0x3fff+8000) {
		z = 0x1p10000L;
		x *= 0x1p-10000L;
		y *= 0x1p-10000L;
	} else if (ey < 0x3fff-8000) {
		z = 0x1p-10000L;
		x *= 0x1p10000L;
		y *= 0x1p10000L;
	}
	sq(&hx, &lx, x);
	sq(&hy, &ly, y);
	return z*sqrtl(ly+lx+hy+hx);
}
#endif
