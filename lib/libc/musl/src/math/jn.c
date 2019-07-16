/* origin: FreeBSD /usr/src/lib/msun/src/e_jn.c */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunSoft, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */
/*
 * jn(n, x), yn(n, x)
 * floating point Bessel's function of the 1st and 2nd kind
 * of order n
 *
 * Special cases:
 *      y0(0)=y1(0)=yn(n,0) = -inf with division by zero signal;
 *      y0(-ve)=y1(-ve)=yn(n,-ve) are NaN with invalid signal.
 * Note 2. About jn(n,x), yn(n,x)
 *      For n=0, j0(x) is called,
 *      for n=1, j1(x) is called,
 *      for n<=x, forward recursion is used starting
 *      from values of j0(x) and j1(x).
 *      for n>x, a continued fraction approximation to
 *      j(n,x)/j(n-1,x) is evaluated and then backward
 *      recursion is used starting from a supposed value
 *      for j(n,x). The resulting value of j(0,x) is
 *      compared with the actual value to correct the
 *      supposed value of j(n,x).
 *
 *      yn(n,x) is similar in all respects, except
 *      that forward recursion is used for all
 *      values of n>1.
 */

#include "libm.h"

static const double invsqrtpi = 5.64189583547756279280e-01; /* 0x3FE20DD7, 0x50429B6D */

double jn(int n, double x)
{
	uint32_t ix, lx;
	int nm1, i, sign;
	double a, b, temp;

	EXTRACT_WORDS(ix, lx, x);
	sign = ix>>31;
	ix &= 0x7fffffff;

	if ((ix | (lx|-lx)>>31) > 0x7ff00000) /* nan */
		return x;

	/* J(-n,x) = (-1)^n * J(n, x), J(n, -x) = (-1)^n * J(n, x)
	 * Thus, J(-n,x) = J(n,-x)
	 */
	/* nm1 = |n|-1 is used instead of |n| to handle n==INT_MIN */
	if (n == 0)
		return j0(x);
	if (n < 0) {
		nm1 = -(n+1);
		x = -x;
		sign ^= 1;
	} else
		nm1 = n-1;
	if (nm1 == 0)
		return j1(x);

	sign &= n;  /* even n: 0, odd n: signbit(x) */
	x = fabs(x);
	if ((ix|lx) == 0 || ix == 0x7ff00000)  /* if x is 0 or inf */
		b = 0.0;
	else if (nm1 < x) {
		/* Safe to use J(n+1,x)=2n/x *J(n,x)-J(n-1,x) */
		if (ix >= 0x52d00000) { /* x > 2**302 */
			/* (x >> n**2)
			 *      Jn(x) = cos(x-(2n+1)*pi/4)*sqrt(2/x*pi)
			 *      Yn(x) = sin(x-(2n+1)*pi/4)*sqrt(2/x*pi)
			 *      Let s=sin(x), c=cos(x),
			 *          xn=x-(2n+1)*pi/4, sqt2 = sqrt(2),then
			 *
			 *             n    sin(xn)*sqt2    cos(xn)*sqt2
			 *          ----------------------------------
			 *             0     s-c             c+s
			 *             1    -s-c            -c+s
			 *             2    -s+c            -c-s
			 *             3     s+c             c-s
			 */
			switch(nm1&3) {
			case 0: temp = -cos(x)+sin(x); break;
			case 1: temp = -cos(x)-sin(x); break;
			case 2: temp =  cos(x)-sin(x); break;
			default:
			case 3: temp =  cos(x)+sin(x); break;
			}
			b = invsqrtpi*temp/sqrt(x);
		} else {
			a = j0(x);
			b = j1(x);
			for (i=0; i<nm1; ) {
				i++;
				temp = b;
				b = b*(2.0*i/x) - a; /* avoid underflow */
				a = temp;
			}
		}
	} else {
		if (ix < 0x3e100000) { /* x < 2**-29 */
			/* x is tiny, return the first Taylor expansion of J(n,x)
			 * J(n,x) = 1/n!*(x/2)^n  - ...
			 */
			if (nm1 > 32)  /* underflow */
				b = 0.0;
			else {
				temp = x*0.5;
				b = temp;
				a = 1.0;
				for (i=2; i<=nm1+1; i++) {
					a *= (double)i; /* a = n! */
					b *= temp;      /* b = (x/2)^n */
				}
				b = b/a;
			}
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
			double t,q0,q1,w,h,z,tmp,nf;
			int k;

			nf = nm1 + 1.0;
			w = 2*nf/x;
			h = 2/x;
			z = w+h;
			q0 = w;
			q1 = w*z - 1.0;
			k = 1;
			while (q1 < 1.0e9) {
				k += 1;
				z += h;
				tmp = z*q1 - q0;
				q0 = q1;
				q1 = tmp;
			}
			for (t=0.0, i=k; i>=0; i--)
				t = 1/(2*(i+nf)/x - t);
			a = t;
			b = 1.0;
			/*  estimate log((2/x)^n*n!) = n*log(2/x)+n*ln(n)
			 *  Hence, if n*(log(2n/x)) > ...
			 *  single 8.8722839355e+01
			 *  double 7.09782712893383973096e+02
			 *  long double 1.1356523406294143949491931077970765006170e+04
			 *  then recurrent value may overflow and the result is
			 *  likely underflow to zero
			 */
			tmp = nf*log(fabs(w));
			if (tmp < 7.09782712893383973096e+02) {
				for (i=nm1; i>0; i--) {
					temp = b;
					b = b*(2.0*i)/x - a;
					a = temp;
				}
			} else {
				for (i=nm1; i>0; i--) {
					temp = b;
					b = b*(2.0*i)/x - a;
					a = temp;
					/* scale b to avoid spurious overflow */
					if (b > 0x1p500) {
						a /= b;
						t /= b;
						b  = 1.0;
					}
				}
			}
			z = j0(x);
			w = j1(x);
			if (fabs(z) >= fabs(w))
				b = t*z/b;
			else
				b = t*w/a;
		}
	}
	return sign ? -b : b;
}


double yn(int n, double x)
{
	uint32_t ix, lx, ib;
	int nm1, sign, i;
	double a, b, temp;

	EXTRACT_WORDS(ix, lx, x);
	sign = ix>>31;
	ix &= 0x7fffffff;

	if ((ix | (lx|-lx)>>31) > 0x7ff00000) /* nan */
		return x;
	if (sign && (ix|lx)!=0) /* x < 0 */
		return 0/0.0;
	if (ix == 0x7ff00000)
		return 0.0;

	if (n == 0)
		return y0(x);
	if (n < 0) {
		nm1 = -(n+1);
		sign = n&1;
	} else {
		nm1 = n-1;
		sign = 0;
	}
	if (nm1 == 0)
		return sign ? -y1(x) : y1(x);

	if (ix >= 0x52d00000) { /* x > 2**302 */
		/* (x >> n**2)
		 *      Jn(x) = cos(x-(2n+1)*pi/4)*sqrt(2/x*pi)
		 *      Yn(x) = sin(x-(2n+1)*pi/4)*sqrt(2/x*pi)
		 *      Let s=sin(x), c=cos(x),
		 *          xn=x-(2n+1)*pi/4, sqt2 = sqrt(2),then
		 *
		 *             n    sin(xn)*sqt2    cos(xn)*sqt2
		 *          ----------------------------------
		 *             0     s-c             c+s
		 *             1    -s-c            -c+s
		 *             2    -s+c            -c-s
		 *             3     s+c             c-s
		 */
		switch(nm1&3) {
		case 0: temp = -sin(x)-cos(x); break;
		case 1: temp = -sin(x)+cos(x); break;
		case 2: temp =  sin(x)+cos(x); break;
		default:
		case 3: temp =  sin(x)-cos(x); break;
		}
		b = invsqrtpi*temp/sqrt(x);
	} else {
		a = y0(x);
		b = y1(x);
		/* quit if b is -inf */
		GET_HIGH_WORD(ib, b);
		for (i=0; i<nm1 && ib!=0xfff00000; ){
			i++;
			temp = b;
			b = (2.0*i/x)*b - a;
			GET_HIGH_WORD(ib, b);
			a = temp;
		}
	}
	return sign ? -b : b;
}
