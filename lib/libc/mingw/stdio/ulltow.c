/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <stdlib.h>

wchar_t* ulltow(unsigned long long _n, wchar_t * _w, int _i)
	{ return _ui64tow (_n, _w, _i); }
