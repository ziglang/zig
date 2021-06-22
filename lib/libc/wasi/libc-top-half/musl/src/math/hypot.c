#include <math.h>
#include <stdint.h>
#include <float.h>

#if FLT_EVAL_METHOD > 1U && LDBL_MANT_DIG == 64
#define SPLIT (0x1p32 + 1)
#else
#define SPLIT (0x1p27 + 1)
#endif

static void sq(double_t *hi, double_t *lo, double x)
{
	double_t xh, xl, xc;

	xc = (double_t)x*SPLIT;
	xh = x - xc + xc;
	xl = x - xh;
	*hi = (double_t)x*x;
	*lo = xh*xh - *hi + 2*xh*xl + xl*xl;
}

double hypot(double x, double y)
{
	union {double f; uint64_t i;} ux = {x}, uy = {y}, ut;
	int ex, ey;
	double_t hx, lx, hy, ly, z;

	/* arrange |x| >= |y| */
	ux.i &= -1ULL>>1;
	uy.i &= -1ULL>>1;
	if (ux.i < uy.i) {
		ut = ux;
		ux = uy;
		uy = ut;
	}

	/* special cases */
	ex = ux.i>>52;
	ey = uy.i>>52;
	x = ux.f;
	y = uy.f;
	/* note: hypot(inf,nan) == inf */
	if (ey == 0x7ff)
		return y;
	if (ex == 0x7ff || uy.i == 0)
		return x;
	/* note: hypot(x,y) ~= x + y*y/x/2 with inexact for small y/x */
	/* 64 difference is enough for ld80 double_t */
	if (ex - ey > 64)
		return x + y;

	/* precise sqrt argument in nearest rounding mode without overflow */
	/* xh*xh must not overflow and xl*xl must not underflow in sq */
	z = 1;
	if (ex > 0x3ff+510) {
		z = 0x1p700;
		x *= 0x1p-700;
		y *= 0x1p-700;
	} else if (ey < 0x3ff-450) {
		z = 0x1p-700;
		x *= 0x1p700;
		y *= 0x1p700;
	}
	sq(&hx, &lx, x);
	sq(&hy, &ly, y);
	return z*sqrt(ly+lx+hy+hx);
}
