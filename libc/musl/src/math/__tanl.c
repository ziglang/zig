/* origin: FreeBSD /usr/src/lib/msun/ld80/k_tanl.c */
/* origin: FreeBSD /usr/src/lib/msun/ld128/k_tanl.c */
/*
 * ====================================================
 * Copyright 2004 Sun Microsystems, Inc.  All Rights Reserved.
 * Copyright (c) 2008 Steven G. Kargl, David Schultz, Bruce D. Evans.
 *
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */

#include "libm.h"

#if (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
#if LDBL_MANT_DIG == 64
/*
 * ld80 version of __tan.c.  See __tan.c for most comments.
 */
/*
 * Domain [-0.67434, 0.67434], range ~[-2.25e-22, 1.921e-22]
 * |tan(x)/x - t(x)| < 2**-71.9
 *
 * See __cosl.c for more details about the polynomial.
 */
static const long double
T3 =  0.333333333333333333180L,         /*  0xaaaaaaaaaaaaaaa5.0p-65 */
T5 =  0.133333333333333372290L,         /*  0x88888888888893c3.0p-66 */
T7 =  0.0539682539682504975744L,        /*  0xdd0dd0dd0dc13ba2.0p-68 */
pio4   =  0.785398163397448309628L,     /*  0xc90fdaa22168c235.0p-64 */
pio4lo = -1.25413940316708300586e-20L;  /* -0xece675d1fc8f8cbb.0p-130 */
static const double
T9  =  0.021869488536312216,            /*  0x1664f4882cc1c2.0p-58 */
T11 =  0.0088632355256619590,           /*  0x1226e355c17612.0p-59 */
T13 =  0.0035921281113786528,           /*  0x1d6d3d185d7ff8.0p-61 */
T15 =  0.0014558334756312418,           /*  0x17da354aa3f96b.0p-62 */
T17 =  0.00059003538700862256,          /*  0x13559358685b83.0p-63 */
T19 =  0.00023907843576635544,          /*  0x1f56242026b5be.0p-65 */
T21 =  0.000097154625656538905,         /*  0x1977efc26806f4.0p-66 */
T23 =  0.000038440165747303162,         /*  0x14275a09b3ceac.0p-67 */
T25 =  0.000018082171885432524,         /*  0x12f5e563e5487e.0p-68 */
T27 =  0.0000024196006108814377,        /*  0x144c0d80cc6896.0p-71 */
T29 =  0.0000078293456938132840,        /*  0x106b59141a6cb3.0p-69 */
T31 = -0.0000032609076735050182,        /* -0x1b5abef3ba4b59.0p-71 */
T33 =  0.0000023261313142559411;        /*  0x13835436c0c87f.0p-71 */
#define RPOLY(w) (T5 + w * (T9 + w * (T13 + w * (T17 + w * (T21 + \
	w * (T25 + w * (T29 + w * T33)))))))
#define VPOLY(w) (T7 + w * (T11 + w * (T15 + w * (T19 + w * (T23 + \
	w * (T27 + w * T31))))))
#elif LDBL_MANT_DIG == 113
/*
 * ld128 version of __tan.c.  See __tan.c for most comments.
 */
/*
 * Domain [-0.67434, 0.67434], range ~[-3.37e-36, 1.982e-37]
 * |tan(x)/x - t(x)| < 2**-117.8 (XXX should be ~1e-37)
 *
 * See __cosl.c for more details about the polynomial.
 */
static const long double
T3 = 0x1.5555555555555555555555555553p-2L,
T5 = 0x1.1111111111111111111111111eb5p-3L,
T7 = 0x1.ba1ba1ba1ba1ba1ba1ba1b694cd6p-5L,
T9 = 0x1.664f4882c10f9f32d6bbe09d8bcdp-6L,
T11 = 0x1.226e355e6c23c8f5b4f5762322eep-7L,
T13 = 0x1.d6d3d0e157ddfb5fed8e84e27b37p-9L,
T15 = 0x1.7da36452b75e2b5fce9ee7c2c92ep-10L,
T17 = 0x1.355824803674477dfcf726649efep-11L,
T19 = 0x1.f57d7734d1656e0aceb716f614c2p-13L,
T21 = 0x1.967e18afcb180ed942dfdc518d6cp-14L,
T23 = 0x1.497d8eea21e95bc7e2aa79b9f2cdp-15L,
T25 = 0x1.0b132d39f055c81be49eff7afd50p-16L,
T27 = 0x1.b0f72d33eff7bfa2fbc1059d90b6p-18L,
T29 = 0x1.5ef2daf21d1113df38d0fbc00267p-19L,
T31 = 0x1.1c77d6eac0234988cdaa04c96626p-20L,
T33 = 0x1.cd2a5a292b180e0bdd701057dfe3p-22L,
T35 = 0x1.75c7357d0298c01a31d0a6f7d518p-23L,
T37 = 0x1.2f3190f4718a9a520f98f50081fcp-24L,
pio4 = 0x1.921fb54442d18469898cc51701b8p-1L,
pio4lo = 0x1.cd129024e088a67cc74020bbea60p-116L;
static const double
T39 =  0.000000028443389121318352,	/*  0x1e8a7592977938.0p-78 */
T41 =  0.000000011981013102001973,	/*  0x19baa1b1223219.0p-79 */
T43 =  0.0000000038303578044958070,	/*  0x107385dfb24529.0p-80 */
T45 =  0.0000000034664378216909893,	/*  0x1dc6c702a05262.0p-81 */
T47 = -0.0000000015090641701997785,	/* -0x19ecef3569ebb6.0p-82 */
T49 =  0.0000000029449552300483952,	/*  0x194c0668da786a.0p-81 */
T51 = -0.0000000022006995706097711,	/* -0x12e763b8845268.0p-81 */
T53 =  0.0000000015468200913196612,	/*  0x1a92fc98c29554.0p-82 */
T55 = -0.00000000061311613386849674,	/* -0x151106cbc779a9.0p-83 */
T57 =  1.4912469681508012e-10;		/*  0x147edbdba6f43a.0p-85 */
#define RPOLY(w) (T5 + w * (T9 + w * (T13 + w * (T17 + w * (T21 + \
	w * (T25 + w * (T29 + w * (T33 + w * (T37 + w * (T41 + \
	w * (T45 + w * (T49 + w * (T53 + w * T57)))))))))))))
#define VPOLY(w) (T7 + w * (T11 + w * (T15 + w * (T19 + w * (T23 + \
	w * (T27 + w * (T31 + w * (T35 + w * (T39 + w * (T43 + \
	w * (T47 + w * (T51 + w * T55))))))))))))
#endif

long double __tanl(long double x, long double y, int odd) {
	long double z, r, v, w, s, a, t;
	int big, sign;

	big = fabsl(x) >= 0.67434;
	if (big) {
		sign = 0;
		if (x < 0) {
			sign = 1;
			x = -x;
			y = -y;
		}
		x = (pio4 - x) + (pio4lo - y);
		y = 0.0;
	}
	z = x * x;
	w = z * z;
	r = RPOLY(w);
	v = z * VPOLY(w);
	s = z * x;
	r = y + z * (s * (r + v) + y) + T3 * s;
	w = x + r;
	if (big) {
		s = 1 - 2*odd;
		v = s - 2.0 * (x + (r - w * w / (w + s)));
		return sign ? -v : v;
	}
	if (!odd)
		return w;
	/*
	 * if allow error up to 2 ulp, simply return
	 * -1.0 / (x+r) here
	 */
	/* compute -1.0 / (x+r) accurately */
	z = w;
	z = z + 0x1p32 - 0x1p32;
	v = r - (z - x);        /* z+v = r+x */
	t = a = -1.0 / w;       /* a = -1.0/w */
	t = t + 0x1p32 - 0x1p32;
	s = 1.0 + t * z;
	return t + a * (s + t * v);
}
#endif
