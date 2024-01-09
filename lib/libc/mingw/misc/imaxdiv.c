/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
    This source code was extracted from the Q8 package created and
    placed in the PUBLIC DOMAIN by Doug Gwyn <gwyn@arl.mil>
    last edit:	1999/11/05	gwyn@arl.mil


	last edit:	1999/11/05	gwyn@arl.mil

	Implements subclause 7.8.2 of ISO/IEC 9899:1999 (E).

*/

#include	<inttypes.h>
#include	<stdlib.h>

imaxdiv_t
__cdecl
imaxdiv(intmax_t numer, intmax_t denom)
{
  imaxdiv_t	result;
  result.quot = numer / denom;
  result.rem = numer % denom;
  return result;
}
imaxdiv_t (__cdecl *__MINGW_IMP_SYMBOL(imaxdiv))(intmax_t, intmax_t) = imaxdiv;

lldiv_t __attribute__ ((alias ("imaxdiv")))
__cdecl
lldiv (long long, long long); 
lldiv_t (__cdecl *__MINGW_IMP_SYMBOL(lldiv))(long long, long long) = lldiv;
