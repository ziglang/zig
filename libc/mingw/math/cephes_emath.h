/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _CEPHES_EMATH_H
#define _CEPHES_EMATH_H

/**
 * This is a workaround for a gcc bug
 */
#define __restrict__

/* This file is extracted from S L Moshier's  ioldoubl.c,
 * modified for use in MinGW 
 *
 * Extended precision arithmetic functions for long double I/O.
 * This program has been placed in the public domain.
 */


/*
 * Revision history:
 *
 *  5 Jan 84	PDP-11 assembly language version
 *  6 Dec 86	C language version
 * 30 Aug 88	100 digit version, improved rounding
 * 15 May 92    80-bit long double support
 *
 * Author:  S. L. Moshier.
 *
 * 6 Oct 02	Modified for MinGW by inlining utility routines,
 * 		removing global variables, and splitting out strtold
 *		from _IO_ldtoa and _IO_ldtostr.
 *  
 *		Danny Smith <dannysmith@users.sourceforge.net>
 * 
 */


/*							ieee.c
 *
 *    Extended precision IEEE binary floating point arithmetic routines
 *
 * Numbers are stored in C language as arrays of 16-bit unsigned
 * short integers.  The arguments of the routines are pointers to
 * the arrays.
 *
 *
 * External e type data structure, simulates Intel 8087 chip
 * temporary real format but possibly with a larger significand:
 *
 *	NE-1 significand words	(least significant word first,
 *				 most significant bit is normally set)
 *	exponent		(value = EXONE for 1.0,
 *				top bit is the sign)
 *
 *
 * Internal data structure of a number (a "word" is 16 bits):
 *
 * ei[0]	sign word	(0 for positive, 0xffff for negative)
 * ei[1]	biased __exponent	(value = EXONE for the number 1.0)
 * ei[2]	high guard word	(always zero after normalization)
 * ei[3]
 * to ei[NI-2]	significand	(NI-4 significand words,
 *				 most significant word first,
 *				 most significant bit is set)
 * ei[NI-1]	low guard word	(0x8000 bit is rounding place)
 *
 *
 *
 *		Routines for external format numbers
 *
 *	__asctoe64( string, &d )	ASCII string to long double
 *	__asctoeg( string, e, prec )	ASCII string to specified precision
 *	__e64toe( &d, e )		IEEE long double precision to e type
 *	__eadd( a, b, c )		c = b + a
 *	__eclear(e)			e = 0
 *	__ecmp (a, b)			Returns 1 if a > b, 0 if a == b,
 *					-1 if a < b, -2 if either a or b is a NaN.
 *	__ediv( a, b, c )		c = b / a
 *	__efloor( a, b )		truncate to integer, toward -infinity
 *	__efrexp( a, exp, s )		extract exponent and significand
 *	__eifrac( e, &l, frac )   	e to long integer and e type fraction
 *	__euifrac( e, &l, frac )  	e to unsigned long integer and e type fraction
 *	__einfin( e )			set e to infinity, leaving its sign alone
 *	__eldexp( a, n, b )		multiply by 2**n
 *	__emov( a, b )			b = a
 *	__emul( a, b, c )		c = b * a
 *	__eneg(e)			e = -e
 *	__eround( a, b )		b = nearest integer value to a
 *	__esub( a, b, c )		c = b - a
 *	__e24toasc( &f, str, n )	single to ASCII string, n digits after decimal
 *	__e53toasc( &d, str, n )	double to ASCII string, n digits after decimal
 *	__e64toasc( &d, str, n )	long double to ASCII string
 *	__etoasc( e, str, n )		e to ASCII string, n digits after decimal
 *	__etoe24( e, &f )		convert e type to IEEE single precision
 *	__etoe53( e, &d )		convert e type to IEEE double precision
 *	__etoe64( e, &d )		convert e type to IEEE long double precision
 *	__eisneg( e )             	1 if sign bit of e != 0, else 0
 *	__eisinf( e )             	1 if e has maximum exponent (non-IEEE)
 *					or is infinite (IEEE)
 *	__eisnan( e )             	1 if e is a NaN
 *	__esqrt( a, b )			b = square root of a
 *
 *
 *		Routines for internal format numbers
 *
 *	__eaddm( ai, bi )		add significands, bi = bi + ai
 *	__ecleaz(ei)		ei = 0
 *	__ecleazs(ei)		set ei = 0 but leave its sign alone
 *	__ecmpm( ai, bi )		compare significands, return 1, 0, or -1
 *	__edivm( ai, bi )		divide  significands, bi = bi / ai
 *	__emdnorm(ai,l,s,exp)	normalize and round off
 *	__emovi( a, ai )		convert external a to internal ai
 *	__emovo( ai, a )		convert internal ai to external a
 *	__emovz( ai, bi )		bi = ai, low guard word of bi = 0
 *	__emulm( ai, bi )		multiply significands, bi = bi * ai
 *	__enormlz(ei)		left-justify the significand
 *	__eshdn1( ai )		shift significand and guards down 1 bit
 *	__eshdn8( ai )		shift down 8 bits
 *	__eshdn6( ai )		shift down 16 bits
 *	__eshift( ai, n )		shift ai n bits up (or down if n < 0)
 *	__eshup1( ai )		shift significand and guards up 1 bit
 *	__eshup8( ai )		shift up 8 bits
 *	__eshup6( ai )		shift up 16 bits
 *	__esubm( ai, bi )		subtract significands, bi = bi - ai
 *
 *
 * The result is always normalized and rounded to NI-4 word precision
 * after each arithmetic operation.
 *
 * Exception flags are NOT fully supported.
 *
 * Define INFINITY in mconf.h for support of infinity; otherwise a
 * saturation arithmetic is implemented.
 *
 * Define NANS for support of Not-a-Number items; otherwise the
 * arithmetic will never produce a NaN output, and might be confused
 * by a NaN input.
 * If NaN's are supported, the output of ecmp(a,b) is -2 if
 * either a or b is a NaN. This means asking if(ecmp(a,b) < 0)
 * may not be legitimate. Use if(ecmp(a,b) == -1) for less-than
 * if in doubt.
 * Signaling NaN's are NOT supported; they are treated the same
 * as quiet NaN's.
 *
 * Denormals are always supported here where appropriate (e.g., not
 * for conversion to DEC numbers).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <locale.h>
#include <ctype.h>

#undef alloca
#define alloca __builtin_alloca

/* Don't build non-ANSI _IO_ldtoa.  It is not thread safe. */ 
#ifndef USE_LDTOA
#define USE_LDTOA 0
#endif


 /* Number of 16 bit words in external x type format */
#define NE 6

 /* Number of 16 bit words in internal format */
#define NI (NE+3)

 /* Array offset to exponent */
#define E 1

 /* Array offset to high guard word */
#define M 2

 /* Number of bits of precision */
#define NBITS ((NI-4)*16)

 /* Maximum number of decimal digits in ASCII conversion
  * = NBITS*log10(2)
  */
#define NDEC (NBITS*8/27)

 /* The exponent of 1.0 */
#define EXONE (0x3fff)


#define mtherr(fname, code)


extern long double strtold (const char * __restrict__ s, char ** __restrict__ se);
extern int __asctoe64(const char * __restrict__ ss,
		      short unsigned int * __restrict__ y);
extern void __emul(const short unsigned int *  a,
		   const short unsigned int *  b,
		   short unsigned int * c);
extern int __ecmp(const short unsigned int * __restrict__ a,
		  const short unsigned int *  __restrict__ b);
extern int __enormlz(short unsigned int *x);
extern int __eshift(short unsigned int *x, int sc);
extern void __eaddm(const short unsigned int  *  __restrict__  x,
		    short unsigned int *  __restrict__  y);
extern void __esubm(const short unsigned int * __restrict__  x,
		    short unsigned int *  __restrict__ y);
extern void __emdnorm(short unsigned int *s, int lost, int subflg,
		      int exp, int rcntrl, const int rndprc);
extern void __toe64(short unsigned int *  __restrict__  a,
		    short unsigned int *  __restrict__  b);
extern int __edivm(short unsigned int *  __restrict__  den,
		   short unsigned int * __restrict__  num);
extern int __emulm(const short unsigned int *  __restrict__ a,
		   short unsigned int *  __restrict__ b);
extern void __emovi(const short unsigned int * __restrict__ a,
		    short unsigned int * __restrict__ b);
extern void __emovo(const short unsigned int * __restrict__ a,
		    short unsigned int * __restrict__ b);

#if USE_LDTOA

extern char * _IO_ldtoa(long double, int, int, int *, int *, char **);
extern void _IO_ldtostr(long double *x, char *string, int ndigs,
			int flags, char fmt);

extern void __eiremain(short unsigned int * __restrict__ den,
		       short unsigned int *__restrict__ num,
		       short unsigned int *__restrict__ equot);
extern void __efloor(short unsigned int *x, short unsigned int *y);
extern void __eadd1(const short unsigned int * __restrict__ a,
		    const short unsigned int * __restrict__ b,
		    short unsigned int * __restrict__ c,
		    int subflg);
extern void __esub(const short unsigned int *a, const short unsigned int *b,
		   short unsigned int *c);
extern void __ediv(const short unsigned int *a, const short unsigned int *b,
		   short unsigned int *c);
extern void __e64toe(short unsigned int *pe, short unsigned int *y);


#endif

static  __inline__ int __eisneg(const short unsigned int *x);
static  __inline__ int __eisinf(const short unsigned int *x);
static __inline__ int __eisnan(const short unsigned int *x);
static __inline__ int __eiszero(const short unsigned int *a);
static __inline__ void __emovz(register const short unsigned int * __restrict__ a,
			       register short unsigned int * __restrict__ b);
static __inline__ void __eclear(register short unsigned int *x);
static __inline__ void __ecleaz(register short unsigned int *xi);
static __inline__ void __ecleazs(register short unsigned int *xi);
static  __inline__ int __eiisinf(const short unsigned int *x);
static __inline__ int __eiisnan(const short unsigned int *x);
static __inline__ int __eiiszero(const short unsigned int *x);
static __inline__ void __enan_64(short unsigned int *nanptr);
static __inline__ void __enan_NBITS (short unsigned int *nanptr);
static __inline__ void __enan_NI16 (short unsigned int *nanptr);
static __inline__ void __einfin(register short unsigned int *x);
static __inline__ void __eneg(short unsigned int *x);
static __inline__ void __eshup1(register short unsigned int *x);
static __inline__ void __eshup8(register short unsigned int *x);
static __inline__ void __eshup6(register short unsigned int *x);
static __inline__ void __eshdn1(register short unsigned int *x);
static __inline__ void __eshdn8(register short unsigned int *x);
static __inline__ void __eshdn6(register short unsigned int *x);



/* Intel IEEE, low order words come first:
 */
#define IBMPC 1

/* Define 1 for ANSI C atan2() function
 * See atan.c and clog.c.
 */
#define ANSIC 1

/*define VOLATILE volatile*/
#define VOLATILE

/* For 12-byte long doubles on an i386, pad a 16-bit short 0
 * to the end of real constants initialized by integer arrays.
 *
 * #define XPD 0,
 *
 * Otherwise, the type is 10 bytes long and XPD should be
 * defined blank.
 *
 * #define XPD
 */
#define XPD 0,
/* #define XPD */
#define NANS 1

/* NaN's require infinity support. */
#ifdef NANS
#ifndef INFINITY
#define INFINITY
#endif
#endif

/* This handles 64-bit long ints. */
#define LONGBITS (8 * sizeof(long))


#define NTEN 12
#define MAXP 4096

/*
; Clear out entire external format number.
;
; unsigned short x[];
; eclear( x );
*/

static __inline__ void __eclear(register short unsigned int *x)
{
	memset(x, 0, NE * sizeof(unsigned short));
}


/* Move external format number from a to b.
 *
 * emov( a, b );
 */

static __inline__ void __emov(register const short unsigned int * __restrict__ a,
			      register short unsigned int * __restrict__ b)
{
	memcpy(b, a, NE * sizeof(unsigned short));
}


/*
;	Negate external format number
;
;	unsigned short x[NE];
;	eneg( x );
*/

static __inline__ void __eneg(short unsigned int *x)
{
#ifdef NANS
	if (__eisnan(x))
		return;
#endif
	x[NE-1] ^= 0x8000; /* Toggle the sign bit */
}


/* Return 1 if external format number is negative,
 * else return zero.
 */
static __inline__ int __eisneg(const short unsigned int *x)
{
#ifdef NANS
	if (__eisnan(x))
		return (0);
#endif
	if (x[NE-1] & 0x8000)
		return (1);
	else
		return (0);
}


/* Return 1 if external format number has maximum possible exponent,
 * else return zero.
 */
static __inline__ int __eisinf(const short unsigned int *x)
{
	if ((x[NE - 1] & 0x7fff) == 0x7fff)
	{
#ifdef NANS
		if (__eisnan(x))
			return (0);
#endif
		return (1);
	}
	else
		return (0);
}

/* Check if e-type number is not a number.
 */
static __inline__ int __eisnan(const short unsigned int *x)
{
#ifdef NANS
	int i;
	/* NaN has maximum __exponent */
	if ((x[NE - 1] & 0x7fff) == 0x7fff)
		/* ... and non-zero significand field. */
		for (i = 0; i < NE - 1; i++)
		{
			if (*x++ != 0)
				return (1);
		}
#endif
	return (0);
}

/*
; Fill __entire number, including __exponent and significand, with
; largest possible number.  These programs implement a saturation
; value that is an ordinary, legal number.  A special value
; "infinity" may also be implemented; this would require tests
; for that value and implementation of special rules for arithmetic
; operations involving inifinity.
*/

static __inline__ void __einfin(register short unsigned int *x)
{
	register int i;
#ifdef INFINITY
	for (i = 0; i < NE - 1; i++)
		*x++ = 0;
	*x |= 32767;
#else
	for (i = 0; i < NE - 1; i++)
		*x++ = 0xffff;
	*x |= 32766;
	*(x - 5) = 0;
#endif
}

/* Clear out internal format number.
 */

static __inline__ void __ecleaz(register short unsigned int *xi)
{
	memset(xi, 0, NI * sizeof(unsigned short));
}

/* same, but don't touch the sign. */

static __inline__ void __ecleazs(register short unsigned int *xi)
{
	++xi;
	memset(xi, 0, (NI-1) * sizeof(unsigned short));
}

/* Move internal format number from a to b.
 */
static __inline__ void __emovz(register const short unsigned int * __restrict__ a,
			       register short unsigned int * __restrict__ b)
{
	memcpy(b, a, (NI-1) * sizeof(unsigned short));
	b[NI - 1] = 0;
}

/* Return nonzero if internal format number is a NaN.
 */

static __inline__ int __eiisnan (const short unsigned int *x)
{
	int i;

	if ((x[E] & 0x7fff) == 0x7fff)
	{
		for (i = M + 1; i < NI; i++ )
		{
			if (x[i] != 0)
				return (1);
		}
	}
	return (0);
}

/* Return nonzero if external format number is zero. */

static __inline__ int
__eiszero(const short unsigned int * a)
{
  union {
    long double ld;
    unsigned short sh[8];
  } av;
  av.ld = 0.0;
  memcpy (av.sh, a, 12);
  if (av.ld == 0.0)
    return (1);
  return (0);
}

/* Return nonzero if internal format number is zero. */

static __inline__ int
__eiiszero(const short unsigned int * ai)
{
	int i;
	/* skip the sign word */
	for (i = 1; i < NI - 1; i++ )
	{
		if (ai[i] != 0)
			return (0);
	}
	return (1);
}


/* Return nonzero if internal format number is infinite. */

static __inline__ int 
__eiisinf (const unsigned short *x)
{
#ifdef NANS
	if (__eiisnan (x))
		return (0);
#endif
	if ((x[E] & 0x7fff) == 0x7fff)
		return (1);
	return (0);
}

/*
;	Compare significands of numbers in internal format.
;	Guard words are included in the comparison.
;
;	unsigned short a[NI], b[NI];
;	cmpm( a, b );
;
;	for the significands:
;	returns	+1 if a > b
;		 0 if a == b
;		-1 if a < b
*/
static __inline__ int __ecmpm(register const short unsigned int * __restrict__ a,
			      register const short unsigned int * __restrict__ b)
{
	int i;

	a += M; /* skip up to significand area */
	b += M;
	for (i = M; i < NI; i++)
	{
		if( *a++ != *b++ )
		goto difrnt;
	}
	return(0);

  difrnt:
	if ( *(--a) > *(--b) )
		return (1);
	else
		return (-1);
}


/*
;	Shift significand down by 1 bit
*/

static __inline__ void __eshdn1(register short unsigned int *x)
{
	register unsigned short bits;
	int i;

	x += M;	/* point to significand area */

	bits = 0;
	for (i = M; i < NI; i++ )
	{
		if (*x & 1)
			bits |= 1;
		*x >>= 1;
		if (bits & 2)
			*x |= 0x8000;
		bits <<= 1;
		++x;
	}
}

/*
;	Shift significand up by 1 bit
*/

static __inline__ void __eshup1(register short unsigned int *x)
{
	register unsigned short bits;
	int i;

	x += NI-1;
	bits = 0;

	for (i = M; i < NI; i++)
	{
		if (*x & 0x8000)
			bits |= 1;
		*x <<= 1;
		if (bits & 2)
			*x |= 1;
		bits <<= 1;
		--x;
	}
}


/*
;	Shift significand down by 8 bits
*/

static __inline__ void __eshdn8(register short unsigned int *x)
{
	register unsigned short newbyt, oldbyt;
	int i;

	x += M;
	oldbyt = 0;
	for (i = M; i < NI; i++)
	{
		newbyt = *x << 8;
		*x >>= 8;
		*x |= oldbyt;
		oldbyt = newbyt;
		++x;
	}
}

/*
;	Shift significand up by 8 bits
*/

static __inline__ void __eshup8(register short unsigned int *x)
{
	int i;
	register unsigned short newbyt, oldbyt;

	x += NI - 1;
	oldbyt = 0;

	for (i = M; i < NI; i++)
	{
		newbyt = *x >> 8;
		*x <<= 8;
		*x |= oldbyt;
		oldbyt = newbyt;
		--x;
	}
}

/*
;	Shift significand up by 16 bits
*/

static __inline__ void __eshup6(register short unsigned int *x)
{
	int i;
	register unsigned short *p;

	p = x + M;
	x += M + 1;

	for (i = M; i < NI - 1; i++)
		*p++ = *x++;

	*p = 0;
}

/*
;	Shift significand down by 16 bits
*/

static __inline__ void __eshdn6(register short unsigned int *x)
{
	int i;
	register unsigned short *p;

	x += NI - 1;
	p = x + 1;

	for (i = M; i < NI - 1; i++)
		*(--p) = *(--x);

	*(--p) = 0;
}

/*
;	Add significands
;	x + y replaces y
*/

static __inline__ void __enan_64(unsigned short* nanptr)
{
	int i;
	for (i = 0; i < 3; i++)
		*nanptr++ = 0;
	*nanptr++ = 0xc000;
	*nanptr++ = 0x7fff;
	*nanptr = 0;
	return;
}

static __inline__ void __enan_NBITS(unsigned short* nanptr)
{
	int i;
	for (i = 0; i < NE - 2; i++)
		*nanptr++ = 0;
	*nanptr++ = 0xc000;
	*nanptr = 0x7fff;
	return;
}

static __inline__ void __enan_NI16(unsigned short* nanptr)
{
	int i;
	*nanptr++ = 0;
	*nanptr++ = 0x7fff;
	*nanptr++ = 0;
	*nanptr++ = 0xc000;
	for (i = 4; i < NI; i++)
		*nanptr++ = 0;
	return;
}

#endif /* _CEPHES_EMATH_H */

