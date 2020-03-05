/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_mconf.h"

/* define MAXGAM 34.84425627277176174 */

/* Stirling's formula for the gamma function
 * gamma(x) = sqrt(2 pi) x^(x-.5) exp(-x) ( 1 + 1/x P(1/x) )
 * .028 < 1/x < .1
 * relative error < 1.9e-11
 */
static const float STIR[] = {
  -2.705194986674176E-003,
   3.473255786154910E-003,
   8.333331788340907E-002,
};
static const float MAXSTIR = 26.77;
static const float SQTPIF = 2.50662827463100050242; /* sqrt( 2 pi ) */

static float stirf(float);

/* Gamma function computed by Stirling's formula,
 * sqrt(2 pi) x^(x-.5) exp(-x) (1 + 1/x P(1/x))
 * The polynomial STIR is valid for 33 <= x <= 172.
 */
static float stirf( float x )
{
	float  y, w, v;

	w = 1.0/x;
	w = 1.0 + w * polevlf(w, STIR, 2);
	y = expf(-x);
	if (x > MAXSTIR)
	{ /* Avoid overflow in pow() */
		v = powf(x, 0.5 * x - 0.25);
		y *= v;
		y *= v;
	}
	else
	{
		y = powf(x, x - 0.5) * y;
	}
	y = SQTPIF * y * w;
	return (y);
}


/* gamma(x+2), 0 < x < 1 */
static const float P[] = {
  1.536830450601906E-003,
  5.397581592950993E-003,
  4.130370201859976E-003,
  7.232307985516519E-002,
  8.203960091619193E-002,
  4.117857447645796E-001,
  4.227867745131584E-001,
  9.999999822945073E-001,
};

float __tgammaf_r( float x, int* sgngamf);

float __tgammaf_r( float x, int* sgngamf)
{
	float p, q, z, nz;
	int i, direction, negative;

#ifdef NANS
	if (isnan(x))
		return (x);
#endif
#ifdef INFINITIES
#ifdef NANS
	if (x == INFINITYF)
		return (x);
	if (x == -INFINITYF)
		return (NANF);
#else
	if (!isfinite(x))
		return (x);
#endif
#endif
	if (x == 0.0)
		return copysignf(HUGE_VALF, x);

	*sgngamf = 1;
	negative = 0;
	nz = 0.0;
	if (x < 0.0)
	{
		negative = 1;
		q = -x;
		p = floorf(q);
		if (p == q)
		{
gsing:
			_SET_ERRNO(EDOM);
			mtherr("tgammaf", SING);
#ifdef NANS
			return (NAN);
#else
			return (MAXNUMF);
#endif
		}
		i = p;
		if ((i & 1) == 0)
			*sgngamf = -1;
		nz = q - p;
		if (nz > 0.5)
		{
			p += 1.0;
			nz = q - p;
		}
		nz = q * sinf(PIF * nz);
		if (nz == 0.0)
		{
			_SET_ERRNO(ERANGE);
			mtherr("tgamma", OVERFLOW);
#ifdef INFINITIES
			return(*sgngamf * INFINITYF);
#else
			return(*sgngamf * MAXNUMF);
#endif
		}
		if (nz < 0)
			nz = -nz;
		x = q;
	}
	if (x >= 10.0)
	{
		z = stirf(x);
	}
	if (x < 2.0)
		direction = 1;
	else
		direction = 0;
	z = 1.0;
	while (x >= 3.0)
	{
		x -= 1.0;
		z *= x;
	}
	/*
	while (x < 0.0)
	{
		if (x > -1.E-4)
			goto Small;
		z *=x;
		x += 1.0;
	}
	*/
	while (x < 2.0)
	{
		if (x < 1.e-4)
			goto Small;
		z *=x;
		x += 1.0;
	}

	if (direction)
		z = 1.0/z;

	if (x == 2.0)
		return (z);

	x -= 2.0;
	p = z * polevlf(x, P, 7);

gdone:
	if (negative)
	{
		p = *sgngamf * PIF/(nz * p );
	}
	return (p);

Small:
	if (x == 0.0)
	{
		goto gsing;
	}
	else
	{
		p = z / ((1.0 + 0.5772156649015329 * x) * x);
		goto gdone;
	}
}

/* This is the C99 version */
float tgammaf(float x)
{
	int local_sgngamf = 0;
	return (__tgammaf_r(x, &local_sgngamf));
}

