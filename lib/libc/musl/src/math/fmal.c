/* origin: FreeBSD /usr/src/lib/msun/src/s_fmal.c */
/*-
 * Copyright (c) 2005-2011 David Schultz <das@FreeBSD.ORG>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */


#include "libm.h"
#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double fmal(long double x, long double y, long double z)
{
	return fma(x, y, z);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
#include <fenv.h>
#if LDBL_MANT_DIG == 64
#define LASTBIT(u) (u.i.m & 1)
#define SPLIT (0x1p32L + 1)
#elif LDBL_MANT_DIG == 113
#define LASTBIT(u) (u.i.lo & 1)
#define SPLIT (0x1p57L + 1)
#endif

/*
 * A struct dd represents a floating-point number with twice the precision
 * of a long double.  We maintain the invariant that "hi" stores the high-order
 * bits of the result.
 */
struct dd {
	long double hi;
	long double lo;
};

/*
 * Compute a+b exactly, returning the exact result in a struct dd.  We assume
 * that both a and b are finite, but make no assumptions about their relative
 * magnitudes.
 */
static inline struct dd dd_add(long double a, long double b)
{
	struct dd ret;
	long double s;

	ret.hi = a + b;
	s = ret.hi - a;
	ret.lo = (a - (ret.hi - s)) + (b - s);
	return (ret);
}

/*
 * Compute a+b, with a small tweak:  The least significant bit of the
 * result is adjusted into a sticky bit summarizing all the bits that
 * were lost to rounding.  This adjustment negates the effects of double
 * rounding when the result is added to another number with a higher
 * exponent.  For an explanation of round and sticky bits, see any reference
 * on FPU design, e.g.,
 *
 *     J. Coonen.  An Implementation Guide to a Proposed Standard for
 *     Floating-Point Arithmetic.  Computer, vol. 13, no. 1, Jan 1980.
 */
static inline long double add_adjusted(long double a, long double b)
{
	struct dd sum;
	union ldshape u;

	sum = dd_add(a, b);
	if (sum.lo != 0) {
		u.f = sum.hi;
		if (!LASTBIT(u))
			sum.hi = nextafterl(sum.hi, INFINITY * sum.lo);
	}
	return (sum.hi);
}

/*
 * Compute ldexp(a+b, scale) with a single rounding error. It is assumed
 * that the result will be subnormal, and care is taken to ensure that
 * double rounding does not occur.
 */
static inline long double add_and_denormalize(long double a, long double b, int scale)
{
	struct dd sum;
	int bits_lost;
	union ldshape u;

	sum = dd_add(a, b);

	/*
	 * If we are losing at least two bits of accuracy to denormalization,
	 * then the first lost bit becomes a round bit, and we adjust the
	 * lowest bit of sum.hi to make it a sticky bit summarizing all the
	 * bits in sum.lo. With the sticky bit adjusted, the hardware will
	 * break any ties in the correct direction.
	 *
	 * If we are losing only one bit to denormalization, however, we must
	 * break the ties manually.
	 */
	if (sum.lo != 0) {
		u.f = sum.hi;
		bits_lost = -u.i.se - scale + 1;
		if ((bits_lost != 1) ^ LASTBIT(u))
			sum.hi = nextafterl(sum.hi, INFINITY * sum.lo);
	}
	return scalbnl(sum.hi, scale);
}

/*
 * Compute a*b exactly, returning the exact result in a struct dd.  We assume
 * that both a and b are normalized, so no underflow or overflow will occur.
 * The current rounding mode must be round-to-nearest.
 */
static inline struct dd dd_mul(long double a, long double b)
{
	struct dd ret;
	long double ha, hb, la, lb, p, q;

	p = a * SPLIT;
	ha = a - p;
	ha += p;
	la = a - ha;

	p = b * SPLIT;
	hb = b - p;
	hb += p;
	lb = b - hb;

	p = ha * hb;
	q = ha * lb + la * hb;

	ret.hi = p + q;
	ret.lo = p - ret.hi + q + la * lb;
	return (ret);
}

/*
 * Fused multiply-add: Compute x * y + z with a single rounding error.
 *
 * We use scaling to avoid overflow/underflow, along with the
 * canonical precision-doubling technique adapted from:
 *
 *      Dekker, T.  A Floating-Point Technique for Extending the
 *      Available Precision.  Numer. Math. 18, 224-242 (1971).
 */
long double fmal(long double x, long double y, long double z)
{
	#pragma STDC FENV_ACCESS ON
	long double xs, ys, zs, adj;
	struct dd xy, r;
	int oround;
	int ex, ey, ez;
	int spread;

	/*
	 * Handle special cases. The order of operations and the particular
	 * return values here are crucial in handling special cases involving
	 * infinities, NaNs, overflows, and signed zeroes correctly.
	 */
	if (!isfinite(x) || !isfinite(y))
		return (x * y + z);
	if (!isfinite(z))
		return (z);
	if (x == 0.0 || y == 0.0)
		return (x * y + z);
	if (z == 0.0)
		return (x * y);

	xs = frexpl(x, &ex);
	ys = frexpl(y, &ey);
	zs = frexpl(z, &ez);
	oround = fegetround();
	spread = ex + ey - ez;

	/*
	 * If x * y and z are many orders of magnitude apart, the scaling
	 * will overflow, so we handle these cases specially.  Rounding
	 * modes other than FE_TONEAREST are painful.
	 */
	if (spread < -LDBL_MANT_DIG) {
#ifdef FE_INEXACT
		feraiseexcept(FE_INEXACT);
#endif
#ifdef FE_UNDERFLOW
		if (!isnormal(z))
			feraiseexcept(FE_UNDERFLOW);
#endif
		switch (oround) {
		default: /* FE_TONEAREST */
			return (z);
#ifdef FE_TOWARDZERO
		case FE_TOWARDZERO:
			if (x > 0.0 ^ y < 0.0 ^ z < 0.0)
				return (z);
			else
				return (nextafterl(z, 0));
#endif
#ifdef FE_DOWNWARD
		case FE_DOWNWARD:
			if (x > 0.0 ^ y < 0.0)
				return (z);
			else
				return (nextafterl(z, -INFINITY));
#endif
#ifdef FE_UPWARD
		case FE_UPWARD:
			if (x > 0.0 ^ y < 0.0)
				return (nextafterl(z, INFINITY));
			else
				return (z);
#endif
		}
	}
	if (spread <= LDBL_MANT_DIG * 2)
		zs = scalbnl(zs, -spread);
	else
		zs = copysignl(LDBL_MIN, zs);

	fesetround(FE_TONEAREST);

	/*
	 * Basic approach for round-to-nearest:
	 *
	 *     (xy.hi, xy.lo) = x * y           (exact)
	 *     (r.hi, r.lo)   = xy.hi + z       (exact)
	 *     adj = xy.lo + r.lo               (inexact; low bit is sticky)
	 *     result = r.hi + adj              (correctly rounded)
	 */
	xy = dd_mul(xs, ys);
	r = dd_add(xy.hi, zs);

	spread = ex + ey;

	if (r.hi == 0.0) {
		/*
		 * When the addends cancel to 0, ensure that the result has
		 * the correct sign.
		 */
		fesetround(oround);
		volatile long double vzs = zs; /* XXX gcc CSE bug workaround */
		return xy.hi + vzs + scalbnl(xy.lo, spread);
	}

	if (oround != FE_TONEAREST) {
		/*
		 * There is no need to worry about double rounding in directed
		 * rounding modes.
		 * But underflow may not be raised correctly, example in downward rounding:
		 * fmal(0x1.0000000001p-16000L, 0x1.0000000001p-400L, -0x1p-16440L)
		 */
		long double ret;
#if defined(FE_INEXACT) && defined(FE_UNDERFLOW)
		int e = fetestexcept(FE_INEXACT);
		feclearexcept(FE_INEXACT);
#endif
		fesetround(oround);
		adj = r.lo + xy.lo;
		ret = scalbnl(r.hi + adj, spread);
#if defined(FE_INEXACT) && defined(FE_UNDERFLOW)
		if (ilogbl(ret) < -16382 && fetestexcept(FE_INEXACT))
			feraiseexcept(FE_UNDERFLOW);
		else if (e)
			feraiseexcept(FE_INEXACT);
#endif
		return ret;
	}

	adj = add_adjusted(r.lo, xy.lo);
	if (spread + ilogbl(r.hi) > -16383)
		return scalbnl(r.hi + adj, spread);
	else
		return add_and_denormalize(r.hi, adj, spread);
}
#endif
