/****************************************************************

The author of this software is David M. Gay.

Copyright (C) 1998 by Lucent Technologies
All Rights Reserved

Permission to use, copy, modify, and distribute this software and
its documentation for any purpose and without fee is hereby
granted, provided that the above copyright notice appear in all
copies and that both that the copyright notice and this
permission notice and warranty disclaimer appear in supporting
documentation, and that the name of Lucent or any of its entities
not be used in advertising or publicity pertaining to
distribution of the software without specific, written prior
permission.

LUCENT DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.
IN NO EVENT SHALL LUCENT OR ANY OF ITS ENTITIES BE LIABLE FOR ANY
SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.

****************************************************************/

/* Please send bug reports to David M. Gay (dmg at acm dot org,
 * with " at " changed at "@" and " dot " changed to ".").	*/

#include "gdtoaimp.h"

#ifdef USE_LOCALE
#include "locale.h"
#endif

#ifndef ldus_QNAN0
#define ldus_QNAN0 0x7fff
#endif
#ifndef ldus_QNAN1
#define ldus_QNAN1 0xc000
#endif
#ifndef ldus_QNAN2
#define ldus_QNAN2 0
#endif
#ifndef ldus_QNAN3
#define ldus_QNAN3 0
#endif
#ifndef ldus_QNAN4
#define ldus_QNAN4 0
#endif

 const char *InfName[6] = { "Infinity", "infinity", "INFINITY", "Inf", "inf", "INF" };
 const char *NanName[3] = { "NaN", "nan", "NAN" };
 ULong NanDflt_Q_D2A[4] = { 0xffffffff, 0xffffffff, 0xffffffff, 0x7fffffff };
 ULong NanDflt_d_D2A[2] = { d_QNAN1, d_QNAN0 };
 ULong NanDflt_f_D2A[1] = { f_QNAN };
 ULong NanDflt_xL_D2A[3] = { 1, 0x80000000, 0x7fff0000 };
 UShort NanDflt_ldus_D2A[5] = { ldus_QNAN4, ldus_QNAN3, ldus_QNAN2, ldus_QNAN1, ldus_QNAN0 };

char *__g__fmt (char *b, char *s, char *se, int decpt, ULong sign, size_t blen)
{
	int i, j, k;
	char *be, *s0;
	size_t len;
#ifdef USE_LOCALE
#ifdef NO_LOCALE_CACHE
	char *decimalpoint = localeconv()->decimal_point;
	size_t dlen = strlen(decimalpoint);
#else
	char *decimalpoint;
	static char *decimalpoint_cache;
	static size_t dlen;
	if (!(s0 = decimalpoint_cache)) {
		s0 = localeconv()->decimal_point;
		dlen = strlen(s0);
		if ((decimalpoint_cache = (char*)MALLOC(strlen(s0) + 1))) {
			strcpy(decimalpoint_cache, s0);
			s0 = decimalpoint_cache;
		}
	}
	decimalpoint = s0;
#endif
#else
#define dlen 0
#endif
	s0 = s;
	len = (se-s) + dlen + 6; /* 6 = sign + e+dd + trailing null */
	if (blen < len)
		goto ret0;
	be = b + blen - 1;
	if (sign)
		*b++ = '-';
	if (decpt <= -4 || decpt > se - s + 5) {
		*b++ = *s++;
		if (*s) {
#ifdef USE_LOCALE
			while((*b = *decimalpoint++))
				++b;
#else
			*b++ = '.';
#endif
			while((*b = *s++) !=0)
				b++;
		}
		*b++ = 'e';
		/* sprintf(b, "%+.2d", decpt - 1); */
		if (--decpt < 0) {
			*b++ = '-';
			decpt = -decpt;
		}
		else
			*b++ = '+';
		for(j = 2, k = 10; 10*k <= decpt; j++, k *= 10){}
		for(;;) {
			i = decpt / k;
			if (b >= be)
				goto ret0;
			*b++ = i + '0';
			if (--j <= 0)
				break;
			decpt -= i*k;
			decpt *= 10;
		}
		*b = 0;
	}
	else if (decpt <= 0) {
#ifdef USE_LOCALE
		while((*b = *decimalpoint++))
			++b;
#else
		*b++ = '.';
#endif
		if (be < b - decpt + (se - s))
			goto ret0;
		for(; decpt < 0; decpt++)
			*b++ = '0';
		while((*b = *s++) != 0)
			b++;
	}
	else {
		while((*b = *s++) != 0) {
			b++;
			if (--decpt == 0 && *s) {
#ifdef USE_LOCALE
				while((*b = *decimalpoint++))
					++b;
#else
				*b++ = '.';
#endif
			}
		}
		if (b + decpt > be) {
 ret0:
			b = 0;
			goto ret;
		}
		for(; decpt > 0; decpt--)
			*b++ = '0';
		*b = 0;
	}
 ret:
	__freedtoa(s0);
	return b;
}

 char *
__add_nanbits_D2A(char *b, size_t blen, ULong *bits, int nb)
{
	ULong t;
	char *rv;
	int i, j;
	size_t L;
	static char Hexdig[16] = "0123456789abcdef";

	while(!bits[--nb])
		if (!nb)
			return b;
	L = 8*nb + 3;
	t = bits[nb];
	do ++L; while((t >>= 4));
	if (L > blen)
		return b;
	b += L;
	*--b = 0;
	rv = b;
	*--b = /*(*/ ')';
	for(i = 0; i < nb; ++i) {
		t = bits[i];
		for(j = 0; j < 8; ++j, t >>= 4)
			*--b = Hexdig[t & 0xf];
		}
	t = bits[nb];
	do *--b = Hexdig[t & 0xf]; while(t >>= 4);
	*--b = '('; /*)*/
	return rv;
	}
