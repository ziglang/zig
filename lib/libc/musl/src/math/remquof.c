#include <math.h>
#include <stdint.h>

float remquof(float x, float y, int *quo)
{
	union {float f; uint32_t i;} ux = {x}, uy = {y};
	int ex = ux.i>>23 & 0xff;
	int ey = uy.i>>23 & 0xff;
	int sx = ux.i>>31;
	int sy = uy.i>>31;
	uint32_t q;
	uint32_t i;
	uint32_t uxi = ux.i;

	*quo = 0;
	if (uy.i<<1 == 0 || isnan(y) || ex == 0xff)
		return (x*y)/(x*y);
	if (ux.i<<1 == 0)
		return x;

	/* normalize x and y */
	if (!ex) {
		for (i = uxi<<9; i>>31 == 0; ex--, i <<= 1);
		uxi <<= -ex + 1;
	} else {
		uxi &= -1U >> 9;
		uxi |= 1U << 23;
	}
	if (!ey) {
		for (i = uy.i<<9; i>>31 == 0; ey--, i <<= 1);
		uy.i <<= -ey + 1;
	} else {
		uy.i &= -1U >> 9;
		uy.i |= 1U << 23;
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
		if (i >> 31 == 0) {
			uxi = i;
			q++;
		}
		uxi <<= 1;
		q <<= 1;
	}
	i = uxi - uy.i;
	if (i >> 31 == 0) {
		uxi = i;
		q++;
	}
	if (uxi == 0)
		ex = -30;
	else
		for (; uxi>>23 == 0; uxi <<= 1, ex--);
end:
	/* scale result and decide between |x| and |x|-|y| */
	if (ex > 0) {
		uxi -= 1U << 23;
		uxi |= (uint32_t)ex << 23;
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
