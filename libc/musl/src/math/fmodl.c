#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double fmodl(long double x, long double y)
{
	return fmod(x, y);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
long double fmodl(long double x, long double y)
{
	union ldshape ux = {x}, uy = {y};
	int ex = ux.i.se & 0x7fff;
	int ey = uy.i.se & 0x7fff;
	int sx = ux.i.se & 0x8000;

	if (y == 0 || isnan(y) || ex == 0x7fff)
		return (x*y)/(x*y);
	ux.i.se = ex;
	uy.i.se = ey;
	if (ux.f <= uy.f) {
		if (ux.f == uy.f)
			return 0*x;
		return x;
	}

	/* normalize x and y */
	if (!ex) {
		ux.f *= 0x1p120f;
		ex = ux.i.se - 120;
	}
	if (!ey) {
		uy.f *= 0x1p120f;
		ey = uy.i.se - 120;
	}

	/* x mod y */
#if LDBL_MANT_DIG == 64
	uint64_t i, mx, my;
	mx = ux.i.m;
	my = uy.i.m;
	for (; ex > ey; ex--) {
		i = mx - my;
		if (mx >= my) {
			if (i == 0)
				return 0*x;
			mx = 2*i;
		} else if (2*mx < mx) {
			mx = 2*mx - my;
		} else {
			mx = 2*mx;
		}
	}
	i = mx - my;
	if (mx >= my) {
		if (i == 0)
			return 0*x;
		mx = i;
	}
	for (; mx >> 63 == 0; mx *= 2, ex--);
	ux.i.m = mx;
#elif LDBL_MANT_DIG == 113
	uint64_t hi, lo, xhi, xlo, yhi, ylo;
	xhi = (ux.i2.hi & -1ULL>>16) | 1ULL<<48;
	yhi = (uy.i2.hi & -1ULL>>16) | 1ULL<<48;
	xlo = ux.i2.lo;
	ylo = uy.i2.lo;
	for (; ex > ey; ex--) {
		hi = xhi - yhi;
		lo = xlo - ylo;
		if (xlo < ylo)
			hi -= 1;
		if (hi >> 63 == 0) {
			if ((hi|lo) == 0)
				return 0*x;
			xhi = 2*hi + (lo>>63);
			xlo = 2*lo;
		} else {
			xhi = 2*xhi + (xlo>>63);
			xlo = 2*xlo;
		}
	}
	hi = xhi - yhi;
	lo = xlo - ylo;
	if (xlo < ylo)
		hi -= 1;
	if (hi >> 63 == 0) {
		if ((hi|lo) == 0)
			return 0*x;
		xhi = hi;
		xlo = lo;
	}
	for (; xhi >> 48 == 0; xhi = 2*xhi + (xlo>>63), xlo = 2*xlo, ex--);
	ux.i2.hi = xhi;
	ux.i2.lo = xlo;
#endif

	/* scale result */
	if (ex <= 0) {
		ux.i.se = (ex+120)|sx;
		ux.f *= 0x1p-120f;
	} else
		ux.i.se = ex|sx;
	return ux.f;
}
#endif
