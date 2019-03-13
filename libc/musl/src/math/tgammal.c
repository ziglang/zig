/* origin: OpenBSD /usr/src/lib/libm/src/ld80/e_tgammal.c */
/*
 * Copyright (c) 2008 Stephen L. Moshier <steve@moshier.net>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
/*
 *      Gamma function
 *
 *
 * SYNOPSIS:
 *
 * long double x, y, tgammal();
 *
 * y = tgammal( x );
 *
 *
 * DESCRIPTION:
 *
 * Returns gamma function of the argument.  The result is
 * correctly signed.
 *
 * Arguments |x| <= 13 are reduced by recurrence and the function
 * approximated by a rational function of degree 7/8 in the
 * interval (2,3).  Large arguments are handled by Stirling's
 * formula. Large negative arguments are made positive using
 * a reflection formula.
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    IEEE     -40,+40      10000       3.6e-19     7.9e-20
 *    IEEE    -1755,+1755   10000       4.8e-18     6.5e-19
 *
 * Accuracy for large arguments is dominated by error in powl().
 *
 */

#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double tgammal(long double x)
{
	return tgamma(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
/*
tgamma(x+2) = tgamma(x+2) P(x)/Q(x)
0 <= x <= 1
Relative error
n=7, d=8
Peak error =  1.83e-20
Relative error spread =  8.4e-23
*/
static const long double P[8] = {
 4.212760487471622013093E-5L,
 4.542931960608009155600E-4L,
 4.092666828394035500949E-3L,
 2.385363243461108252554E-2L,
 1.113062816019361559013E-1L,
 3.629515436640239168939E-1L,
 8.378004301573126728826E-1L,
 1.000000000000000000009E0L,
};
static const long double Q[9] = {
-1.397148517476170440917E-5L,
 2.346584059160635244282E-4L,
-1.237799246653152231188E-3L,
-7.955933682494738320586E-4L,
 2.773706565840072979165E-2L,
-4.633887671244534213831E-2L,
-2.243510905670329164562E-1L,
 4.150160950588455434583E-1L,
 9.999999999999999999908E-1L,
};

/*
static const long double P[] = {
-3.01525602666895735709e0L,
-3.25157411956062339893e1L,
-2.92929976820724030353e2L,
-1.70730828800510297666e3L,
-7.96667499622741999770e3L,
-2.59780216007146401957e4L,
-5.99650230220855581642e4L,
-7.15743521530849602425e4L
};
static const long double Q[] = {
 1.00000000000000000000e0L,
-1.67955233807178858919e1L,
 8.85946791747759881659e1L,
 5.69440799097468430177e1L,
-1.98526250512761318471e3L,
 3.31667508019495079814e3L,
 1.60577839621734713377e4L,
-2.97045081369399940529e4L,
-7.15743521530849602412e4L
};
*/
#define MAXGAML 1755.455L
/*static const long double LOGPI = 1.14472988584940017414L;*/

/* Stirling's formula for the gamma function
tgamma(x) = sqrt(2 pi) x^(x-.5) exp(-x) (1 + 1/x P(1/x))
z(x) = x
13 <= x <= 1024
Relative error
n=8, d=0
Peak error =  9.44e-21
Relative error spread =  8.8e-4
*/
static const long double STIR[9] = {
 7.147391378143610789273E-4L,
-2.363848809501759061727E-5L,
-5.950237554056330156018E-4L,
 6.989332260623193171870E-5L,
 7.840334842744753003862E-4L,
-2.294719747873185405699E-4L,
-2.681327161876304418288E-3L,
 3.472222222230075327854E-3L,
 8.333333333333331800504E-2L,
};

#define MAXSTIR 1024.0L
static const long double SQTPI = 2.50662827463100050242E0L;

/* 1/tgamma(x) = z P(z)
 * z(x) = 1/x
 * 0 < x < 0.03125
 * Peak relative error 4.2e-23
 */
static const long double S[9] = {
-1.193945051381510095614E-3L,
 7.220599478036909672331E-3L,
-9.622023360406271645744E-3L,
-4.219773360705915470089E-2L,
 1.665386113720805206758E-1L,
-4.200263503403344054473E-2L,
-6.558780715202540684668E-1L,
 5.772156649015328608253E-1L,
 1.000000000000000000000E0L,
};

/* 1/tgamma(-x) = z P(z)
 * z(x) = 1/x
 * 0 < x < 0.03125
 * Peak relative error 5.16e-23
 * Relative error spread =  2.5e-24
 */
static const long double SN[9] = {
 1.133374167243894382010E-3L,
 7.220837261893170325704E-3L,
 9.621911155035976733706E-3L,
-4.219773343731191721664E-2L,
-1.665386113944413519335E-1L,
-4.200263503402112910504E-2L,
 6.558780715202536547116E-1L,
 5.772156649015328608727E-1L,
-1.000000000000000000000E0L,
};

static const long double PIL = 3.1415926535897932384626L;

/* Gamma function computed by Stirling's formula.
 */
static long double stirf(long double x)
{
	long double y, w, v;

	w = 1.0/x;
	/* For large x, use rational coefficients from the analytical expansion.  */
	if (x > 1024.0)
		w = (((((6.97281375836585777429E-5L * w
		 + 7.84039221720066627474E-4L) * w
		 - 2.29472093621399176955E-4L) * w
		 - 2.68132716049382716049E-3L) * w
		 + 3.47222222222222222222E-3L) * w
		 + 8.33333333333333333333E-2L) * w
		 + 1.0;
	else
		w = 1.0 + w * __polevll(w, STIR, 8);
	y = expl(x);
	if (x > MAXSTIR) { /* Avoid overflow in pow() */
		v = powl(x, 0.5L * x - 0.25L);
		y = v * (v / y);
	} else {
		y = powl(x, x - 0.5L) / y;
	}
	y = SQTPI * y * w;
	return y;
}

long double tgammal(long double x)
{
	long double p, q, z;

	if (!isfinite(x))
		return x + INFINITY;

	q = fabsl(x);
	if (q > 13.0) {
		if (x < 0.0) {
			p = floorl(q);
			z = q - p;
			if (z == 0)
				return 0 / z;
			if (q > MAXGAML) {
				z = 0;
			} else {
				if (z > 0.5) {
					p += 1.0;
					z = q - p;
				}
				z = q * sinl(PIL * z);
				z = fabsl(z) * stirf(q);
				z = PIL/z;
			}
			if (0.5 * p == floorl(q * 0.5))
				z = -z;
		} else if (x > MAXGAML) {
			z = x * 0x1p16383L;
		} else {
			z = stirf(x);
		}
		return z;
	}

	z = 1.0;
	while (x >= 3.0) {
		x -= 1.0;
		z *= x;
	}
	while (x < -0.03125L) {
		z /= x;
		x += 1.0;
	}
	if (x <= 0.03125L)
		goto small;
	while (x < 2.0) {
		z /= x;
		x += 1.0;
	}
	if (x == 2.0)
		return z;

	x -= 2.0;
	p = __polevll(x, P, 7);
	q = __polevll(x, Q, 8);
	z = z * p / q;
	return z;

small:
	/* z==1 if x was originally +-0 */
	if (x == 0 && z != 1)
		return x / x;
	if (x < 0.0) {
		x = -x;
		q = z / (x * __polevll(x, SN, 8));
	} else
		q = z / (x * __polevll(x, S, 8));
	return q;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
// TODO: broken implementation to make things compile
long double tgammal(long double x)
{
	return tgamma(x);
}
#endif
