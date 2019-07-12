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
int mbsinit(const mbstate_t *ps)
{
	return 1;			/* don't have shift states */
}
#endif

int __cdecl mbsinit(const mbstate_t *_P)
{
	return (!_P || *_P == 0);
}

