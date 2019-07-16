/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#define __CRT__NO_INLINE
#include	<wchar.h>
#include	<stdio.h>

#if 0
int fwide(FILE *stream,int mode)
{
	return -1;			/* limited to byte orientation */
}
#endif

int __cdecl fwide(FILE *_F,int _M)
{
    (void)_F;
    return (_M);
}

