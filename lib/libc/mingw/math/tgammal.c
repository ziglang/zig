/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"

/*
gamma(x+2)  = gamma(x+2) P(x)/Q(x)
0 <= x <= 1
Relative error
n=7, d=8
Peak error =  1.83e-20
Relative error spread =  8.4e-23
*/

#if UNK
static const uLD P[8] = {
  { { 4.212760487471622013093E-5L } },
  { { 4.542931960608009155600E-4L } },
  { { 4.092666828394035500949E-3L } },
  { { 2.385363243461108252554E-2L } },
  { { 1.113062816019361559013E-1L } },
  { { 3.629515436640239168939E-1L } },
  { { 8.378004301573126728826E-1L } },
  { { 1.000000000000000000009E0L } }
};
static const uLD Q[9] = {
  { { -1.397148517476170440917E-5L } },
  { { 2.346584059160635244282E-4L } },
  { { -1.237799246653152231188E-3L } },
  { { -7.955933682494738320586E-4L } },
  { { 2.773706565840072979165E-2L } },
  { { -4.633887671244534213831E-2L } },
  { { -2.243510905670329164562E-1L } },
  { { 4.150160950588455434583E-1L } },
  { { 9.999999999999999999908E-1L } }
};
#endif
#if IBMPC
static const uLD P[8] = {
  { { 0x434a,0x3f22,0x2bda,0xb0b2,0x3ff0, 0x0, 0x0, 0x0 } },
  { { 0xf5aa,0xe82f,0x335b,0xee2e,0x3ff3, 0x0, 0x0, 0x0 } },
  { { 0xbe6c,0x3757,0xc717,0x861b,0x3ff7, 0x0, 0x0, 0x0 } },
  { { 0x7f43,0x5196,0xb166,0xc368,0x3ff9, 0x0, 0x0, 0x0 } },
  { { 0x9549,0x8eb5,0x8c3a,0xe3f4,0x3ffb, 0x0, 0x0, 0x0 } },
  { { 0x8d75,0x23af,0xc8e4,0xb9d4,0x3ffd, 0x0, 0x0, 0x0 } },
  { { 0x29cf,0x19b3,0x16c8,0xd67a,0x3ffe, 0x0, 0x0, 0x0 } },
  { { 0x0000,0x0000,0x0000,0x8000,0x3fff, 0x0, 0x0, 0x0 } }
};
static const uLD Q[9] = {
  { { 0x5473,0x2de8,0x1268,0xea67,0xbfee, 0x0, 0x0, 0x0 } },
  { { 0x334b,0xc2f0,0xa2dd,0xf60e,0x3ff2, 0x0, 0x0, 0x0 } },
  { { 0xbeed,0x1853,0xa691,0xa23d,0xbff5, 0x0, 0x0, 0x0 } },
  { { 0x296e,0x7cb1,0x5dfd,0xd08f,0xbff4, 0x0, 0x0, 0x0 } },
  { { 0x0417,0x7989,0xd7bc,0xe338,0x3ff9, 0x0, 0x0, 0x0 } },
  { { 0x3295,0x3698,0xd580,0xbdcd,0xbffa, 0x0, 0x0, 0x0 } },
  { { 0x75ef,0x3ab7,0x4ad3,0xe5bc,0xbffc, 0x0, 0x0, 0x0 } },
  { { 0xe458,0x2ec7,0xfd57,0xd47c,0x3ffd, 0x0, 0x0, 0x0 } },
  { { 0x0000,0x0000,0x0000,0x8000,0x3fff, 0x0, 0x0, 0x0 } }
};
#endif
#if MIEEE
static const uLD P[8] = {
  { { 0x3ff00000,0xb0b22bda,0x3f22434a, 0 } },
  { { 0x3ff30000,0xee2e335b,0xe82ff5aa, 0 } },
  { { 0x3ff70000,0x861bc717,0x3757be6c, 0 } },
  { { 0x3ff90000,0xc368b166,0x51967f43, 0 } },
  { { 0x3ffb0000,0xe3f48c3a,0x8eb59549, 0 } },
  { { 0x3ffd0000,0xb9d4c8e4,0x23af8d75, 0 } },
  { { 0x3ffe0000,0xd67a16c8,0x19b329cf, 0 } },
  { { 0x3fff0000,0x80000000,0x00000000, 0 } }
};
static const uLD Q[9] = {
  { { 0xbfee0000,0xea671268,0x2de85473, 0 } },
  { { 0x3ff20000,0xf60ea2dd,0xc2f0334b, 0 } },
  { { 0xbff50000,0xa23da691,0x1853beed, 0 } },
  { { 0xbff40000,0xd08f5dfd,0x7cb1296e, 0 } },
  { { 0x3ff90000,0xe338d7bc,0x79890417, 0 } },
  { { 0xbffa0000,0xbdcdd580,0x36983295, 0 } },
  { { 0xbffc0000,0xe5bc4ad3,0x3ab775ef, 0 } },
  { { 0x3ffd0000,0xd47cfd57,0x2ec7e458, 0 } },
  { { 0x3fff0000,0x80000000,0x00000000, 0 } }
};
#endif

#define MAXGAML 1755.455L
/*static const long double LOGPI = 1.14472988584940017414L;*/

/* Stirling's formula for the gamma function
gamma(x) = sqrt(2 pi) x^(x-.5) exp(-x) (1 + 1/x P(1/x))
z(x) = x
13 <= x <= 1024
Relative error
n=8, d=0
Peak error =  9.44e-21
Relative error spread =  8.8e-4
*/
#if UNK
static const uLD STIR[9] = {
  { { 7.147391378143610789273E-4L } },
  { { -2.363848809501759061727E-5L } },
  { { -5.950237554056330156018E-4L } },
  { { 6.989332260623193171870E-5L } },
  { { 7.840334842744753003862E-4L } },
  { { -2.294719747873185405699E-4L } },
  { { -2.681327161876304418288E-3L } },
  { { 3.472222222230075327854E-3L } },
  { { 8.333333333333331800504E-2L } }
};
#endif
#if IBMPC
static const uLD STIR[9] = {
  { { 0x6ede,0x69f7,0x54e3,0xbb5d,0x3ff4, 0, 0, 0 } },
  { { 0xc395,0x0295,0x4443,0xc64b,0xbfef, 0, 0, 0 } },
  { { 0xba6f,0x7c59,0x5e47,0x9bfb,0xbff4, 0, 0, 0 } },
  { { 0x5704,0x1a39,0xb11d,0x9293,0x3ff1, 0, 0, 0 } },
  { { 0x30b7,0x1a21,0x98b2,0xcd87,0x3ff4, 0, 0, 0 } },
  { { 0xbef3,0x7023,0x6a08,0xf09e,0xbff2, 0, 0, 0 } },
  { { 0x3a1c,0x5ac8,0x3478,0xafb9,0xbff6, 0, 0, 0 } },
  { { 0xc3c9,0x906e,0x38e3,0xe38e,0x3ff6, 0, 0, 0 } },
  { { 0xa1d5,0xaaaa,0xaaaa,0xaaaa,0x3ffb, 0, 0, 0 } }
};
#endif
#if MIEEE
static const uLD STIR[9] = {
  { { 0x3ff40000,0xbb5d54e3,0x69f76ede, 0 } },
  { { 0xbfef0000,0xc64b4443,0x0295c395, 0 } },
  { { 0xbff40000,0x9bfb5e47,0x7c59ba6f, 0 } },
  { { 0x3ff10000,0x9293b11d,0x1a395704, 0 } },
  { { 0x3ff40000,0xcd8798b2,0x1a2130b7, 0 } },
  { { 0xbff20000,0xf09e6a08,0x7023bef3, 0 } },
  { { 0xbff60000,0xafb93478,0x5ac83a1c, 0 } },
  { { 0x3ff60000,0xe38e38e3,0x906ec3c9, 0 } },
  { { 0x3ffb0000,0xaaaaaaaa,0xaaaaa1d5, 0 } }
};
#endif
#define MAXSTIR 1024.0L
static const long double SQTPI = 2.50662827463100050242E0L;

/* 1/gamma(x) = z P(z)
 * z(x) = 1/x
 * 0 < x < 0.03125
 * Peak relative error 4.2e-23
 */
#if UNK
static const uLD S[9] = {
  { { -1.193945051381510095614E-3L } },
  { { 7.220599478036909672331E-3L } },
  { { -9.622023360406271645744E-3L } },
  { { -4.219773360705915470089E-2L } },
  { { 1.665386113720805206758E-1L } },
  { { -4.200263503403344054473E-2L } },
  { { -6.558780715202540684668E-1L } },
  { { 5.772156649015328608253E-1L } },
  { { 1.000000000000000000000E0L } }
};
#endif
#if IBMPC
static const uLD S[9] = {
  { { 0xbaeb,0xd6d3,0x25e5,0x9c7e,0xbff5, 0, 0, 0 } },
  { { 0xfe9a,0xceb4,0xc74e,0xec9a,0x3ff7, 0, 0, 0 } },
  { { 0x9225,0xdfef,0xb0e9,0x9da5,0xbff8, 0, 0, 0 } },
  { { 0x10b0,0xec17,0x87dc,0xacd7,0xbffa, 0, 0, 0 } },
  { { 0x6b8d,0x7515,0x1905,0xaa89,0x3ffc, 0, 0, 0 } },
  { { 0xf183,0x126b,0xf47d,0xac0a,0xbffa, 0, 0, 0 } },
  { { 0x7bf6,0x57d1,0xa013,0xa7e7,0xbffe, 0, 0, 0 } },
  { { 0xc7a9,0x7db0,0x67e3,0x93c4,0x3ffe, 0, 0, 0 } },
  { { 0x0000,0x0000,0x0000,0x8000,0x3fff, 0, 0, 0 } }
};
#endif
#if MIEEE
static const long S[9] = {
  { { 0xbff50000,0x9c7e25e5,0xd6d3baeb, 0 } },
  { { 0x3ff70000,0xec9ac74e,0xceb4fe9a, 0 } },
  { { 0xbff80000,0x9da5b0e9,0xdfef9225, 0 } },
  { { 0xbffa0000,0xacd787dc,0xec1710b0, 0 } },
  { { 0x3ffc0000,0xaa891905,0x75156b8d, 0 } },
  { { 0xbffa0000,0xac0af47d,0x126bf183, 0 } },
  { { 0xbffe0000,0xa7e7a013,0x57d17bf6, 0 } },
  { { 0x3ffe0000,0x93c467e3,0x7db0c7a9, 0 } },
  { { 0x3fff0000,0x80000000,0x00000000, 0 } }
};
#endif
/* 1/gamma(-x) = z P(z)
 * z(x) = 1/x
 * 0 < x < 0.03125
 * Peak relative error 5.16e-23
 * Relative error spread =  2.5e-24
 */
#if UNK
static const uLD SN[9] = {
  { { 1.133374167243894382010E-3L } },
  { { 7.220837261893170325704E-3L } },
  { { 9.621911155035976733706E-3L } },
  { { -4.219773343731191721664E-2L } },
  { { -1.665386113944413519335E-1L } },
  { { -4.200263503402112910504E-2L } },
  { { 6.558780715202536547116E-1L } },
  { { 5.772156649015328608727E-1L } },
  { { -1.000000000000000000000E0L } }
};
#endif
#if IBMPC
static const uLD SN[9] = {
  { { 0x5dd1,0x02de,0xb9f7,0x948d,0x3ff5, 0, 0, 0 } },
  { { 0x989b,0xdd68,0xc5f1,0xec9c,0x3ff7, 0, 0, 0 } },
  { { 0x2ca1,0x18f0,0x386f,0x9da5,0x3ff8, 0, 0, 0 } },
  { { 0x783f,0x41dd,0x87d1,0xacd7,0xbffa, 0, 0, 0 } },
  { { 0x7a5b,0xd76d,0x1905,0xaa89,0xbffc, 0, 0, 0 } },
  { { 0x7f64,0x1234,0xf47d,0xac0a,0xbffa, 0, 0, 0 } },
  { { 0x5e26,0x57d1,0xa013,0xa7e7,0x3ffe, 0, 0, 0 } },
  { { 0xc7aa,0x7db0,0x67e3,0x93c4,0x3ffe, 0, 0, 0 } },
  { { 0x0000,0x0000,0x0000,0x8000,0xbfff, 0, 0, 0 } }
};
#endif
#if MIEEE
static const uLD SN[9] = {
  { { 0x3ff50000,0x948db9f7,0x02de5dd1, 0 } },
  { { 0x3ff70000,0xec9cc5f1,0xdd68989b, 0 } },
  { { 0x3ff80000,0x9da5386f,0x18f02ca1, 0 } },
  { { 0xbffa0000,0xacd787d1,0x41dd783f, 0 } },
  { { 0xbffc0000,0xaa891905,0xd76d7a5b, 0 } },
  { { 0xbffa0000,0xac0af47d,0x12347f64, 0 } },
  { { 0x3ffe0000,0xa7e7a013,0x57d15e26, 0 } },
  { { 0x3ffe0000,0x93c467e3,0x7db0c7aa, 0 } },
  { { 0xbfff0000,0x80000000,0x00000000, 0 } }
};
#endif

static long double stirf (long double);

/* Gamma function computed by Stirling's formula.  */

static long double stirf(long double x)
{
	long double y, w, v;

	w = 1.0L/x;
	/* For large x, use rational coefficients from the analytical expansion.  */
	if (x > 1024.0L)
		w = (((((6.97281375836585777429E-5L * w
		      + 7.84039221720066627474E-4L) * w
		      - 2.29472093621399176955E-4L) * w
		      - 2.68132716049382716049E-3L) * w
		      + 3.47222222222222222222E-3L) * w
		      + 8.33333333333333333333E-2L) * w
		      + 1.0L;
	else
		w = 1.0L + w * polevll( w, STIR, 8 );
	y = expl(x);
	if (x > MAXSTIR)
	{ /* Avoid overflow in pow() */
		v = powl(x, 0.5L * x - 0.25L);
		y = v * (v / y);
	}
	else
	{
		y = powl(x, x - 0.5L) / y;
	}
	y = SQTPI * y * w;
	return (y);
}

long double __tgammal_r(long double, int *);

long double __tgammal_r(long double x, int* sgngaml)
{
	long double p, q, z;
	int i;

	*sgngaml = 1;
#ifdef NANS
	if (isnanl(x))
		return (NANL);
#endif
#ifdef INFINITIES
#ifdef NANS
	if (x == INFINITYL)
		return (x);
	if (x == -INFINITYL)
		return (NANL);
#else
	if (!isfinite(x))
		return (x);
#endif
#endif
	q = fabsl(x);

	if (q > 13.0L)
	{
		if (q > MAXGAML)
			goto goverf;
		if (x < 0.0L)
		{
			p = floorl(q);
			if (p == q)
			{
gsing:
				_SET_ERRNO(EDOM);
				mtherr("tgammal", SING);
#ifdef INFINITIES
				return (INFINITYL);
#else
				return (*sgngaml * MAXNUML);
#endif
			}
			i = p;
			if ((i & 1) == 0)
				*sgngaml = -1;
			z = q - p;
			if (z > 0.5L)
			{
				p += 1.0L;
				z = q - p;
			}
			z = q * sinl(PIL * z);
			z = fabsl(z) * stirf(q);
			if (z <= PIL/MAXNUML)
			{
goverf:
				_SET_ERRNO(ERANGE);
				mtherr("tgammal", OVERFLOW);
#ifdef INFINITIES
				return(*sgngaml * INFINITYL);
#else
				return(*sgngaml * MAXNUML);
#endif
			}
			z = PIL/z;
		}
		else
		{
			z = stirf(x);
		}
		return (*sgngaml * z);
	}

	z = 1.0L;
	while (x >= 3.0L)
	{
		x -= 1.0L;
		z *= x;
	}

	while (x < -0.03125L)
	{
		z /= x;
		x += 1.0L;
	}

	if (x <= 0.03125L)
		goto Small;

	while (x < 2.0L)
	{
		z /= x;
		x += 1.0L;
	}

	if (x == 2.0L)
		return (z);

	x -= 2.0L;
	p = polevll( x, P, 7 );
	q = polevll( x, Q, 8 );
	return (z * p / q);

Small:
	if (x == 0.0L)
	{
		goto gsing;
	}
	else
	{
		if (x < 0.0L)
		{
			x = -x;
			q = z / (x * polevll(x, SN, 8));
		}
		else
			q = z / (x * polevll(x, S, 8));
	}
	return q;
}

/* This is the C99 version. */
long double tgammal(long double x)
{
	int local_sgngaml = 0;
	return (__tgammal_r(x, &local_sgngaml));
}

