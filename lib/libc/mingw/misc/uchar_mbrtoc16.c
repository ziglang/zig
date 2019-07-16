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

#include <errno.h>
#include <uchar.h>

size_t mbrtoc16 (char16_t *__restrict__ pc16,
		 const char *__restrict__ s,
		 size_t n,
		 mbstate_t *__restrict__ state)
{
/* wchar_t should compatible to char16_t on Windows */
    return mbrtowc((wchar_t *)pc16, s, n, state);
}

