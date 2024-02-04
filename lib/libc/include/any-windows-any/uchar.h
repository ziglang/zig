/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* ISO C1x Unicode utilities
 * Based on ISO/IEC SC22/WG14 9899 TR 19769 (SC22 N1326)
 *
 *  THIS SOFTWARE IS NOT COPYRIGHTED
 *
 *  This source code is offered for use in the public domain. You may
 *  use, modify or distribute it freely.
 *
 *  This code is distributed in the hope that it will be useful but
 *  WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 *  DISCLAIMED. This includes but is not limited to warranties of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 *  Date: 2011-09-27
 */

#ifndef __UCHAR_H
#define __UCHAR_H

#include <stddef.h>	/* size_t */
#include <stdint.h>	/* uint_leastXX_t */
#include <wchar.h>	/* mbstate_t */

/* Remember that g++ >= 4.4 defines these types only in c++0x mode */
#if !(defined(__cplusplus) && defined(__GXX_EXPERIMENTAL_CXX0X__)) ||	\
    !defined(__GNUC__) ||						\
    (!defined(__clang__) && (__GNUC__ < 4 || (__GNUC__ == 4 &&	__GNUC_MINOR__ < 4)))
typedef uint_least16_t char16_t;
typedef uint_least32_t char32_t;
#endif

#ifndef __STDC_UTF_16__
#define __STDC_UTF_16__ 1
#endif

#ifndef __STDC_UTF_32__
#define __STDC_UTF_32__ 1
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _UCRT

size_t mbrtoc16 (char16_t *__restrict__ pc16,
		 const char *__restrict__ s,
		 size_t n,
		 mbstate_t *__restrict__ ps);

size_t c16rtomb (char *__restrict__ s,
		 char16_t c16,
		 mbstate_t *__restrict__ ps);

size_t mbrtoc32 (char32_t *__restrict__ pc32,
		 const char *__restrict__ s,
		 size_t n,
		 mbstate_t *__restrict__ ps);

size_t c32rtomb (char *__restrict__ s,
		 char32_t c32,
		 mbstate_t *__restrict__ ps);

#endif  /* _UCRT */

#ifdef __cplusplus
}
#endif

#endif /* __UCHAR_H */

