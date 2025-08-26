/* origin: FreeBSD /usr/src/lib/msun/src/e_j0f.c */
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

static float pzerof(float), qzerof(float);

static const float
invsqrtpi = 5.6418961287e-01, /* 0x3f106ebb */
tpi       = 6.3661974669e-01; /* 0x3f22f983 */

static float common(uint32_t ix, float x, int y0)
{
	float z,s,c,ss,cc;
	/*
	 * j0(x) = 1/sqrt(pi) * (P(0,x)*cc - Q(0,x)*ss) / sqrt(x)
	 * y0(x) = 1/sqrt(pi) * (P(0,x)*ss + Q(0,x)*cc) / sqrt(x)
	 */
	s = sinf(x);
	c = cosf(x);
	if (y0)
		c = -c;
	cc = s+c;
	if (ix < 0x7f000000) {
		ss = s-c;
		z = -cosf(2*x);
		if (s*c < 0)
			cc = z/ss;
		else
			ss = z/cc;
		if (ix < 0x58800000) {
			if (y0)
				ss = -ss;
			cc = pzerof(x)*cc-qzerof(x)*ss;
		}
	}
	return invsqrtpi*cc/sqrtf(x);
}

/* R0/S0 on [0, 2.00] */
static const float
R02 =  1.5625000000e-02, /* 0x3c800000 */
R03 = -1.8997929874e-04, /* 0xb947352e */
R04 =  1.8295404516e-06, /* 0x35f58e88 */
R05 = -4.6183270541e-09, /* 0xb19eaf3c */
S01 =  1.5619102865e-02, /* 0x3c7fe744 */
S02 =  1.1692678527e-04, /* 0x38f53697 */
S03 =  5.1354652442e-07, /* 0x3509daa6 */
S04 =  1.1661400734e-09; /* 0x30a045e8 */

float j0f(float x)
{
	float z,r,s;
	uint32_t ix;

	GET_FLOAT_WORD(ix, x);
	ix &= 0x7fffffff;
	if (ix >= 0x7f800000)
		return 1/(x*x);
	x = fabsf(x);

	if (ix >= 0x40000000) {  /* |x| >= 2 */
		/* large ulp error near zeros */
		return common(ix, x, 0);
	}
	if (ix >= 0x3a000000) {  /* |x| >= 2**-11 */
		/* up to 4ulp error near 2 */
		z = x*x;
		r = z*(R02+z*(R03+z*(R04+z*R05)));
		s = 1+z*(S01+z*(S02+z*(S03+z*S04)));
		return (1+x/2)*(1-x/2) + z*(r/s);
	}
	if (ix >= 0x21800000)  /* |x| >= 2**-60 */
		x = 0.25f*x*x;
	return 1 - x;
}

static const float
u00  = -7.3804296553e-02, /* 0xbd9726b5 */
u01  =  1.7666645348e-01, /* 0x3e34e80d */
u02  = -1.3818567619e-02, /* 0xbc626746 */
u03  =  3.4745343146e-04, /* 0x39b62a69 */
u04  = -3.8140706238e-06, /* 0xb67ff53c */
u05  =  1.9559013964e-08, /* 0x32a802ba */
u06  = -3.9820518410e-11, /* 0xae2f21eb */
v01  =  1.2730483897e-02, /* 0x3c509385 */
v02  =  7.6006865129e-05, /* 0x389f65e0 */
v03  =  2.5915085189e-07, /* 0x348b216c */
v04  =  4.4111031494e-10; /* 0x2ff280c2 */

float y0f(float x)
{
	float z,u,v;
	uint32_t ix;

	GET_FLOAT_WORD(ix, x);
	if ((ix & 0x7fffffff) == 0)
		return -1/0.0f;
	if (ix>>31)
		return 0/0.0f;
	if (ix >= 0x7f800000)
		return 1/x;
	if (ix >= 0x40000000) {  /* |x| >= 2.0 */
		/* large ulp error near zeros */
		return common(ix,x,1);
	}
	if (ix >= 0x39000000) {  /* x >= 2**-13 */
		/* large ulp error at x ~= 0.89 */
		z = x*x;
		u = u00+z*(u01+z*(u02+z*(u03+z*(u04+z*(u05+z*u06)))));
		v = 1+z*(v01+z*(v02+z*(v03+z*v04)));
		return u/v + tpi*(j0f(x)*logf(x));
	}
	return u00 + tpi*logf(x);
}

/* The asymptotic expansions of pzero is
 *      1 - 9/128 s^2 + 11025/98304 s^4 - ...,  where s = 1/x.
 * For x >= 2, We approximate pzero by
 *      pzero(x) = 1 + (R/S)
 * where  R = pR0 + pR1*s^2 + pR2*s^4 + ... + pR5*s^10
 *        S = 1 + pS0*s^2 + ... + pS4*s^10
 * and
 *      | pzero(x)-1-R/S | <= 2  ** ( -60.26)
 */
static const float pR8[6] = { /* for x in [inf, 8]=1/[0,0.125] */
  0.0000000000e+00, /* 0x00000000 */
 -7.0312500000e-02, /* 0xbd900000 */
 -8.0816707611e+00, /* 0xc1014e86 */
 -2.5706311035e+02, /* 0xc3808814 */
 -2.4852163086e+03, /* 0xc51b5376 */
 -5.2530439453e+03, /* 0xc5a4285a */
};
static const float pS8[5] = {
  1.1653436279e+02, /* 0x42e91198 */
  3.8337448730e+03, /* 0x456f9beb */
  4.0597855469e+04, /* 0x471e95db */
  1.1675296875e+05, /* 0x47e4087c */
  4.7627726562e+04, /* 0x473a0bba */
};
static const float pR5[6] = { /* for x in [8,4.5454]=1/[0.125,0.22001] */
 -1.1412546255e-11, /* 0xad48c58a */
 -7.0312492549e-02, /* 0xbd8fffff */
 -4.1596107483e+00, /* 0xc0851b88 */
 -6.7674766541e+01, /* 0xc287597b */
 -3.3123129272e+02, /* 0xc3a59d9b */
 -3.4643338013e+02, /* 0xc3ad3779 */
};
static const float pS5[5] = {
  6.0753936768e+01, /* 0x42730408 */
  1.0512523193e+03, /* 0x44836813 */
  5.9789707031e+03, /* 0x45bad7c4 */
  9.6254453125e+03, /* 0x461665c8 */
  2.4060581055e+03, /* 0x451660ee */
};

static const float pR3[6] = {/* for x in [4.547,2.8571]=1/[0.2199,0.35001] */
 -2.5470459075e-09, /* 0xb12f081b */
 -7.0311963558e-02, /* 0xbd8fffb8 */
 -2.4090321064e+00, /* 0xc01a2d95 */
 -2.1965976715e+01, /* 0xc1afba52 */
 -5.8079170227e+01, /* 0xc2685112 */
 -3.1447946548e+01, /* 0xc1fb9565 */
};
static const float pS3[5] = {
  3.5856033325e+01, /* 0x420f6c94 */
  3.6151397705e+02, /* 0x43b4c1ca */
  1.1936077881e+03, /* 0x44953373 */
  1.1279968262e+03, /* 0x448cffe6 */
  1.7358093262e+02, /* 0x432d94b8 */
};

static const float pR2[6] = {/* for x in [2.8570,2]=1/[0.3499,0.5] */
 -8.8753431271e-08, /* 0xb3be98b7 */
 -7.0303097367e-02, /* 0xbd8ffb12 */
 -1.4507384300e+00, /* 0xbfb9b1cc */
 -7.6356959343e+00, /* 0xc0f4579f */
 -1.1193166733e+01, /* 0xc1331736 */
 -3.2336456776e+00, /* 0xc04ef40d */
};
static const float pS2[5] = {
  2.2220300674e+01, /* 0x41b1c32d */
  1.3620678711e+02, /* 0x430834f0 */
  2.7047027588e+02, /* 0x43873c32 */
  1.5387539673e+02, /* 0x4319e01a */
  1.4657617569e+01, /* 0x416a859a */
};

static float pzerof(float x)
{
	const float *p,*q;
	float_t z,r,s;
	uint32_t ix;

	GET_FLOAT_WORD(ix, x);
	ix &= 0x7fffffff;
	if      (ix >= 0x41000000){p = pR8; q = pS8;}
	else if (ix >= 0x409173eb){p = pR5; q = pS5;}
	else if (ix >= 0x4036d917){p = pR3; q = pS3;}
	else /*ix >= 0x40000000*/ {p = pR2; q = pS2;}
	z = 1.0f/(x*x);
	r = p[0]+z*(p[1]+z*(p[2]+z*(p[3]+z*(p[4]+z*p[5]))));
	s = 1.0f+z*(q[0]+z*(q[1]+z*(q[2]+z*(q[3]+z*q[4]))));
	return 1.0f + r/s;
}


/* For x >= 8, the asymptotic expansions of qzero is
 *      -1/8 s + 75/1024 s^3 - ..., where s = 1/x.
 * We approximate pzero by
 *      qzero(x) = s*(-1.25 + (R/S))
 * where  R = qR0 + qR1*s^2 + qR2*s^4 + ... + qR5*s^10
 *        S = 1 + qS0*s^2 + ... + qS5*s^12
 * and
 *      | qzero(x)/s +1.25-R/S | <= 2  ** ( -61.22)
 */
static const float qR8[6] = { /* for x in [inf, 8]=1/[0,0.125] */
  0.0000000000e+00, /* 0x00000000 */
  7.3242187500e-02, /* 0x3d960000 */
  1.1768206596e+01, /* 0x413c4a93 */
  5.5767340088e+02, /* 0x440b6b19 */
  8.8591972656e+03, /* 0x460a6cca */
  3.7014625000e+04, /* 0x471096a0 */
};
static const float qS8[6] = {
  1.6377603149e+02, /* 0x4323c6aa */
  8.0983447266e+03, /* 0x45fd12c2 */
  1.4253829688e+05, /* 0x480b3293 */
  8.0330925000e+05, /* 0x49441ed4 */
  8.4050156250e+05, /* 0x494d3359 */
 -3.4389928125e+05, /* 0xc8a7eb69 */
};

static const float qR5[6] = { /* for x in [8,4.5454]=1/[0.125,0.22001] */
  1.8408595828e-11, /* 0x2da1ec79 */
  7.3242180049e-02, /* 0x3d95ffff */
  5.8356351852e+00, /* 0x40babd86 */
  1.3511157227e+02, /* 0x43071c90 */
  1.0272437744e+03, /* 0x448067cd */
  1.9899779053e+03, /* 0x44f8bf4b */
};
static const float qS5[6] = {
  8.2776611328e+01, /* 0x42a58da0 */
  2.0778142090e+03, /* 0x4501dd07 */
  1.8847289062e+04, /* 0x46933e94 */
  5.6751113281e+04, /* 0x475daf1d */
  3.5976753906e+04, /* 0x470c88c1 */
 -5.3543427734e+03, /* 0xc5a752be */
};

static const float qR3[6] = {/* for x in [4.547,2.8571]=1/[0.2199,0.35001] */
  4.3774099900e-09, /* 0x3196681b */
  7.3241114616e-02, /* 0x3d95ff70 */
  3.3442313671e+00, /* 0x405607e3 */
  4.2621845245e+01, /* 0x422a7cc5 */
  1.7080809021e+02, /* 0x432acedf */
  1.6673394775e+02, /* 0x4326bbe4 */
};
static const float qS3[6] = {
  4.8758872986e+01, /* 0x42430916 */
  7.0968920898e+02, /* 0x44316c1c */
  3.7041481934e+03, /* 0x4567825f */
  6.4604252930e+03, /* 0x45c9e367 */
  2.5163337402e+03, /* 0x451d4557 */
 -1.4924745178e+02, /* 0xc3153f59 */
};

static const float qR2[6] = {/* for x in [2.8570,2]=1/[0.3499,0.5] */
  1.5044444979e-07, /* 0x342189db */
  7.3223426938e-02, /* 0x3d95f62a */
  1.9981917143e+00, /* 0x3fffc4bf */
  1.4495602608e+01, /* 0x4167edfd */
  3.1666231155e+01, /* 0x41fd5471 */
  1.6252708435e+01, /* 0x4182058c */
};
static const float qS2[6] = {
  3.0365585327e+01, /* 0x41f2ecb8 */
  2.6934811401e+02, /* 0x4386ac8f */
  8.4478375244e+02, /* 0x44533229 */
  8.8293585205e+02, /* 0x445cbbe5 */
  2.1266638184e+02, /* 0x4354aa98 */
 -5.3109550476e+00, /* 0xc0a9f358 */
};

static float qzerof(float x)
{
	const float *p,*q;
	float_t s,r,z;
	uint32_t ix;

	GET_FLOAT_WORD(ix, x);
	ix &= 0x7fffffff;
	if      (ix >= 0x41000000){p = qR8; q = qS8;}
	else if (ix >= 0x409173eb){p = qR5; q = qS5;}
	else if (ix >= 0x4036d917){p = qR3; q = qS3;}
	else /*ix >= 0x40000000*/ {p = qR2; q = qS2;}
	z = 1.0f/(x*x);
	r = p[0]+z*(p[1]+z*(p[2]+z*(p[3]+z*(p[4]+z*p[5]))));
	s = 1.0f+z*(q[0]+z*(q[1]+z*(q[2]+z*(q[3]+z*(q[4]+z*q[5])))));
	return (-.125f + r/s)/x;
}
