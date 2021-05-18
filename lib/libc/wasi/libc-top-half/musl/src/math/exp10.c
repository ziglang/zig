#define _GNU_SOURCE
#include <math.h>
#include <stdint.h>

double exp10(double x)
{
	static const double p10[] = {
		1e-15, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10,
		1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1,
		1, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
		1e10, 1e11, 1e12, 1e13, 1e14, 1e15
	};
	double n, y = modf(x, &n);
	union {double f; uint64_t i;} u = {n};
	/* fabs(n) < 16 without raising invalid on nan */
	if ((u.i>>52 & 0x7ff) < 0x3ff+4) {
		if (!y) return p10[(int)n+15];
		y = exp2(3.32192809488736234787031942948939 * y);
		return y * p10[(int)n+15];
	}
	return pow(10.0, x);
}

weak_alias(exp10, pow10);
