
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
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

#include <stdbool.h>
#include <stdint.h>
#include "platform.h"
#include "internals.h"
#include "specialize.h"
#include "softfloat.h"

#ifdef SOFTFLOAT_FAST_INT64

bool f128M_le_quiet( const float128_t *aPtr, const float128_t *bPtr )
{

    return f128_le_quiet( *aPtr, *bPtr );

}

#else

bool f128M_le_quiet( const float128_t *aPtr, const float128_t *bPtr )
{
    const uint32_t *aWPtr, *bWPtr;
    uint32_t uiA96, uiB96;
    bool signA, signB;
    uint32_t wordA, wordB;

    aWPtr = (const uint32_t *) aPtr;
    bWPtr = (const uint32_t *) bPtr;
    if ( softfloat_isNaNF128M( aWPtr ) || softfloat_isNaNF128M( bWPtr ) ) {
        if ( f128M_isSignalingNaN( aPtr ) || f128M_isSignalingNaN( bPtr ) ) {
            softfloat_raiseFlags( softfloat_flag_invalid );
        }
        return false;
    }
    uiA96 = aWPtr[indexWordHi( 4 )];
    uiB96 = bWPtr[indexWordHi( 4 )];
    signA = signF128UI96( uiA96 );
    signB = signF128UI96( uiB96 );
    if ( signA != signB ) {
        if ( signA ) return true;
        if ( (uiA96 | uiB96) & 0x7FFFFFFF ) return false;
        wordA = aWPtr[indexWord( 4, 2 )];
        wordB = bWPtr[indexWord( 4, 2 )];
        if ( wordA | wordB ) return false;
        wordA = aWPtr[indexWord( 4, 1 )];
        wordB = bWPtr[indexWord( 4, 1 )];
        if ( wordA | wordB ) return false;
        wordA = aWPtr[indexWord( 4, 0 )];
        wordB = bWPtr[indexWord( 4, 0 )];
        return ((wordA | wordB) == 0);
    }
    if ( signA ) {
        aWPtr = (const uint32_t *) bPtr;
        bWPtr = (const uint32_t *) aPtr;
    }
    return (softfloat_compare128M( aWPtr, bWPtr ) <= 0);

}

#endif

