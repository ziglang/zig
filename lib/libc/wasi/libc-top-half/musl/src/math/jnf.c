/* origin: FreeBSD /usr/src/lib/msun/src/e_jnf.c */
/*
 * Conversion to float by Ian Lance Taylor, Cygnus Support, ian@cygnus.com.
 */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */

#define _GNU_SOURCE
#include "libm.h"

float jnf(int n, float x)
{
	uint32_t ix;
	int nm1, sign, i;
	float a, b, temp;

	GET_FLOAT_WORD(ix, x);
	sign = ix>>31;
	ix &= 0x7fffffff;
	if (ix > 0x7f800000) /* nan */
		return x;

	/* J(-n,x) = J(n,-x), use |n|-1 to avoid overflow in -n */
	if (n == 0)
		return j0f(x);
	if (n < 0) {
		nm1 = -(n+1);
		x = -x;
		sign ^= 1;
	} else
		nm1 = n-1;
	if (nm1 == 0)
		return j1f(x);

	sign &= n;  /* even n: 0, odd n: signbit(x) */
	x = fabsf(x);
	if (ix == 0 || ix == 0x7f800000)  /* if x is 0 or inf */
		b = 0.0f;
	else if (nm1 < x) {
		/* Safe to use J(n+1,x)=2n/x *J(n,x)-J(n-1,x) */
		a = j0f(x);
		b = j1f(x);
		for (i=0; i<nm1; ){
			i++;
			temp = b;
			b = b*(2.0f*i/x) - a;
			a = temp;
		}
	} else {
		if (ix < 0x35800000) { /* x < 2**-20 */
			/* x is tiny, return the first Taylor expansion of J(n,x)
			 * J(n,x) = 1/n!*(x/2)^n  - ...
			 */
			if (nm1 > 8)  /* underflow */
				nm1 = 8;
			temp = 0.5f * x;
			b = temp;
			a = 1.0f;
			for (i=2; i<=nm1+1; i++) {
				a *= (float)i;    /* a = n! */
				b *= temp;        /* b = (x/2)^n */
			}
			b = b/a;
		} else {
			/* use backward recurrence */
			/*                      x      x^2      x^2
			 *  J(n,x)/J(n-1,x) =  ----   ------   ------   .....
			 *                      2n  - 2(n+1) - 2(n+2)
			 *
			 *                      1      1        1
			 *  (for large x)   =  ----  ------   ------   .....
			 *                      2n   2(n+1)   2(n+2)
			 *                      -- - ------ - ------ -
			 *                       x     x         x
			 *
			 * Let w = 2n/x and h=2/x, then the above quotient
			 * is equal to the continued fraction:
			 *                  1
			 *      = -----------------------
			 *                     1
			 *         w - -----------------
			 *                        1
			 *              w+h - ---------
			 *                     w+2h - ...
			 *
			 * To determine how many terms needed, let
			 * Q(0) = w, Q(1) = w(w+h) - 1,
			 * Q(k) = (w+k*h)*Q(k-1) - Q(k-2),
			 * When Q(k) > 1e4      good for single
			 * When Q(k) > 1e9      good for double
			 * When Q(k) > 1e17     good for quadruple
			 */
			/* determine k */
			float t,q0,q1,w,h,z,tmp,nf;
			int k;

			nf = nm1+1.0f;
			w = 2*nf/x;
			h = 2/x;
			z = w+h;
			q0 = w;
			q1 = w*z - 1.0f;
			k = 1;
			while (q1 < 1.0e4f) {
				k += 1;
				z += h;
				tmp = z*q1 - q0;
				q0 = q1;
				q1 = tmp;
			}
			for (t=0.0f, i=k; i>=0; i--)
				t = 1.0f/(2*(i+nf)/x-t);
			a = t;
			b = 1.0f;
			/*  estimate log((2/x)^n*n!) = n*log(2/x)+n*ln(n)
			 *  Hence, if n*(log(2n/x)) > ...
			 *  single 8.8722839355e+01
			 *  double 7.09782712893383973096e+02
			 *  long double 1.1356523406294143949491931077970765006170e+04
			 *  then recurrent value may overflow and the result is
			 *  likely underflow to zero
			 */
			tmp = nf*logf(fabsf(w));
			if (tmp < 88.721679688f) {
				for (i=nm1; i>0; i--) {
					temp = b;
					b = 2.0f*i*b/x - a;
					a = temp;
				}
			} else {
				for (i=nm1; i>0; i--){
					temp = b;
					b = 2.0f*i*b/x - a;
					a = temp;
					/* scale b to avoid spurious overflow */
					if (b > 0x1p60f) {
						a /= b;
						t /= b;
						b = 1.0f;
					}
				}
			}
			z = j0f(x);
			w = j1f(x);
			if (fabsf(z) >= fabsf(w))
				b = t*z/b;
			else
				b = t*w/a;
		}
	}
	return sign ? -b : b;
}

float ynf(int n, float x)
{
	uint32_t ix, ib;
	int nm1, sign, i;
	float a, b, temp;

	GET_FLOAT_WORD(ix, x);
	sign = ix>>31;
	ix &= 0x7fffffff;
	if (ix > 0x7f800000) /* nan */
		return x;
	if (sign && ix != 0) /* x < 0 */
		return 0/0.0f;
	if (ix == 0x7f800000)
		return 0.0f;

	if (n == 0)
		return y0f(x);
	if (n < 0) {
		nm1 = -(n+1);
		sign = n&1;
	} else {
		nm1 = n-1;
		sign = 0;
	}
	if (nm1 == 0)
		return sign ? -y1f(x) : y1f(x);

	a = y0f(x);
	b = y1f(x);
	/* quit if b is -inf */
	GET_FLOAT_WORD(ib,b);
	for (i = 0; i < nm1 && ib != 0xff800000; ) {
		i++;
		temp = b;
		b = (2.0f*i/x)*b - a;
		GET_FLOAT_WORD(ib, b);
		a = temp;
	}
	return sign ? -b : b;
}
