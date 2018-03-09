
/*============================================================================

This C header file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014 The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#ifndef primitiveTypes_h
#define primitiveTypes_h 1

#include <stdint.h>

#ifdef SOFTFLOAT_FAST_INT64

#ifdef LITTLEENDIAN
struct uint128 { uint64_t v0, v64; };
struct uint64_extra { uint64_t extra, v; };
struct uint128_extra { uint64_t extra; struct uint128 v; };
#else
struct uint128 { uint64_t v64, v0; };
struct uint64_extra { uint64_t v, extra; };
struct uint128_extra { struct uint128 v; uint64_t extra; };
#endif

#endif

/*----------------------------------------------------------------------------
| These macros are used to isolate the differences in word order between big-
| endian and little-endian platforms.
*----------------------------------------------------------------------------*/
#ifdef LITTLEENDIAN
#define wordIncr 1
#define indexWord( total, n ) (n)
#define indexWordHi( total ) ((total) - 1)
#define indexWordLo( total ) 0
#define indexMultiword( total, m, n ) (n)
#define indexMultiwordHi( total, n ) ((total) - (n))
#define indexMultiwordLo( total, n ) 0
#define indexMultiwordHiBut( total, n ) (n)
#define indexMultiwordLoBut( total, n ) 0
#define INIT_UINTM4( v3, v2, v1, v0 ) { v0, v1, v2, v3 }
#else
#define wordIncr -1
#define indexWord( total, n ) ((total) - 1 - (n))
#define indexWordHi( total ) 0
#define indexWordLo( total ) ((total) - 1)
#define indexMultiword( total, m, n ) ((total) - 1 - (m))
#define indexMultiwordHi( total, n ) 0
#define indexMultiwordLo( total, n ) ((total) - (n))
#define indexMultiwordHiBut( total, n ) 0
#define indexMultiwordLoBut( total, n ) (n)
#define INIT_UINTM4( v3, v2, v1, v0 ) { v3, v2, v1, v0 }
#endif

#endif

