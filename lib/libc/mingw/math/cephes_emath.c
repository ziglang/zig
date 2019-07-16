/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "cephes_emath.h"

/*
 * The constants are for 64 bit precision.
 */


/* Move in external format number,
 * converting it to internal format.
 */
void __emovi(const short unsigned int * __restrict__ a,
	     short unsigned int * __restrict__ b)
{
	register const unsigned short *p;
	register unsigned short *q;
	int i;

	q = b;
	p = a + (NE-1);	/* point to last word of external number */
	/* get the sign bit */
	if (*p & 0x8000)
		*q++ = 0xffff;
	else
		*q++ = 0;
	/* get the exponent */
	*q = *p--;
	*q++ &= 0x7fff;	/* delete the sign bit */
#ifdef INFINITY
	if ((*(q - 1) & 0x7fff) == 0x7fff)
	{
#ifdef NANS
		if (__eisnan(a))
		{
			*q++ = 0;
			for (i = 3; i < NI; i++ )
				*q++ = *p--;
			return;
		}
#endif
		for (i = 2; i < NI; i++)
			*q++ = 0;
		return;
	}
#endif
	/* clear high guard word */
	*q++ = 0;
	/* move in the significand */
	for (i = 0; i < NE - 1; i++ )
		*q++ = *p--;
	/* clear low guard word */
	*q = 0;
}


/*
;	Add significands
;	x + y replaces y
*/

void __eaddm(const short unsigned int * __restrict__ x,
		  short unsigned int * __restrict__ y)
{
	register unsigned long a;
	int i;
	unsigned int carry;

	x += NI - 1;
	y += NI - 1;
	carry = 0;
	for (i = M; i < NI; i++)
	{
		a = (unsigned long)(*x) + (unsigned long)(*y) + carry;
		if (a & 0x10000)
			carry = 1;
		else
			carry = 0;
		*y = (unsigned short)a;
		--x;
		--y;
	}
}

/*
;	Subtract significands
;	y - x replaces y
*/

void __esubm(const short unsigned int * __restrict__ x,
		  short unsigned int * __restrict__ y)
{
	unsigned long a;
	int i;
	unsigned int carry;

	x += NI - 1;
	y += NI - 1;
	carry = 0;
	for (i = M; i < NI; i++)
	{
		a = (unsigned long)(*y) - (unsigned long)(*x) - carry;
		if (a & 0x10000)
			carry = 1;
		else
			carry = 0;
		*y = (unsigned short)a;
		--x;
		--y;
	}
}


/* Multiply significand of e-type number b
by 16-bit quantity a, e-type result to c. */

static void __m16m(short unsigned int a,
		   short unsigned int *  __restrict__ b,
		   short unsigned int *  __restrict__ c)
{
	register unsigned short *pp;
	register unsigned long carry;
	unsigned short *ps;
	unsigned short p[NI];
	unsigned long aa, m;
	int i;

	aa = a;
	pp = &p[NI - 2];
	*pp++ = 0;
	*pp = 0;
	ps = &b[NI - 1];

	for(i = M + 1; i < NI; i++)
	{
		if (*ps == 0)
		{
			--ps;
			--pp;
			*(pp - 1) = 0;
		}
		else
		{
			m = (unsigned long) aa * *ps--;
			carry = (m & 0xffff) + *pp;
			*pp-- = (unsigned short)carry;
			carry = (carry >> 16) + (m >> 16) + *pp;
			*pp = (unsigned short)carry;
			*(pp - 1) = carry >> 16;
		}
	}
	for (i = M; i < NI; i++)
	c[i] = p[i];
}


/* Divide significands. Neither the numerator nor the denominator
is permitted to have its high guard word nonzero.  */

int __edivm(short unsigned int * __restrict__ den,
		 short unsigned int * __restrict__ num)
{
	int i;
	register unsigned short *p;
	unsigned long tnum;
	unsigned short j, tdenm, tquot;
	unsigned short tprod[NI + 1];
	unsigned short equot[NI];

	p = &equot[0];
	*p++ = num[0];
	*p++ = num[1];

	for (i = M; i < NI; i++)
	{
		*p++ = 0;
	}
	__eshdn1(num);
	tdenm = den[M + 1];
	for (i = M; i < NI; i++)
	{
		/* Find trial quotient digit (the radix is 65536). */
		tnum = (((unsigned long) num[M]) << 16) + num[M + 1];

		/* Do not execute the divide instruction if it will overflow. */
		if ((tdenm * 0xffffUL) < tnum)
			tquot = 0xffff;
		else
			tquot = tnum / tdenm;

		/* Prove that the divide worked. */
		/*
		tcheck = (unsigned long)tquot * tdenm;
		if (tnum - tcheck > tdenm)
			tquot = 0xffff;
		*/
		/* Multiply denominator by trial quotient digit. */
		__m16m(tquot, den, tprod);
		/* The quotient digit may have been overestimated. */
		if (__ecmpm(tprod, num) > 0)
		{
			tquot -= 1;
			__esubm(den, tprod);
			if(__ecmpm(tprod, num) > 0)
			{
				tquot -= 1;
				__esubm(den, tprod);
			}
		}
		__esubm(tprod, num);
		equot[i] = tquot;
		__eshup6(num);
	}
	/* test for nonzero remainder after roundoff bit */
	p = &num[M];
	j = 0;
	for (i = M; i < NI; i++)
	{
		j |= *p++;
	}
	if (j)
		j = 1;

	for (i = 0; i < NI; i++)
		num[i] = equot[i];

	return ( (int)j );
}


/* Multiply significands */
int __emulm(const short unsigned int * __restrict__ a,
		 short unsigned int * __restrict__ b)
{
	const unsigned short *p;
	unsigned short *q;
	unsigned short pprod[NI];
	unsigned short equot[NI];
	unsigned short j;
	int i;

	equot[0] = b[0];
	equot[1] = b[1];
	for (i = M; i < NI; i++)
		equot[i] = 0;

	j = 0;
	p = &a[NI - 1];
	q = &equot[NI - 1];
	for (i = M + 1; i < NI; i++)
	{
		if (*p == 0)
		{
			--p;
		}
		else
		{
			__m16m(*p--, b, pprod);
			__eaddm(pprod, equot);
		}
		j |= *q;
		__eshdn6(equot);
	}

	for (i = 0; i < NI; i++)
		b[i] = equot[i];

	/* return flag for lost nonzero bits */
	return ( (int)j );
}


/*
 * Normalize and round off.
 *
 * The internal format number to be rounded is "s".
 * Input "lost" indicates whether the number is exact.
 * This is the so-called sticky bit.
 *
 * Input "subflg" indicates whether the number was obtained
 * by a subtraction operation.  In that case if lost is nonzero
 * then the number is slightly smaller than indicated.
 *
 * Input "expo" is the biased exponent, which may be negative.
 * the exponent field of "s" is ignored but is replaced by
 * "expo" as adjusted by normalization and rounding.
 *
 * Input "rcntrl" is the rounding control.
 *
 * Input "rnprc" is precison control (64 or NBITS).
 */

void __emdnorm(short unsigned int *s, int lost, int subflg, int expo, int rcntrl, int rndprc)
{
	int i, j;
	unsigned short r;
	int rw = NI-1; /* low guard word */
	int re = NI-2;
	const unsigned short rmsk = 0xffff;
	const unsigned short rmbit = 0x8000;
#if NE == 6
	unsigned short rbit[NI] = {0,0,0,0,0,0,0,1,0};
#else
	unsigned short rbit[NI] = {0,0,0,0,0,0,0,0,0,0,0,1,0};
#endif

	/* Normalize */
	j = __enormlz(s);

	/* a blank significand could mean either zero or infinity. */
#ifndef INFINITY
	if (j > NBITS)
	{
		__ecleazs(s);
		return;
	}
#endif
	expo -= j;
#ifndef INFINITY
	if (expo >= 32767L)
		goto overf;
#else
	if ((j > NBITS) && (expo < 32767L))
	{
		__ecleazs(s);
		return;
	}
#endif
	if (expo < 0L)
	{
		if (expo > (long)(-NBITS - 1))
		{
			j = (int)expo;
			i = __eshift(s, j);
			if (i)
				lost = 1;
		}
		else
		{
			__ecleazs(s);
			return;
		}
	}
	/* Round off, unless told not to by rcntrl. */
	if (rcntrl == 0)
		goto mdfin;
	if (rndprc == 64)
	{
		rw = 7;
		re = 6;
		rbit[NI - 2] = 0;
		rbit[6] = 1;
	}

	/* Shift down 1 temporarily if the data structure has an implied
	 * most significant bit and the number is denormal.
	 * For rndprc = 64 or NBITS, there is no implied bit.
	 * But Intel long double denormals lose one bit of significance even so.
	 */
#if IBMPC
	if ((expo <= 0) && (rndprc != NBITS))
#else
	if ((expo <= 0) && (rndprc != 64) && (rndprc != NBITS))
#endif
	{
		lost |= s[NI - 1] & 1;
		__eshdn1(s);
	}
	/* Clear out all bits below the rounding bit,
	 * remembering in r if any were nonzero.
	 */
	r = s[rw] & rmsk;
	if (rndprc < NBITS)
	{
		i = rw + 1;
		while (i < NI)
		{
			if( s[i] )
				r |= 1;
			s[i] = 0;
			++i;
		}
	}
	s[rw] &= (rmsk ^ 0xffff);
	if ((r & rmbit) != 0)
	{
		if (r == rmbit)
		{
			if (lost == 0)
			{ /* round to even */
				if ((s[re] & 1) == 0)
					goto mddone;
			}
			else
			{
				if (subflg != 0)
					goto mddone;
			}
		}
		__eaddm(rbit, s);
	}
mddone:
#if IBMPC
	if ((expo <= 0) && (rndprc != NBITS))
#else
	if ((expo <= 0) && (rndprc != 64) && (rndprc != NBITS))
#endif
	{
		__eshup1(s);
	}
	if (s[2] != 0)
	{ /* overflow on roundoff */
		__eshdn1(s);
		expo += 1;
	}
mdfin:
	s[NI - 1] = 0;
	if (expo >= 32767L)
	{
#ifndef INFINITY
overf:
#endif
#ifdef INFINITY
		s[1] = 32767;
		for (i = 2; i < NI - 1; i++ )
			s[i] = 0;
#else
		s[1] = 32766;
		s[2] = 0;
		for (i = M + 1; i < NI - 1; i++)
			s[i] = 0xffff;
		s[NI - 1] = 0;
		if ((rndprc < 64) || (rndprc == 113))
			s[rw] &= (rmsk ^ 0xffff);
#endif
		return;
	}
	if (expo < 0)
		s[1] = 0;
	else
		s[1] = (unsigned short)expo;
}


/*
;	Multiply.
;
;	unsigned short a[NE], b[NE], c[NE];
;	emul( a, b, c );	c = b * a
*/
void __emul(const short unsigned int *a,
		 const short unsigned int *b,
		 short unsigned int *c)
{
	unsigned short ai[NI], bi[NI];
	int i, j;
	long lt, lta, ltb;

#ifdef NANS
	/* NaN times anything is the same NaN. */
	if (__eisnan(a))
	{
		__emov(a, c);
		return;
	}
	if (__eisnan(b))
	{
		__emov(b, c);
		return;
	}
	/* Zero times infinity is a NaN. */
	if ((__eisinf(a) && __eiiszero(b))
	 || (__eisinf(b) && __eiiszero(a)))
	{
		mtherr( "emul", DOMAIN);
		__enan_NBITS(c);
		return;
	}
#endif
/* Infinity times anything else is infinity. */
#ifdef INFINITY
	if (__eisinf(a) || __eisinf(b))
	{
		if (__eisneg(a) ^ __eisneg(b))
			*(c + (NE-1)) = 0x8000;
		else
			*(c + (NE-1)) = 0;
		__einfin(c);
		return;
	}
#endif
	__emovi(a, ai);
	__emovi(b, bi);
	lta = ai[E];
	ltb = bi[E];
	if (ai[E] == 0)
	{
		for (i = 1; i < NI - 1; i++)
		{
			if (ai[i] != 0)
			{
				lta -= __enormlz( ai );
				goto mnzer1;
			}
		}
		__eclear(c);
		return;
	}
mnzer1:

	if (bi[E] == 0)
	{
		for (i = 1; i < NI - 1; i++)
		{
			if (bi[i] != 0)
			{
				ltb -= __enormlz(bi);
				goto mnzer2;
			}
		}
		__eclear(c);
		return;
	}
mnzer2:

	/* Multiply significands */
	j = __emulm(ai, bi);
	/* calculate exponent */
	lt = lta + ltb - (EXONE - 1);
	__emdnorm(bi, j, 0, lt, 64, NBITS);
	/* calculate sign of product */
	if (ai[0] == bi[0])
		bi[0] = 0;
	else
		bi[0] = 0xffff;
	__emovo(bi, c);
}


/* move out internal format to ieee long double */
void __toe64(short unsigned int *a, short unsigned int *b)
{
	register unsigned short *p, *q;
	unsigned short i;

#ifdef NANS
	if (__eiisnan(a))
	{
		__enan_64(b);
		return;
	}
#endif
#ifdef IBMPC
	/* Shift Intel denormal significand down 1.  */
	if (a[E] == 0)
		__eshdn1(a);
#endif
	p = a;
#ifdef MIEEE
	q = b;
#else
	q = b + 4; /* point to output exponent */
#if 1
	/* NOTE: if data type is 96 bits wide, clear the last word here. */
	*(q + 1)= 0;
#endif
#endif

	/* combine sign and exponent */
	i = *p++;
#ifdef MIEEE
	if (i)
		*q++ = *p++ | 0x8000;
	else
		*q++ = *p++;
	*q++ = 0;
#else
	if (i)
		*q-- = *p++ | 0x8000;
	else
		*q-- = *p++;
#endif
	/* skip over guard word */
	++p;
	/* move the significand */
#ifdef MIEEE
	for (i = 0; i < 4; i++)
		*q++ = *p++;
#else
#ifdef INFINITY
	if (__eiisinf(a))
        {
	/* Intel long double infinity.  */
		*q-- = 0x8000;
		*q-- = 0;
		*q-- = 0;
		*q = 0;
		return;
	}
#endif
	for (i = 0; i < 4; i++)
		*q-- = *p++;
#endif
}


/* Compare two e type numbers.
 *
 * unsigned short a[NE], b[NE];
 * ecmp( a, b );
 *
 *  returns +1 if a > b
 *           0 if a == b
 *          -1 if a < b
 *          -2 if either a or b is a NaN.
 */
int __ecmp(const short unsigned int * __restrict__ a,
		const short unsigned int *  __restrict__ b)
{
	unsigned short ai[NI], bi[NI];
	register unsigned short *p, *q;
	register int i;
	int msign;

#ifdef NANS
	if (__eisnan (a) || __eisnan (b))
		return (-2);
#endif
	__emovi(a, ai);
	p = ai;
	__emovi(b, bi);
	q = bi;

	if (*p != *q)
	{ /* the signs are different */
		/* -0 equals + 0 */
		for (i = 1; i < NI - 1; i++)
		{
			if (ai[i] != 0)
				goto nzro;
			if (bi[i] != 0)
				goto nzro;
		}
		return (0);
nzro:
		if (*p == 0)
			return (1);
		else
			return (-1);
	}
	/* both are the same sign */
	if (*p == 0)
		msign = 1;
	else
		msign = -1;
	i = NI - 1;
	do
	{
		if (*p++ != *q++)
		{
			goto diff;
		}
	}
	while (--i > 0);

	return (0);	/* equality */

diff:
	if ( *(--p) > *(--q) )
		return (msign);		/* p is bigger */
	else
		return (-msign);	/* p is littler */
}

/*
;	Shift significand
;
;	Shifts significand area up or down by the number of bits
;	given by the variable sc.
*/
int __eshift(short unsigned int *x, int sc)
{
	unsigned short lost;
	unsigned short *p;

	if (sc == 0)
		return (0);

	lost = 0;
	p = x + NI - 1;

	if (sc < 0)
	{
		sc = -sc;
		while (sc >= 16)
		{
			lost |= *p;	/* remember lost bits */
			__eshdn6(x);
			sc -= 16;
		}

		while (sc >= 8)
		{
			lost |= *p & 0xff;
			__eshdn8(x);
			sc -= 8;
		}

		while (sc > 0)
		{
			lost |= *p & 1;
			__eshdn1(x);
			sc -= 1;
		}
	}
	else
	{
		while (sc >= 16)
		{
			__eshup6(x);
			sc -= 16;
		}

		while (sc >= 8)
		{
			__eshup8(x);
			sc -= 8;
		}

		while (sc > 0)
		{
			__eshup1(x);
			sc -= 1;
		}
	}
	if (lost)
		lost = 1;
	return ( (int)lost );
}


/*
;	normalize
;
; Shift normalizes the significand area pointed to by argument
; shift count (up = positive) is returned.
*/
int __enormlz(short unsigned int *x)
{
	register unsigned short *p;
	int sc;

	sc = 0;
	p = &x[M];
	if (*p != 0)
		goto normdn;
	++p;
	if (*p & 0x8000)
		return (0);	/* already normalized */
	while (*p == 0)
	{
		__eshup6(x);
		sc += 16;
		/* With guard word, there are NBITS+16 bits available.
		 * return true if all are zero.
		 */
		if (sc > NBITS)
			return (sc);
	}
	/* see if high byte is zero */
	while ((*p & 0xff00) == 0)
	{
		__eshup8(x);
		sc += 8;
	}
	/* now shift 1 bit at a time */
	while ((*p  & 0x8000) == 0)
	{
		__eshup1(x);
		sc += 1;
		if (sc > (NBITS + 16))
		{
			mtherr( "enormlz", UNDERFLOW);
			return (sc);
		}
	}
	return (sc);

	/* Normalize by shifting down out of the high guard word
	   of the significand */
normdn:
	if (*p & 0xff00)
	{
		__eshdn8(x);
		sc -= 8;
	}
	while (*p != 0)
	{
		__eshdn1(x);
		sc -= 1;

		if (sc < -NBITS)
		{
			mtherr("enormlz", OVERFLOW);
			return (sc);
		}
	}
	return (sc);
}


/* Move internal format number out,
 * converting it to external format.
 */
void __emovo(const short unsigned int * __restrict__ a,
		  short unsigned int * __restrict__ b)
{
	register const unsigned short *p;
	register unsigned short *q;
	unsigned short i;

	p = a;
	q = b + (NE - 1); /* point to output exponent */
	/* combine sign and exponent */
	i = *p++;
	if (i)
		*q-- = *p++ | 0x8000;
	else
		*q-- = *p++;
#ifdef INFINITY
	if (*(p - 1) == 0x7fff)
	{
#ifdef NANS
		if (__eiisnan(a))
		{
			__enan_NBITS(b);
			return;
		}
#endif
		__einfin(b);
		return;
	}
#endif
	/* skip over guard word */
	++p;
	/* move the significand */
	for (i = 0; i < NE - 1; i++)
		*q-- = *p++;
}


#if USE_LDTOA

void __eiremain(short unsigned int *den, short unsigned int *num,
	 short unsigned int *equot )
{
	long ld, ln;
	unsigned short j;

	ld = den[E];
	ld -= __enormlz(den);
	ln = num[E];
	ln -= __enormlz(num);
	__ecleaz(equot);
	while (ln >= ld)
	{
		if(__ecmpm(den,num) <= 0)
		{
			__esubm(den, num);
			j = 1;
		}
		else
		{
			j = 0;
		}
		__eshup1(equot);
		equot[NI - 1] |= j;
		__eshup1(num);
		ln -= 1;
	}
	__emdnorm( num, 0, 0, ln, 0, NBITS );
}


void __eadd1(const short unsigned int *  __restrict__ a,
		  const short unsigned int *  __restrict__ b,
		  short unsigned int *  __restrict__ c,
		  int subflg)
{
	unsigned short ai[NI], bi[NI], ci[NI];
	int i, lost, j, k;
	long lt, lta, ltb;

#ifdef INFINITY
	if (__eisinf(a))
	{
		__emov(a, c);
		if( subflg )
			__eneg(c);
		return;
	}
	if (__eisinf(b))
	{
		__emov(b, c);
		return;
	}
#endif
	__emovi(a, ai);
	__emovi(b, bi);
	if (sub)
		ai[0] = ~ai[0];

	/* compare exponents */
	lta = ai[E];
	ltb = bi[E];
	lt = lta - ltb;
	if (lt > 0L)
	{	/* put the larger number in bi */
		__emovz(bi, ci);
		__emovz(ai, bi);
		__emovz(ci, ai);
		ltb = bi[E];
		lt = -lt;
	}
	lost = 0;
	if (lt != 0L)
	{
		if (lt < (long)(-NBITS - 1))
			goto done;	/* answer same as larger addend */
		k = (int)lt;
		lost = __eshift(ai, k); /* shift the smaller number down */
	}
	else
	{
		/* exponents were the same, so must compare significands */
		i = __ecmpm(ai, bi);
		if (i == 0)
		{ /* the numbers are identical in magnitude */
			/* if different signs, result is zero */
			if (ai[0] != bi[0])
			{
				__eclear(c);
				return;
			}
			/* if same sign, result is double */
			/* double denomalized tiny number */
			if ((bi[E] == 0) && ((bi[3] & 0x8000) == 0))
			{
				__eshup1( bi );
				goto done;
			}
			/* add 1 to exponent unless both are zero! */
			for (j = 1; j < NI - 1; j++)
			{
				if (bi[j] != 0)
				{
				/* This could overflow, but let emovo take care of that. */
					ltb += 1;
					break;
				}
			}
			bi[E] = (unsigned short )ltb;
			goto done;
		}
		if (i > 0)
		{	/* put the larger number in bi */
			__emovz(bi, ci);
			__emovz(ai, bi);
			__emovz(ci, ai);
		}
	}
	if (ai[0] == bi[0])
	{
		__eaddm(ai, bi);
		subflg = 0;
	}
	else
	{
		__esubm(ai, bi);
		subflg = 1;
	}
	__emdnorm(bi, lost, subflg, ltb, 64, NBITS);

done:
	__emovo(bi, c);
}


/* y = largest integer not greater than x
 * (truncated toward minus infinity)
 *
 * unsigned short x[NE], y[NE]
 *
 * efloor( x, y );
 */


void __efloor(short unsigned int *x, short unsigned int *y)
{
	register unsigned short *p;
	int e, expon, i;
	unsigned short f[NE];
	const unsigned short bmask[] = {
				0xffff,
				0xfffe,
				0xfffc,
				0xfff8,
				0xfff0,
				0xffe0,
				0xffc0,
				0xff80,
				0xff00,
				0xfe00,
				0xfc00,
				0xf800,
				0xf000,
				0xe000,
				0xc000,
				0x8000,
				0x0000,
	};

	__emov(x, f); /* leave in external format */
	expon = (int) f[NE - 1];
	e = (expon & 0x7fff) - (EXONE - 1);
	if (e <= 0)
	{
		__eclear(y);
		goto isitneg;
	}
	/* number of bits to clear out */
	e = NBITS - e;
	__emov(f, y);
	if (e <= 0)
		return;

	p = &y[0];
	while (e >= 16)
	{
		*p++ = 0;
		e -= 16;
	}
	/* clear the remaining bits */
	*p &= bmask[e];
	/* truncate negatives toward minus infinity */
isitneg:

	if ((unsigned short)expon & (unsigned short)0x8000)
	{
		for (i = 0; i < NE - 1; i++)
		{
			if (f[i] != y[i])
			{
				__esub( __eone, y, y );
				break;
			}
		}
	}
}

/*
;	Subtract external format numbers.
;
;	unsigned short a[NE], b[NE], c[NE];
;	esub( a, b, c );	 c = b - a
*/

void __esub(const short unsigned int *  a,
		 const short unsigned int *  b,
		 short unsigned int *  c)
{
#ifdef NANS
	if (__eisnan(a))
	{
		__emov (a, c);
		return;
	}
	if ( __eisnan(b))
	{
		__emov(b, c);
		return;
	}
	/* Infinity minus infinity is a NaN.
	 * Test for subtracting infinities of the same sign.
	 */
	if (__eisinf(a) && __eisinf(b) && ((__eisneg (a) ^ __eisneg (b)) == 0))
	{
		mtherr("esub", DOMAIN);
		__enan_NBITS( c );
		return;
	}
#endif
	__eadd1(a, b, c, 1);
}


/*
;	Divide.
;
;	unsigned short a[NI], b[NI], c[NI];
;	ediv( a, b, c );	c = b / a
*/

void __ediv(const short unsigned int *a,
		 const short unsigned int *b,
		 short unsigned int *c)
{
	unsigned short ai[NI], bi[NI];
	int i;
	long lt, lta, ltb;

#ifdef NANS
	/* Return any NaN input. */
	if (__eisnan(a))
	{
		__emov(a, c);
		return;
	}
	if (__eisnan(b))
	{
		__emov(b, c);
		return;
	}
	/* Zero over zero, or infinity over infinity, is a NaN. */
	if ((__eiszero(a) && __eiszero(b))
	 || (__eisinf (a) && __eisinf (b)))
	{
		mtherr("ediv", DOMAIN);
		__enan_NBITS( c );
		return;
	}
#endif
/* Infinity over anything else is infinity. */
#ifdef INFINITY
	if (__eisinf(b))
	{
		if (__eisneg(a) ^ __eisneg(b))
			*(c + (NE - 1)) = 0x8000;
		else
			*(c + (NE - 1)) = 0;
		__einfin(c);
		return;
	}
	if (__eisinf(a))
	{
		__eclear(c);
		return;
	}
#endif
	__emovi(a, ai);
	__emovi(b, bi);
	lta = ai[E];
	ltb = bi[E];
	if (bi[E] == 0)
	{ /* See if numerator is zero. */
		for (i = 1; i < NI - 1; i++)
		{
			if (bi[i] != 0)
			{
				ltb -= __enormlz(bi);
				goto dnzro1;
			}
		}
		__eclear(c);
		return;
	}
dnzro1:

	if (ai[E] == 0)
	{	/* possible divide by zero */
		for (i = 1; i < NI - 1; i++)
		{
			if (ai[i] != 0)
			{
				lta -= __enormlz(ai);
				goto dnzro2;
			}
		}
		if (ai[0] == bi[0])
			*(c + (NE - 1)) = 0;
		else
			*(c + (NE - 1)) = 0x8000;
		__einfin(c);
		mtherr("ediv", SING);
		return;
	}
dnzro2:

	i = __edivm(ai, bi);
	/* calculate exponent */
	lt = ltb - lta + EXONE;
	__emdnorm(bi, i, 0, lt, 64, NBITS);
	/* set the sign */
	if (ai[0] == bi[0])
		bi[0] = 0;
	else
		bi[0] = 0Xffff;
	__emovo(bi, c);
}

void __e64toe(short unsigned int *pe, short unsigned int *y)
{
	unsigned short yy[NI];
	unsigned short *p, *q, *e;
	int i;

	e = pe;
	p = yy;
	for (i = 0; i < NE - 5; i++)
		*p++ = 0;
#ifdef IBMPC
	for (i = 0; i < 5; i++)
		*p++ = *e++;
#endif
#ifdef DEC
	for (i = 0; i < 5; i++)
		*p++ = *e++;
#endif
#ifdef MIEEE
	p = &yy[0] + (NE - 1);
	*p-- = *e++;
	++e;
	for (i = 0; i < 4; i++)
		*p-- = *e++;
#endif

#ifdef IBMPC
	/* For Intel long double, shift denormal significand up 1
	   -- but only if the top significand bit is zero.  */
	if ((yy[NE - 1] & 0x7fff) == 0 && (yy[NE - 2] & 0x8000) == 0)
	{
		unsigned short temp[NI + 1];
		__emovi(yy, temp);
		__eshup1(temp);
		__emovo(temp,y);
		return;
	}
#endif
#ifdef INFINITY
	/* Point to the exponent field.  */
	p = &yy[NE - 1];
	if (*p == 0x7fff)
	{
#ifdef NANS
#ifdef IBMPC
		for (i = 0; i < 4; i++)
		{
			if ((i != 3 && pe[i] != 0)
			  /* Check for Intel long double infinity pattern.  */
			  || (i == 3 && pe[i] != 0x8000))
			{
				__enan_NBITS(y);
				return;
			}
		}
#else
		for (i = 1; i <= 4; i++)
		{
			if (pe[i] != 0)
			{
				__enan_NBITS(y);
				return;
			}
		}
#endif
#endif /* NANS */
		__eclear(y);
		__einfin(y);
		if (*p & 0x8000)
			__eneg(y);
		return;
	}
#endif
	p = yy;
	q = y;
	for (i = 0; i < NE; i++)
		*q++ = *p++;
}

#endif /* USE_LDTOA */ 
