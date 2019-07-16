/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
    This source code was extracted from the Q8 package created and
    placed in the PUBLIC DOMAIN by Doug Gwyn <gwyn@arl.mil>
    last edit:	1999/11/05	gwyn@arl.mil

	Implements subclause 7.8.2 of ISO/IEC 9899:1999 (E).

	This particular implementation requires the matching <inttypes.h>.
	It also assumes that character codes for A..Z and a..z are in
	contiguous ascending order; this is true for ASCII but not EBCDIC.
*/
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <inttypes.h>

/* Helper macros */

/* convert digit character to number, in any base */
#define ToNumber(c)	(isdigit(c) ? (c) - '0' : \
			 isupper(c) ? (c) - 'A' + 10 : \
			 islower(c) ? (c) - 'a' + 10 : \
			 -1		/* "invalid" flag */ \
			)
/* validate converted digit character for specific base */
#define valid(n, b)	((n) >= 0 && (n) < (b))

uintmax_t
strtoumax(nptr, endptr, base)
	register const char * __restrict__	nptr;
	char ** __restrict__			endptr;
	register int				base;
	{
	register uintmax_t	accum;	/* accumulates converted value */
	register uintmax_t	next;	/* for computing next value of accum */
	register int		n;	/* numeral from digit character */
	int			minus;	/* set iff minus sign seen (yes!) */
	int			toobig;	/* set iff value overflows */

	if ( endptr != NULL )
		*endptr = (char *)nptr;	/* in case no conversion's performed */

	if ( base < 0 || base == 1 || base > 36 )
		{
		errno = EDOM;
		return 0;		/* unspecified behavior */
		}

	/* skip initial, possibly empty sequence of white-space characters */

	while ( isspace(*nptr) )
		++nptr;

	/* process subject sequence: */

	/* optional sign (yes!) */

	if ( (minus = *nptr == '-') || *nptr == '+' )
		++nptr;

	if ( base == 0 )
        {
		if ( *nptr == '0' )
            {
			if ( nptr[1] == 'X' || nptr[1] == 'x' )
				base = 16;
			else
				base = 8;
		    }
		else
				base = 10;
		}

    /* optional "0x" or "0X" for base 16 */
    
	if ( base == 16 && *nptr == '0' && (nptr[1] == 'X' || nptr[1] == 'x') )
		nptr += 2;		/* skip past this prefix */

	/* check whether there is at least one valid digit */

	n = ToNumber(*nptr);
	++nptr;

	if ( !valid(n, base) )
		return 0;		/* subject seq. not of expected form */

	accum = n;

	for ( toobig = 0; n = ToNumber(*nptr), valid(n, base); ++nptr )
		if ( accum > UINTMAX_MAX / base + 1	/* major wrap-around */
		  || (next = base * accum + n) < accum	/* minor wrap-around */
		   )
			toobig = 1;	/* but keep scanning */
		else
			accum = next;

	if ( endptr != NULL )
		*endptr = (char *)nptr;	/* points to first not-valid-digit */

	if ( toobig )
		{
		errno = ERANGE;
		return UINTMAX_MAX;
		}
	else
		return minus ? -accum : accum;	/* (yes!) */
	}

unsigned long long __attribute__ ((alias ("strtoumax")))
strtoull (const char* __restrict__ nptr, char ** __restrict__ endptr, int base);
