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

size_t mbrtoc32 (char32_t *__restrict__ pc32,
		 const char *__restrict__ s,
		 size_t n,
		 mbstate_t *__restrict__ __UNUSED_PARAM(ps))
{
    if (*s == 0)
    {
	*pc32 = 0;
	return 0;
    }

    /* ASCII character - high bit unset */
    if ((*s & 0x80) == 0)
    {
	*pc32 = *s;
	return 1;
    }

    /* Multibyte chars */
    if ((*s & 0xE0) == 0xC0) /* 110xxxxx needs 2 bytes */
    {
	if (n < 2)
	    return (size_t)-2;

	*pc32 = ((s[0] & 31) << 6) | (s[1] & 63);
	return 2;
    }
    else if ((*s & 0xf0) == 0xE0) /* 1110xxxx needs 3 bytes */
    {
	if (n < 3)
	    return (size_t)-2;

	*pc32 = ((s[0] & 15) << 12) | ((s[1] & 63) << 6) | (s[2] & 63);
	return 3;
    }
    else if ((*s & 0xF8) == 0xF0) /* 11110xxx needs 4 bytes */
    {
	if (n < 4)
	    return (size_t)-2;

	*pc32 = ((s[0] & 7) << 18) | ((s[1] & 63) << 12) | ((s[2] & 63) << 6) | (s[4] & 63);
	return 4;
    }

    errno = EILSEQ;
    return (size_t)-1;
}

