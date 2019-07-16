/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*	This source code was extracted from the Q8 package created and placed
    in the PUBLIC DOMAIN by Doug Gwyn <gwyn@arl.mil>
    last edit:	1999/11/05	gwyn@arl.mil

    Implements subclause 7.24 of ISO/IEC 9899:1999 (E).

	It supports an encoding where all char codes are mapped
	to the *same* code values within a wchar_t or wint_t,
	so long as no other wchar_t codes are used by the program.

*/

#define __CRT__NO_INLINE
#include	<wchar.h>

#if 0
int
wmemcmp(s1, s2, n)
	register const wchar_t	*s1;
	register const wchar_t	*s2;
	size_t				n;
{
	if ( n == 0 || s1 == s2 )
		return 0;		/* even for NULL pointers */

	if ( (s1 != NULL) != (s2 != NULL) )
		return s2 == NULL ? 1 : -1;	/* robust */

	for ( ; n > 0; ++s1, ++s2, --n )
		if ( *s1 != *s2 )
			return *s1 - *s2;

	return 0;
}
#endif

int __cdecl wmemcmp(const wchar_t *_S1,const wchar_t *_S2,size_t _N)
{
	if (_N == 0 || _S1 == _S2)
		return 0;	/* even for NULL pointers */

	if ((_S1 != NULL) != (_S2 != NULL))
		return _S2 == NULL ? 1 : -1;	/* robust */

	for ( ; 0 < _N; ++_S1, ++_S2, --_N)
		if (*_S1 != *_S2)
			return (*_S1 < *_S2 ? -1 : +1);

	return 0;
}

