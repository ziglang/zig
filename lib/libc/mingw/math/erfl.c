/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*							erfl.c
 *
 *	Error function
 *
 *
 *
 * SYNOPSIS:
 *
 * long double x, y, erfl();
 *
 * y = erfl( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * The integral is
 *
 *                           x 
 *                            -
 *                 2         | |          2
 *   erf(x)  =  --------     |    exp( - t  ) dt.
 *              sqrt(pi)   | |
 *                          -
 *                           0
 *
 * The magnitude of x is limited to about 106.56 for IEEE
 * arithmetic; 1 or -1 is returned outside this range.
 *
 * For 0 <= |x| < 1, erf(x) = x * P6(x^2)/Q6(x^2);
 * Otherwise: erf(x) = 1 - erfc(x).
 *
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    IEEE      0,1         50000       2.0e-19     5.7e-20
 *
 */

/*							erfcl.c
 *
 *	Complementary error function
 *
 *
 *
 * SYNOPSIS:
 *
 * long double x, y, erfcl();
 *
 * y = erfcl( x );
 *
 *
 *
 * DESCRIPTION:
 *
 *
 *  1 - erf(x) =
 *
 *                           inf. 
 *                             -
 *                  2         | |          2
 *   erfc(x)  =  --------     |    exp( - t  ) dt
 *               sqrt(pi)   | |
 *                           -
 *                            x
 *
 *
 * For small x, erfc(x) = 1 - erf(x); otherwise rational
 * approximations are computed.
 *
 * A special function expx2l.c is used to suppress error amplification
 * in computing exp(-x^2).
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    IEEE      0,13        50000      8.4e-19      9.7e-20
 *    IEEE      6,106.56    20000      2.9e-19      7.1e-20
 *
 *
 * ERROR MESSAGES:
 *
 *   message          condition              value returned
 * erfcl underflow    x^2 > MAXLOGL              0.0
 *
 *
 */


/*
Modified from file ndtrl.c
Cephes Math Library Release 2.3:  January, 1995
Copyright 1984, 1995 by Stephen L. Moshier
*/

#include <math.h>
#include "cephes_mconf.h"

long double erfl(long double x);

/* erfc(x) = exp(-x^2) P(1/x)/Q(1/x)
   1/8 <= 1/x <= 1
   Peak relative error 5.8e-21  */

static const uLD P[10] = {
  { { 0x4bf0,0x9ad8,0x7a03,0x86c7,0x401d, 0, 0, 0 } },
  { { 0xdf23,0xd843,0x4032,0x8881,0x401e, 0, 0, 0 } },
  { { 0xd025,0xcfd5,0x8494,0x88d3,0x401e, 0, 0, 0 } },
  { { 0xb6d0,0xc92b,0x5417,0xacb1,0x401d, 0, 0, 0 } },
  { { 0xada8,0x356a,0x4982,0x94a6,0x401c, 0, 0, 0 } },
  { { 0x4e13,0xcaee,0x9e31,0xb258,0x401a, 0, 0, 0 } },
  { { 0x5840,0x554d,0x37a3,0x9239,0x4018, 0, 0, 0 } },
  { { 0x3b58,0x3da2,0xaf02,0x9780,0x4015, 0, 0, 0 } },
  { { 0x0144,0x489e,0xbe68,0x9c31,0x4011, 0, 0, 0 } },
  { { 0x333b,0xd9e6,0xd404,0x986f,0xbfee, 0, 0, 0 } }
};
static const uLD Q[] = {
  { { 0x0e43,0x302d,0x79ed,0x86c7,0x401d, 0, 0, 0 } },
  { { 0xf817,0x9128,0xc0f8,0xd48b,0x401e, 0, 0, 0 } },
  { { 0x8eae,0x8dad,0x6eb4,0x9aa2,0x401f, 0, 0, 0 } },
  { { 0x00e7,0x7595,0xcd06,0x88bb,0x401f, 0, 0, 0 } },
  { { 0x4991,0xcfda,0x52f1,0xa2a9,0x401e, 0, 0, 0 } },
  { { 0xc39d,0xe415,0xc43d,0x87c0,0x401d, 0, 0, 0 } },
  { { 0xa75d,0x436f,0x30dd,0xa027,0x401b, 0, 0, 0 } },
  { { 0xc4cb,0x305a,0xbf78,0x8220,0x4019, 0, 0, 0 } },
  { { 0x3708,0x33b1,0x07fa,0x8644,0x4016, 0, 0, 0 } },
  { { 0x24fa,0x96f6,0x7153,0x8a6c,0x4012, 0, 0, 0 } }
};

/* erfc(x) = exp(-x^2) 1/x R(1/x^2) / S(1/x^2)
   1/128 <= 1/x < 1/8
   Peak relative error 1.9e-21  */

static const uLD R[] = {
  { { 0x260a,0xab95,0x2fc7,0xe7c4,0x4000, 0, 0, 0 } },
  { { 0x4761,0x613e,0xdf6d,0xe58e,0x4001, 0, 0, 0 } },
  { { 0x0615,0x4b00,0x575f,0xdc7b,0x4000, 0, 0, 0 } },
  { { 0x521d,0x8527,0x3435,0x8dc2,0x3ffe, 0, 0, 0 } },
  { { 0x22cf,0xc711,0x6c5b,0xdcfb,0x3ff9, 0, 0, 0 } }
};
static const uLD S[] = {
  { { 0x5de6,0x17d7,0x54d6,0xaba9,0x4002, 0, 0, 0 } },
  { { 0x55d5,0xd300,0xe71e,0xf564,0x4002, 0, 0, 0 } },
  { { 0xb611,0x8f76,0xf020,0xd255,0x4001, 0, 0, 0 } },
  { { 0x3684,0x3798,0xb793,0x80b0,0x3fff, 0, 0, 0 } },
  { { 0xf5af,0x2fb2,0x1e57,0xc3d7,0x3ffa, 0, 0, 0 } }
};

/* erf(x)  = x T(x^2)/U(x^2)
   0 <= x <= 1
   Peak relative error 7.6e-23  */

static const uLD T[] = {
  { { 0xfd7a,0x3a1a,0x705b,0xe0c4,0x3ffb, 0, 0, 0 } },
  { { 0x3128,0xc337,0x3716,0xace5,0x4001, 0, 0, 0 } },
  { { 0x9517,0x4e93,0x540e,0x8f97,0x4007, 0, 0, 0 } },
  { { 0x6118,0x6059,0x9093,0xa757,0x400a, 0, 0, 0 } },
  { { 0xb954,0xa987,0xc60c,0xbc83,0x400e, 0, 0, 0 } },
  { { 0x7a56,0xe45a,0xa4bd,0x975b,0x4010, 0, 0, 0 } },
  { { 0xc446,0x6bab,0x0b2a,0x86d0,0x4013, 0, 0, 0 } }
};

static const uLD U[] = {
  { { 0x3453,0x1f8e,0xf688,0xb507,0x4004, 0, 0, 0 } },
  { { 0x71ac,0xb12f,0x21ca,0xf2e2,0x4008, 0, 0, 0 } },
  { { 0xffe8,0x9cac,0x3b84,0xc2ac,0x400c, 0, 0, 0 } },
  { { 0x481d,0x445b,0xc807,0xc232,0x400f, 0, 0, 0 } },
  { { 0x9ad5,0x1aef,0x45b1,0xe25e,0x4011, 0, 0, 0 } },
  { { 0x71a7,0x1cad,0x012e,0xeef3,0x4012, 0, 0, 0 } }
};

/*							expx2l.c
 *
 *	Exponential of squared argument
 *
 *
 *
 * SYNOPSIS:
 *
 * long double x, y, expmx2l();
 * int sign;
 *
 * y = expx2l( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Computes y = exp(x*x) while suppressing error amplification
 * that would ordinarily arise from the inexactness of the
 * exponential argument x*x.
 *
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic      domain        # trials      peak         rms
 *   IEEE     -106.566, 106.566    10^5       1.6e-19     4.4e-20
 *
 */

#define M 32768.0L
#define MINV 3.0517578125e-5L

static long double expx2l (long double x)
{
	long double u, u1, m, f;

	x = fabsl (x);
	/* Represent x as an exact multiple of M plus a residual.
	   M is a power of 2 chosen so that exp(m * m) does not overflow
	   or underflow and so that |x - m| is small.  */
	m = MINV * floorl(M * x + 0.5L);
	f = x - m;

	/* x^2 = m^2 + 2mf + f^2 */
	u = m * m;
	u1 = 2 * m * f  +  f * f;

	if ((u + u1) > MAXLOGL)
		return (INFINITYL);

	/* u is exact, u1 is small.  */
	u = expl(u) * expl(u1);
	return (u);
}

long double erfcl(long double a)
{
	long double p, q, x, y, z;

	if (isinf (a))
		return (signbit(a) ? 2.0 : 0.0);

	x = fabsl (a);

	if (x < 1.0L)
		return (1.0L - erfl(a));

	z = a * a;

	if (z  > MAXLOGL)
	{
under:
		mtherr("erfcl", UNDERFLOW);
		errno = ERANGE;
		return (signbit(a) ? 2.0 : 0.0);
	}

	/* Compute z = expl(a * a).  */
	z = expx2l(a);
	y = 1.0L/x;

	if (x < 8.0L)
	{
		p = polevll(y, P, 9);
		q = p1evll(y, Q, 10);
	}
	else
	{
		q = y * y;
		p = y * polevll(q, R, 4);
		q = p1evll(q, S, 5);
	}
	y = p/(q * z);

	if (a < 0.0L)
		y = 2.0L - y;

	if (y == 0.0L)
		goto under;

	return (y);
}

long double erfl(long double x)
{
	long double y, z;

	if (x == 0.0L)
		return (x);

	if (isinf (x))
		return (signbit(x) ?  -1.0L : 1.0L);

	if (fabsl(x) > 1.0L)
		return (1.0L - erfcl(x));

	z = x * x;
	y = x * polevll(z, T, 6) / p1evll(z, U, 6);
	return (y);
}
