/* origin: FreeBSD /usr/src/lib/msun/ld80/e_rem_pio2.c */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 * Copyright (c) 2008 Steven G. Kargl, David Schultz, Bruce D. Evans.
 *
 * Developed at SunSoft, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 *
 * Optimized by Bruce D. Evans.
 */
#include "libm.h"
#if (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
/* ld80 and ld128 version of __rem_pio2(x,y)
 *
 * return the remainder of x rem pi/2 in y[0]+y[1]
 * use __rem_pio2_large() for large x
 */

static const long double toint = 1.5/LDBL_EPSILON;

#if LDBL_MANT_DIG == 64
/* u ~< 0x1p25*pi/2 */
#define SMALL(u) (((u.i.se & 0x7fffU)<<16 | u.i.m>>48) < ((0x3fff + 25)<<16 | 0x921f>>1 | 0x8000))
#define QUOBITS(x) ((uint32_t)(int32_t)x & 0x7fffffff)
#define ROUND1 22
#define ROUND2 61
#define NX 3
#define NY 2
/*
 * invpio2:  64 bits of 2/pi
 * pio2_1:   first  39 bits of pi/2
 * pio2_1t:  pi/2 - pio2_1
 * pio2_2:   second 39 bits of pi/2
 * pio2_2t:  pi/2 - (pio2_1+pio2_2)
 * pio2_3:   third  39 bits of pi/2
 * pio2_3t:  pi/2 - (pio2_1+pio2_2+pio2_3)
 */
static const double
pio2_1 =  1.57079632679597125389e+00, /* 0x3FF921FB, 0x54444000 */
pio2_2 = -1.07463465549783099519e-12, /* -0x12e7b967674000.0p-92 */
pio2_3 =  6.36831716351370313614e-25; /*  0x18a2e037074000.0p-133 */
static const long double
pio4    =  0x1.921fb54442d1846ap-1L,
invpio2 =  6.36619772367581343076e-01L, /*  0xa2f9836e4e44152a.0p-64 */
pio2_1t = -1.07463465549719416346e-12L, /* -0x973dcb3b399d747f.0p-103 */
pio2_2t =  6.36831716351095013979e-25L, /*  0xc51701b839a25205.0p-144 */
pio2_3t = -2.75299651904407171810e-37L; /* -0xbb5bf6c7ddd660ce.0p-185 */
#elif LDBL_MANT_DIG == 113
/* u ~< 0x1p45*pi/2 */
#define SMALL(u) (((u.i.se & 0x7fffU)<<16 | u.i.top) < ((0x3fff + 45)<<16 | 0x921f))
#define QUOBITS(x) ((uint32_t)(int64_t)x & 0x7fffffff)
#define ROUND1 51
#define ROUND2 119
#define NX 5
#define NY 3
static const long double
#ifdef __wasilibc_unmodified_upstream // Wasm doesn't have alternate rounding modes
pio4    =  0x1.921fb54442d18469898cc51701b8p-1L,
#endif
invpio2 =  6.3661977236758134307553505349005747e-01L,	/*  0x145f306dc9c882a53f84eafa3ea6a.0p-113 */
pio2_1  =  1.5707963267948966192292994253909555e+00L,	/*  0x1921fb54442d18469800000000000.0p-112 */
pio2_1t =  2.0222662487959507323996846200947577e-21L,	/*  0x13198a2e03707344a4093822299f3.0p-181 */
pio2_2  =  2.0222662487959507323994779168837751e-21L,	/*  0x13198a2e03707344a400000000000.0p-181 */
pio2_2t =  2.0670321098263988236496903051604844e-43L,	/*  0x127044533e63a0105df531d89cd91.0p-254 */
pio2_3  =  2.0670321098263988236499468110329591e-43L,	/*  0x127044533e63a0105e00000000000.0p-254 */
pio2_3t = -2.5650587247459238361625433492959285e-65L;	/* -0x159c4ec64ddaeb5f78671cbfb2210.0p-327 */
#endif

int __rem_pio2l(long double x, long double *y)
{
	union ldshape u,uz;
	long double z,w,t,r,fn;
	double tx[NX],ty[NY];
	int ex,ey,n,i;

	u.f = x;
	ex = u.i.se & 0x7fff;
	if (SMALL(u)) {
		/* rint(x/(pi/2)) */
		fn = x*invpio2 + toint - toint;
		n = QUOBITS(fn);
		r = x-fn*pio2_1;
		w = fn*pio2_1t;  /* 1st round good to 102/180 bits (ld80/ld128) */
#ifdef __wasilibc_unmodified_upstream // Wasm doesn't have alternate rounding modes
		/* Matters with directed rounding. */
		if (predict_false(r - w < -pio4)) {
			n--;
			fn--;
			r = x - fn*pio2_1;
			w = fn*pio2_1t;
		} else if (predict_false(r - w > pio4)) {
			n++;
			fn++;
			r = x - fn*pio2_1;
			w = fn*pio2_1t;
		}
#endif
		y[0] = r-w;
		u.f = y[0];
		ey = u.i.se & 0x7fff;
		if (ex - ey > ROUND1) {  /* 2nd iteration needed, good to 141/248 (ld80/ld128) */
			t = r;
			w = fn*pio2_2;
			r = t-w;
			w = fn*pio2_2t-((t-r)-w);
			y[0] = r-w;
			u.f = y[0];
			ey = u.i.se & 0x7fff;
			if (ex - ey > ROUND2) {  /* 3rd iteration, good to 180/316 bits */
				t = r; /* will cover all possible cases (not verified for ld128) */
				w = fn*pio2_3;
				r = t-w;
				w = fn*pio2_3t-((t-r)-w);
				y[0] = r-w;
			}
		}
		y[1] = (r - y[0]) - w;
		return n;
	}
	/*
	 * all other (large) arguments
	 */
	if (ex == 0x7fff) {                /* x is inf or NaN */
		y[0] = y[1] = x - x;
		return 0;
	}
	/* set z = scalbn(|x|,-ilogb(x)+23) */
	uz.f = x;
	uz.i.se = 0x3fff + 23;
	z = uz.f;
	for (i=0; i < NX - 1; i++) {
		tx[i] = (double)(int32_t)z;
		z     = (z-tx[i])*0x1p24;
	}
	tx[i] = z;
	while (tx[i] == 0)
		i--;
	n = __rem_pio2_large(tx, ty, ex-0x3fff-23, i+1, NY);
	w = ty[1];
	if (NY == 3)
		w += ty[2];
	r = ty[0] + w;
	/* TODO: for ld128 this does not follow the recommendation of the
	comments of __rem_pio2_large which seem wrong if |ty[0]| > |ty[1]+ty[2]| */
	w -= r - ty[0];
	if (u.i.se >> 15) {
		y[0] = -r;
		y[1] = -w;
		return -n;
	}
	y[0] = r;
	y[1] = w;
	return n;
}
#endif
