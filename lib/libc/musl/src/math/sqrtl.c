#include <stdint.h>
#include <math.h>
#include <float.h>
#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double sqrtl(long double x)
{
	return sqrt(x);
}
#elif (LDBL_MANT_DIG == 113 || LDBL_MANT_DIG == 64) && LDBL_MAX_EXP == 16384
#include "sqrt_data.h"

#define FENV_SUPPORT 1

typedef struct {
	uint64_t hi;
	uint64_t lo;
} u128;

/* top: 16 bit sign+exponent, x: significand.  */
static inline long double mkldbl(uint64_t top, u128 x)
{
	union ldshape u;
#if LDBL_MANT_DIG == 113
	u.i2.hi = x.hi;
	u.i2.lo = x.lo;
	u.i2.hi &= 0x0000ffffffffffff;
	u.i2.hi |= top << 48;
#elif LDBL_MANT_DIG == 64
	u.i.se = top;
	u.i.m = x.lo;
	/* force the top bit on non-zero (and non-subnormal) results.  */
	if (top & 0x7fff)
		u.i.m |= 0x8000000000000000;
#endif
	return u.f;
}

/* return: top 16 bit is sign+exp and following bits are the significand.  */
static inline u128 asu128(long double x)
{
	union ldshape u = {.f=x};
	u128 r;
#if LDBL_MANT_DIG == 113
	r.hi = u.i2.hi;
	r.lo = u.i2.lo;
#elif LDBL_MANT_DIG == 64
	r.lo = u.i.m<<49;
	/* ignore the top bit: pseudo numbers are not handled. */
	r.hi = u.i.m>>15;
	r.hi &= 0x0000ffffffffffff;
	r.hi |= (uint64_t)u.i.se << 48;
#endif
	return r;
}

/* returns a*b*2^-32 - e, with error 0 <= e < 1.  */
static inline uint32_t mul32(uint32_t a, uint32_t b)
{
	return (uint64_t)a*b >> 32;
}

/* returns a*b*2^-64 - e, with error 0 <= e < 3.  */
static inline uint64_t mul64(uint64_t a, uint64_t b)
{
	uint64_t ahi = a>>32;
	uint64_t alo = a&0xffffffff;
	uint64_t bhi = b>>32;
	uint64_t blo = b&0xffffffff;
	return ahi*bhi + (ahi*blo >> 32) + (alo*bhi >> 32);
}

static inline u128 add64(u128 a, uint64_t b)
{
	u128 r;
	r.lo = a.lo + b;
	r.hi = a.hi;
	if (r.lo < a.lo)
		r.hi++;
	return r;
}

static inline u128 add128(u128 a, u128 b)
{
	u128 r;
	r.lo = a.lo + b.lo;
	r.hi = a.hi + b.hi;
	if (r.lo < a.lo)
		r.hi++;
	return r;
}

static inline u128 sub64(u128 a, uint64_t b)
{
	u128 r;
	r.lo = a.lo - b;
	r.hi = a.hi;
	if (a.lo < b)
		r.hi--;
	return r;
}

static inline u128 sub128(u128 a, u128 b)
{
	u128 r;
	r.lo = a.lo - b.lo;
	r.hi = a.hi - b.hi;
	if (a.lo < b.lo)
		r.hi--;
	return r;
}

/* a<<n, 0 <= n <= 127 */
static inline u128 lsh(u128 a, int n)
{
	if (n == 0)
		return a;
	if (n >= 64) {
		a.hi = a.lo<<(n-64);
		a.lo = 0;
	} else {
		a.hi = (a.hi<<n) | (a.lo>>(64-n));
		a.lo = a.lo<<n;
	}
	return a;
}

/* a>>n, 0 <= n <= 127 */
static inline u128 rsh(u128 a, int n)
{
	if (n == 0)
		return a;
	if (n >= 64) {
		a.lo = a.hi>>(n-64);
		a.hi = 0;
	} else {
		a.lo = (a.lo>>n) | (a.hi<<(64-n));
		a.hi = a.hi>>n;
	}
	return a;
}

/* returns a*b exactly.  */
static inline u128 mul64_128(uint64_t a, uint64_t b)
{
	u128 r;
	uint64_t ahi = a>>32;
	uint64_t alo = a&0xffffffff;
	uint64_t bhi = b>>32;
	uint64_t blo = b&0xffffffff;
	uint64_t lo1 = ((ahi*blo)&0xffffffff) + ((alo*bhi)&0xffffffff) + (alo*blo>>32);
	uint64_t lo2 = (alo*blo)&0xffffffff;
	r.hi = ahi*bhi + (ahi*blo>>32) + (alo*bhi>>32) + (lo1>>32);
	r.lo = (lo1<<32) + lo2;
	return r;
}

/* returns a*b*2^-128 - e, with error 0 <= e < 7.  */
static inline u128 mul128(u128 a, u128 b)
{
	u128 hi = mul64_128(a.hi, b.hi);
	uint64_t m1 = mul64(a.hi, b.lo);
	uint64_t m2 = mul64(a.lo, b.hi);
	return add64(add64(hi, m1), m2);
}

/* returns a*b % 2^128.  */
static inline u128 mul128_tail(u128 a, u128 b)
{
	u128 lo = mul64_128(a.lo, b.lo);
	lo.hi += a.hi*b.lo + a.lo*b.hi;
	return lo;
}


/* see sqrt.c for detailed comments.  */

long double sqrtl(long double x)
{
	u128 ix, ml;
	uint64_t top;

	ix = asu128(x);
	top = ix.hi >> 48;
	if (predict_false(top - 0x0001 >= 0x7fff - 0x0001)) {
		/* x < 0x1p-16382 or inf or nan.  */
		if (2*ix.hi == 0 && ix.lo == 0)
			return x;
		if (ix.hi == 0x7fff000000000000 && ix.lo == 0)
			return x;
		if (top >= 0x7fff)
			return __math_invalidl(x);
		/* x is subnormal, normalize it.  */
		ix = asu128(x * 0x1p112);
		top = ix.hi >> 48;
		top -= 112;
	}

	/* x = 4^e m; with int e and m in [1, 4) */
	int even = top & 1;
	ml = lsh(ix, 15);
	ml.hi |= 0x8000000000000000;
	if (even) ml = rsh(ml, 1);
	top = (top + 0x3fff) >> 1;

	/* r ~ 1/sqrt(m) */
	static const uint64_t three = 0xc0000000;
	uint64_t r, s, d, u, i;
	i = (ix.hi >> 42) % 128;
	r = (uint32_t)__rsqrt_tab[i] << 16;
	/* |r sqrt(m) - 1| < 0x1p-8 */
	s = mul32(ml.hi>>32, r);
	d = mul32(s, r);
	u = three - d;
	r = mul32(u, r) << 1;
	/* |r sqrt(m) - 1| < 0x1.7bp-16, switch to 64bit */
	r = r<<32;
	s = mul64(ml.hi, r);
	d = mul64(s, r);
	u = (three<<32) - d;
	r = mul64(u, r) << 1;
	/* |r sqrt(m) - 1| < 0x1.a5p-31 */
	s = mul64(u, s) << 1;
	d = mul64(s, r);
	u = (three<<32) - d;
	r = mul64(u, r) << 1;
	/* |r sqrt(m) - 1| < 0x1.c001p-59, switch to 128bit */

	static const u128 threel = {.hi=three<<32, .lo=0};
	u128 rl, sl, dl, ul;
	rl.hi = r;
	rl.lo = 0;
	sl = mul128(ml, rl);
	dl = mul128(sl, rl);
	ul = sub128(threel, dl);
	sl = mul128(ul, sl); /* repr: 3.125 */
	/* -0x1p-116 < s - sqrt(m) < 0x3.8001p-125 */
	sl = rsh(sub64(sl, 4), 125-(LDBL_MANT_DIG-1));
	/* s < sqrt(m) < s + 1 ULP + tiny */

	long double y;
	u128 d2, d1, d0;
	d0 = sub128(lsh(ml, 2*(LDBL_MANT_DIG-1)-126), mul128_tail(sl,sl));
	d1 = sub128(sl, d0);
	d2 = add128(add64(sl, 1), d1);
	sl = add64(sl, d1.hi >> 63);
	y = mkldbl(top, sl);
	if (FENV_SUPPORT) {
		/* handle rounding modes and inexact exception.  */
		top = predict_false((d2.hi|d2.lo)==0) ? 0 : 1;
		top |= ((d1.hi^d2.hi)&0x8000000000000000) >> 48;
		y += mkldbl(top, (u128){0});
	}
	return y;
}
#else
#error unsupported long double format
#endif
