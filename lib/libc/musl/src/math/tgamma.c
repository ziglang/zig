/*
"A Precision Approximation of the Gamma Function" - Cornelius Lanczos (1964)
"Lanczos Implementation of the Gamma Function" - Paul Godfrey (2001)
"An Analysis of the Lanczos Gamma Approximation" - Glendon Ralph Pugh (2004)

approximation method:

                        (x - 0.5)         S(x)
Gamma(x) = (x + g - 0.5)         *  ----------------
                                    exp(x + g - 0.5)

with
                 a1      a2      a3            aN
S(x) ~= [ a0 + ----- + ----- + ----- + ... + ----- ]
               x + 1   x + 2   x + 3         x + N

with a0, a1, a2, a3,.. aN constants which depend on g.

for x < 0 the following reflection formula is used:

Gamma(x)*Gamma(-x) = -pi/(x sin(pi x))

most ideas and constants are from boost and python
*/
#include "libm.h"

static const double pi = 3.141592653589793238462643383279502884;

/* sin(pi x) with x > 0x1p-100, if sin(pi*x)==0 the sign is arbitrary */
static double sinpi(double x)
{
	int n;

	/* argument reduction: x = |x| mod 2 */
	/* spurious inexact when x is odd int */
	x = x * 0.5;
	x = 2 * (x - floor(x));

	/* reduce x into [-.25,.25] */
	n = 4 * x;
	n = (n+1)/2;
	x -= n * 0.5;

	x *= pi;
	switch (n) {
	default: /* case 4 */
	case 0:
		return __sin(x, 0, 0);
	case 1:
		return __cos(x, 0);
	case 2:
		return __sin(-x, 0, 0);
	case 3:
		return -__cos(x, 0);
	}
}

#define N 12
//static const double g = 6.024680040776729583740234375;
static const double gmhalf = 5.524680040776729583740234375;
static const double Snum[N+1] = {
	23531376880.410759688572007674451636754734846804940,
	42919803642.649098768957899047001988850926355848959,
	35711959237.355668049440185451547166705960488635843,
	17921034426.037209699919755754458931112671403265390,
	6039542586.3520280050642916443072979210699388420708,
	1439720407.3117216736632230727949123939715485786772,
	248874557.86205415651146038641322942321632125127801,
	31426415.585400194380614231628318205362874684987640,
	2876370.6289353724412254090516208496135991145378768,
	186056.26539522349504029498971604569928220784236328,
	8071.6720023658162106380029022722506138218516325024,
	210.82427775157934587250973392071336271166969580291,
	2.5066282746310002701649081771338373386264310793408,
};
static const double Sden[N+1] = {
	0, 39916800, 120543840, 150917976, 105258076, 45995730, 13339535,
	2637558, 357423, 32670, 1925, 66, 1,
};
/* n! for small integer n */
static const double fact[] = {
	1, 1, 2, 6, 24, 120, 720, 5040.0, 40320.0, 362880.0, 3628800.0, 39916800.0,
	479001600.0, 6227020800.0, 87178291200.0, 1307674368000.0, 20922789888000.0,
	355687428096000.0, 6402373705728000.0, 121645100408832000.0,
	2432902008176640000.0, 51090942171709440000.0, 1124000727777607680000.0,
};

/* S(x) rational function for positive x */
static double S(double x)
{
	double_t num = 0, den = 0;
	int i;

	/* to avoid overflow handle large x differently */
	if (x < 8)
		for (i = N; i >= 0; i--) {
			num = num * x + Snum[i];
			den = den * x + Sden[i];
		}
	else
		for (i = 0; i <= N; i++) {
			num = num / x + Snum[i];
			den = den / x + Sden[i];
		}
	return num/den;
}

double tgamma(double x)
{
	union {double f; uint64_t i;} u = {x};
	double absx, y;
	double_t dy, z, r;
	uint32_t ix = u.i>>32 & 0x7fffffff;
	int sign = u.i>>63;

	/* special cases */
	if (ix >= 0x7ff00000)
		/* tgamma(nan)=nan, tgamma(inf)=inf, tgamma(-inf)=nan with invalid */
		return x + INFINITY;
	if (ix < (0x3ff-54)<<20)
		/* |x| < 2^-54: tgamma(x) ~ 1/x, +-0 raises div-by-zero */
		return 1/x;

	/* integer arguments */
	/* raise inexact when non-integer */
	if (x == floor(x)) {
		if (sign)
			return 0/0.0;
		if (x <= sizeof fact/sizeof *fact)
			return fact[(int)x - 1];
	}

	/* x >= 172: tgamma(x)=inf with overflow */
	/* x =< -184: tgamma(x)=+-0 with underflow */
	if (ix >= 0x40670000) { /* |x| >= 184 */
		if (sign) {
			FORCE_EVAL((float)(0x1p-126/x));
			if (floor(x) * 0.5 == floor(x * 0.5))
				return 0;
			return -0.0;
		}
		x *= 0x1p1023;
		return x;
	}

	absx = sign ? -x : x;

	/* handle the error of x + g - 0.5 */
	y = absx + gmhalf;
	if (absx > gmhalf) {
		dy = y - absx;
		dy -= gmhalf;
	} else {
		dy = y - gmhalf;
		dy -= absx;
	}

	z = absx - 0.5;
	r = S(absx) * exp(-y);
	if (x < 0) {
		/* reflection formula for negative x */
		/* sinpi(absx) is not 0, integers are already handled */
		r = -pi / (sinpi(absx) * absx * r);
		dy = -dy;
		z = -z;
	}
	r += dy * (gmhalf+0.5) * r / y;
	z = pow(y, 0.5*z);
	y = r * z * z;
	return y;
}

#if 0
double __lgamma_r(double x, int *sign)
{
	double r, absx;

	*sign = 1;

	/* special cases */
	if (!isfinite(x))
		/* lgamma(nan)=nan, lgamma(+-inf)=inf */
		return x*x;

	/* integer arguments */
	if (x == floor(x) && x <= 2) {
		/* n <= 0: lgamma(n)=inf with divbyzero */
		/* n == 1,2: lgamma(n)=0 */
		if (x <= 0)
			return 1/0.0;
		return 0;
	}

	absx = fabs(x);

	/* lgamma(x) ~ -log(|x|) for tiny |x| */
	if (absx < 0x1p-54) {
		*sign = 1 - 2*!!signbit(x);
		return -log(absx);
	}

	/* use tgamma for smaller |x| */
	if (absx < 128) {
		x = tgamma(x);
		*sign = 1 - 2*!!signbit(x);
		return log(fabs(x));
	}

	/* second term (log(S)-g) could be more precise here.. */
	/* or with stirling: (|x|-0.5)*(log(|x|)-1) + poly(1/|x|) */
	r = (absx-0.5)*(log(absx+gmhalf)-1) + (log(S(absx)) - (gmhalf+0.5));
	if (x < 0) {
		/* reflection formula for negative x */
		x = sinpi(absx);
		*sign = 2*!!signbit(x) - 1;
		r = log(pi/(fabs(x)*absx)) - r;
	}
	return r;
}

weak_alias(__lgamma_r, lgamma_r);
#endif
