/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <stdlib.h>

char* ulltoa(unsigned long long _n, char * _c, int _i)
	{ return _ui64toa (_n, _c, _i); }
