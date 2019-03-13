/* origin: FreeBSD /usr/src/lib/msun/src/s_csinhf.c */
/*-
 * Copyright (c) 2005 Bruce D. Evans and Steven G. Kargl
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/*
 * Hyperbolic sine of a complex argument z.  See s_csinh.c for details.
 */

#include "libm.h"

static const float huge = 0x1p127;

float complex csinhf(float complex z)
{
	float x, y, h;
	int32_t hx, hy, ix, iy;

	x = crealf(z);
	y = cimagf(z);

	GET_FLOAT_WORD(hx, x);
	GET_FLOAT_WORD(hy, y);

	ix = 0x7fffffff & hx;
	iy = 0x7fffffff & hy;

	if (ix < 0x7f800000 && iy < 0x7f800000) {
		if (iy == 0)
			return CMPLXF(sinhf(x), y);
		if (ix < 0x41100000)    /* small x: normal case */
			return CMPLXF(sinhf(x) * cosf(y), coshf(x) * sinf(y));

		/* |x| >= 9, so cosh(x) ~= exp(|x|) */
		if (ix < 0x42b17218) {
			/* x < 88.7: expf(|x|) won't overflow */
			h = expf(fabsf(x)) * 0.5f;
			return CMPLXF(copysignf(h, x) * cosf(y), h * sinf(y));
		} else if (ix < 0x4340b1e7) {
			/* x < 192.7: scale to avoid overflow */
			z = __ldexp_cexpf(CMPLXF(fabsf(x), y), -1);
			return CMPLXF(crealf(z) * copysignf(1, x), cimagf(z));
		} else {
			/* x >= 192.7: the result always overflows */
			h = huge * x;
			return CMPLXF(h * cosf(y), h * h * sinf(y));
		}
	}

	if (ix == 0 && iy >= 0x7f800000)
		return CMPLXF(copysignf(0, x * (y - y)), y - y);

	if (iy == 0 && ix >= 0x7f800000) {
		if ((hx & 0x7fffff) == 0)
			return CMPLXF(x, y);
		return CMPLXF(x, copysignf(0, y));
	}

	if (ix < 0x7f800000 && iy >= 0x7f800000)
		return CMPLXF(y - y, x * (y - y));

	if (ix >= 0x7f800000 && (hx & 0x7fffff) == 0) {
		if (iy >= 0x7f800000)
			return CMPLXF(x * x, x * (y - y));
		return CMPLXF(x * cosf(y), INFINITY * sinf(y));
	}

	return CMPLXF((x * x) * (y - y), (x + x) * (y - y));
}
