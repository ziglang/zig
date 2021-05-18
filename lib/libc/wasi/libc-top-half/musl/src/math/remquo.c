#include <math.h>
#include <stdint.h>

double remquo(double x, double y, int *quo)
{
	union {double f; uint64_t i;} ux = {x}, uy = {y};
	int ex = ux.i>>52 & 0x7ff;
	int ey = uy.i>>52 & 0x7ff;
	int sx = ux.i>>63;
	int sy = uy.i>>63;
	uint32_t q;
	uint64_t i;
	uint64_t uxi = ux.i;

	*quo = 0;
	if (uy.i<<1 == 0 || isnan(y) || ex == 0x7ff)
		return (x*y)/(x*y);
	if (ux.i<<1 == 0)
		return x;

	/* normalize x and y */
	if (!ex) {
		for (i = uxi<<12; i>>63 == 0; ex--, i <<= 1);
		uxi <<= -ex + 1;
	} else {
		uxi &= -1ULL >> 12;
		uxi |= 1ULL << 52;
	}
	if (!ey) {
		for (i = uy.i<<12; i>>63 == 0; ey--, i <<= 1);
		uy.i <<= -ey + 1;
	} else {
		uy.i &= -1ULL >> 12;
		uy.i |= 1ULL << 52;
	}

	q = 0;
	if (ex < ey) {
		if (ex+1 == ey)
			goto end;
		return x;
	}

	/* x mod y */
	for (; ex > ey; ex--) {
		i = uxi - uy.i;
		if (i >> 63 == 0) {
			uxi = i;
			q++;
		}
		uxi <<= 1;
		q <<= 1;
	}
	i = uxi - uy.i;
	if (i >> 63 == 0) {
		uxi = i;
		q++;
	}
	if (uxi == 0)
		ex = -60;
	else
		for (; uxi>>52 == 0; uxi <<= 1, ex--);
end:
	/* scale result and decide between |x| and |x|-|y| */
	if (ex > 0) {
		uxi -= 1ULL << 52;
		uxi |= (uint64_t)ex << 52;
	} else {
		uxi >>= -ex + 1;
	}
	ux.i = uxi;
	x = ux.f;
	if (sy)
		y = -y;
	if (ex == ey || (ex+1 == ey && (2*x > y || (2*x == y && q%2)))) {
		x -= y;
		q++;
	}
	q &= 0x7fffffff;
	*quo = sx^sy ? -(int)q : (int)q;
	return sx ? -x : x;
}
