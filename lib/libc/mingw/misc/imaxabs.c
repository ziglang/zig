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
*/
#define __CRT__NO_INLINE
#include <inttypes.h>

intmax_t
__cdecl
imaxabs (intmax_t _j)
  { return	_j >= 0 ? _j : -_j; }
intmax_t (__cdecl *__MINGW_IMP_SYMBOL(imaxabs))(intmax_t) = imaxabs;

long long __attribute__ ((alias ("imaxabs"))) __cdecl llabs (long long);
long long (__cdecl *__MINGW_IMP_SYMBOL(llabs))(long long) = llabs;

__int64 __attribute__ ((alias ("imaxabs"))) __cdecl _abs64 (__int64);
__int64 (__cdecl *__MINGW_IMP_SYMBOL(_abs64))(__int64) = _abs64;
