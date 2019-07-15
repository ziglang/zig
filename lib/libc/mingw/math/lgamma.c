/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"

/* A[]: Stirling's formula expansion of log gamma
 * B[], C[]: log gamma function between 2 and 3
 */
#ifdef UNK
static uD A[] = {
  { {  8.11614167470508450300E-4 } },
  { { -5.95061904284301438324E-4 } },
  { {  7.93650340457716943945E-4 } },
  { { -2.77777777730099687205E-3 } },
  { {  8.33333333333331927722E-2 } }
};
static uD B[] = {
  { { -1.37825152569120859100E3 } },
  { { -3.88016315134637840924E4 } },
  { { -3.31612992738871184744E5 } },
  { { -1.16237097492762307383E6 } },
  { { -1.72173700820839662146E6 } },
  { { -8.53555664245765465627E5 } }
};
static uD C[] = {
  { { -3.51815701436523470549E2 } },
  { { -1.70642106651881159223E4 } },
  { { -2.20528590553854454839E5 } },
  { { -1.13933444367982507207E6 } },
  { { -2.53252307177582951285E6 } },
  { { -2.01889141433532773231E6 } }
};
/* log( sqrt( 2*pi ) ) */
static double LS2PI  =  0.91893853320467274178;
#define MAXLGM 2.556348e305
static double LOGPI = 1.14472988584940017414;
#endif

#ifdef DEC
static const uD A[] = {
  { { 0035524,0141201,0034633,0031405 } },
  { { 0135433,0176755,0126007,0045030 } },
  { { 0035520,0006371,0003342,0172730 } },
  { { 0136066,0005540,0132605,0026407 } },
  { { 0037252,0125252,0125252,0125132 } }
};
static const uD B[] = {
  { { 0142654,0044014,0077633,0035410 } },
  { { 0144027,0110641,0125335,0144760 } },
  { { 0144641,0165637,0142204,0047447 } },
  { { 0145215,0162027,0146246,0155211 } },
  { { 0145322,0026110,0010317,0110130 } },
  { { 0145120,0061472,0120300,0025363 } }
};
static const uD C[] = {
  { { 0142257,0164150,0163630,0112622 } },
  { { 0143605,0050153,0156116,0135272 } },
  { { 0144527,0056045,0145642,0062332 } },
  { { 0145213,0012063,0106250,0001025 } },
  { { 0145432,0111254,0044577,0115142 } },
  { { 0145366,0071133,0050217,0005122 } }
};
/* log( sqrt( 2*pi ) ) */
static const uD LS2P[] = { {040153,037616,041445,0172645,} };
#define LS2PI LS2P[0].d
#define MAXLGM 2.035093e36
static const uD LPI[] = { { 0040222,0103202,0043475,0006750, } };
#define LOGPI LPI[0].d

#endif

#ifdef IBMPC
static const uD A[] = {
  { { 0x6661,0x2733,0x9850,0x3f4a } },
  { { 0xe943,0xb580,0x7fbd,0xbf43 } },
  { { 0x5ebb,0x20dc,0x019f,0x3f4a } },
  { { 0xa5a1,0x16b0,0xc16c,0xbf66 } },
  { { 0x554b,0x5555,0x5555,0x3fb5 } }
};
static const uD B[] = {
  { { 0x6761,0x8ff3,0x8901,0xc095 } },
  { { 0xb93e,0x355b,0xf234,0xc0e2 } },
  { { 0x89e5,0xf890,0x3d73,0xc114 } },
  { { 0xdb51,0xf994,0xbc82,0xc131 } },
  { { 0xf20b,0x0219,0x4589,0xc13a } },
  { { 0x055e,0x5418,0x0c67,0xc12a } }
};
static const uD C[] = {
  { { 0x12b2,0x1cf3,0xfd0d,0xc075 } },
  { { 0xd757,0x7b89,0xaa0d,0xc0d0 } },
  { { 0x4c9b,0xb974,0xeb84,0xc10a } },
  { { 0x0043,0x7195,0x6286,0xc131 } },
  { { 0xf34c,0x892f,0x5255,0xc143 } },
  { { 0xe14a,0x6a11,0xce4b,0xc13e } }
};
/* log( sqrt( 2*pi ) ) */
static const union
{
  unsigned short  s[4];
  double d;
} ls2p  =  {{0xbeb5,0xc864,0x67f1,0x3fed}};
#define LS2PI   (ls2p.d)
#define MAXLGM 2.556348e305
/* log (pi) */
static const union
{
  unsigned short s[4];
  double d;
} lpi  =  {{0xa1bd,0x48e7,0x50d0,0x3ff2}};
#define LOGPI (lpi.d)
#endif

#ifdef MIEEE
static const uD A[] = {
  { { 0x3f4a,0x9850,0x2733,0x6661 } },
  { { 0xbf43,0x7fbd,0xb580,0xe943 } },
  { { 0x3f4a,0x019f,0x20dc,0x5ebb } },
  { { 0xbf66,0xc16c,0x16b0,0xa5a1 } },
  { { 0x3fb5,0x5555,0x5555,0x554b } }
};
static const uD B[] = {
  { { 0xc095,0x8901,0x8ff3,0x6761 } },
  { { 0xc0e2,0xf234,0x355b,0xb93e } },
  { { 0xc114,0x3d73,0xf890,0x89e5 } },
  { { 0xc131,0xbc82,0xf994,0xdb51 } },
  { { 0xc13a,0x4589,0x0219,0xf20b } },
  { { 0xc12a,0x0c67,0x5418,0x055e } }
};
static const uD C[] = {
  { { 0xc075,0xfd0d,0x1cf3,0x12b2 } },
  { { 0xc0d0,0xaa0d,0x7b89,0xd757 } },
  { { 0xc10a,0xeb84,0xb974,0x4c9b } },
  { { 0xc131,0x6286,0x7195,0x0043 } },
  { { 0xc143,0x5255,0x892f,0xf34c } },
  { { 0xc13e,0xce4b,0x6a11,0xe14a } }
};
/* log( sqrt( 2*pi ) ) */
static const union
{
  unsigned short  s[4];
  double d;
} ls2p  =  {{0x3fed,0x67f1,0xc864,0xbeb5}};
#define LS2PI  ls2p.d
#define MAXLGM 2.556348e305
/* log (pi) */
static const union
{
  unsigned short s[4];
  double d;
} lpi  =  {{0x3ff2, 0x50d0, 0x48e7, 0xa1bd}};
#define LOGPI (lpi.d)
#endif


/* Logarithm of gamma function */
/* Reentrant version */ 
double __lgamma_r(double x, int* sgngam);

double __lgamma_r(double x, int* sgngam)
{
	double p, q, u, w, z;
	int i;

	*sgngam = 1;
#ifdef NANS
	if (isnan(x))
		return (x);
#endif

#ifdef INFINITIES
	if (!isfinite(x))
		return (INFINITY);
#endif

	if (x < -34.0)
	{
		q = -x;
		w = __lgamma_r(q, sgngam); /* note this modifies sgngam! */
		p = floor(q);
		if (p == q)
		{
lgsing:
			_SET_ERRNO(EDOM);
			mtherr( "lgam", SING );
#ifdef INFINITIES
			return (INFINITY);
#else
			return (MAXNUM);
#endif
		}
		i = p;
		if ((i & 1) == 0)
			*sgngam = -1;
		else
			*sgngam = 1;
		z = q - p;
		if (z > 0.5)
		{
			p += 1.0;
			z = p - q;
		}
		z = q * sin( PI * z );
		if (z == 0.0)
			goto lgsing;
	/*	z = log(PI) - log( z ) - w;*/
		z = LOGPI - log( z ) - w;
		return (z);
	}

	if (x < 13.0)
	{
		z = 1.0;
		p = 0.0;
		u = x;
		while (u >= 3.0)
		{
			p -= 1.0;
			u = x + p;
			z *= u;
		}
		while (u < 2.0)
		{
			if (u == 0.0)
				goto lgsing;
			z /= u;
			p += 1.0;
			u = x + p;
		}
		if (z < 0.0)
		{
			*sgngam = -1;
			z = -z;
		}
		else
			*sgngam = 1;
		if (u == 2.0)
			return ( log(z) );
		p -= 2.0;
		x = x + p;
		p = x * polevl(x, B, 5) / p1evl(x, C, 6);
		return ( log(z) + p );
	}

	if (x > MAXLGM)
	{
		_SET_ERRNO(ERANGE);
		mtherr("lgamma", OVERFLOW);
#ifdef INFINITIES
		return (*sgngam * INFINITY);
#else
		return (*sgngam * MAXNUM);
#endif
	}

	q = (x - 0.5) * log(x) - x + LS2PI;
	if (x > 1.0e8)
		return (q);

	p = 1.0/(x*x);
	if (x >= 1000.0)
		q += ((   7.9365079365079365079365e-4 * p
			- 2.7777777777777777777778e-3) *p
			+ 0.0833333333333333333333) / x;
	else
		q += polevl( p, A, 4 ) / x;
	return (q);
}

/* This is the C99 version */
double lgamma(double x)
{
	return (__lgamma_r(x, &signgam));
}

