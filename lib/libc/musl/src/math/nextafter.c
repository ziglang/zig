#include "libm.h"

double nextafter(double x, double y)
{
	union {double f; uint64_t i;} ux={x}, uy={y};
	uint64_t ax, ay;
	int e;

	if (isnan(x) || isnan(y))
		return x + y;
	if (ux.i == uy.i)
		return y;
	ax = ux.i & -1ULL/2;
	ay = uy.i & -1ULL/2;
	if (ax == 0) {
		if (ay == 0)
			return y;
		ux.i = (uy.i & 1ULL<<63) | 1;
	} else if (ax > ay || ((ux.i ^ uy.i) & 1ULL<<63))
		ux.i--;
	else
		ux.i++;
	e = ux.i >> 52 & 0x7ff;
	/* raise overflow if ux.f is infinite and x is finite */
	if (e == 0x7ff)
		FORCE_EVAL(x+x);
	/* raise underflow if ux.f is subnormal or zero */
	if (e == 0)
		FORCE_EVAL(x*x + ux.f*ux.f);
	return ux.f;
}
