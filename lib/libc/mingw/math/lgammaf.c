/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/* log gamma(x+2), -.5 < x < .5 */
static const float B[] = {
   6.055172732649237E-004,
  -1.311620815545743E-003,
   2.863437556468661E-003,
  -7.366775108654962E-003,
   2.058355474821512E-002,
  -6.735323259371034E-002,
   3.224669577325661E-001,
   4.227843421859038E-001
};

/* log gamma(x+1), -.25 < x < .25 */
static const float C[] = {
   1.369488127325832E-001,
  -1.590086327657347E-001,
   1.692415923504637E-001,
  -2.067882815621965E-001,
   2.705806208275915E-001,
  -4.006931650563372E-001,
   8.224670749082976E-001,
  -5.772156501719101E-001
};

/* log( sqrt( 2*pi ) ) */
static const float LS2PI  =  0.91893853320467274178;
#define MAXLGM 2.035093e36
static const float PIINV =  0.318309886183790671538;

#include "cephes_mconf.h"

/* Reentrant version */ 
/* Logarithm of gamma function */
float __lgammaf_r(float x, int* sgngamf);

float __lgammaf_r(float x, int* sgngamf)
{
	float p, q, w, z;
	float nx, tx;
	int i, direction;

	*sgngamf = 1;
#ifdef NANS
	if (isnan(x))
		return (x);
#endif

#ifdef INFINITIES
	if (!isfinite(x))
		return (INFINITY);
#endif

	if (x < 0.0)
	{
		q = -x;
		w = __lgammaf_r(q, sgngamf); /* note this modifies sgngam! */
		p = floorf(q);
		if (p == q)
		{
lgsing:
			_SET_ERRNO(EDOM);
			mtherr("lgamf", SING);
#ifdef INFINITIES
			return (INFINITYF);
#else
			return( *sgngamf * MAXNUMF );
#endif
		}
		i = p;
		if ((i & 1) == 0)
			*sgngamf = -1;
		else
			*sgngamf = 1;
		z = q - p;
		if (z > 0.5)
		{
			p += 1.0;
			z = p - q;
		}
		z = q * sinf(PIF * z);
		if (z == 0.0)
			goto lgsing;
		z = -logf(PIINV * z) - w;
		return (z);
	}

	if (x < 6.5)
	{
		direction = 0;
		z = 1.0;
		tx = x;
		nx = 0.0;
		if (x >= 1.5)
		{
			while (tx > 2.5)
			{
				nx -= 1.0;
				tx = x + nx;
				z *=tx;
			}
			x += nx - 2.0;
iv1r5:
			p = x * polevlf( x, B, 7 );
			goto cont;
		}
		if (x >= 1.25)
		{
			z *= x;
			x -= 1.0; /* x + 1 - 2 */
			direction = 1;
			goto iv1r5;
		}
		if (x >= 0.75)
		{
			x -= 1.0;
			p = x * polevlf( x, C, 7 );
			q = 0.0;
			goto contz;
		}
		while (tx < 1.5)
		{
			if (tx == 0.0)
				goto lgsing;
			z *=tx;
			nx += 1.0;
			tx = x + nx;
		}
		direction = 1;
		x += nx - 2.0;
		p = x * polevlf(x, B, 7);

cont:
		if (z < 0.0)
		{
			*sgngamf = -1;
			z = -z;
		}
		else
		{
			*sgngamf = 1;
		}
		q = logf(z);
		if (direction)
			q = -q;
contz:
		return( p + q );
	}

	if (x > MAXLGM)
	{
		_SET_ERRNO(ERANGE);
		mtherr("lgamf", OVERFLOW);
#ifdef INFINITIES
		return (*sgngamf * INFINITYF);
#else
		return (*sgngamf * MAXNUMF);
#endif

	}

/* Note, though an asymptotic formula could be used for x >= 3,
 * there is cancellation error in the following if x < 6.5.  */
	q = LS2PI - x;
	q += (x - 0.5) * logf(x);

	if (x <= 1.0e4)
	{
		z = 1.0/x;
		p = z * z;
		q += ((    6.789774945028216E-004 * p
			 - 2.769887652139868E-003 ) * p
			+  8.333316229807355E-002 ) * z;
	}
	return (q);
}

/* This is the C99 version */
float lgammaf(float x)
{
	return (__lgammaf_r(x, &signgam));
}

