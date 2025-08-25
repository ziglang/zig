/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#define __CRT__NO_INLINE
#include	<wchar.h>

#if 0
wchar_t *
wmemset(s, c, n)
	register wchar_t	*s;
	register wchar_t	c;
	register size_t		n;
{
	wchar_t			*orig_s = s;

	if ( s != NULL )
		for ( ; n > 0; --n )
			*s++ = c;

	return orig_s;
}
#endif

wchar_t *__cdecl wmemset(wchar_t *_S,wchar_t _C,size_t _N)
{
	wchar_t *_Su = _S;
	for ( ; 0 < _N; ++_Su, --_N)
		 *_Su = _C;
	return (_S);
}

