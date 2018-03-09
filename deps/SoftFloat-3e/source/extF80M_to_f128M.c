
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

void extF80M_to_f128M( const extFloat80_t *aPtr, float128_t *zPtr )
{

    *zPtr = extF80_to_f128( *aPtr );

}

#else

void extF80M_to_f128M( const extFloat80_t *aPtr, float128_t *zPtr )
{
    const struct extFloat80M *aSPtr;
    uint32_t *zWPtr;
    uint_fast16_t uiA64;
    bool sign;
    int32_t exp;
    uint64_t sig;
    struct commonNaN commonNaN;
    uint32_t uiZ96;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aSPtr = (const struct extFloat80M *) aPtr;
    zWPtr = (uint32_t *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    sign = signExtF80UI64( uiA64 );
    exp  = expExtF80UI64( uiA64 );
    sig = aSPtr->signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    zWPtr[indexWord( 4, 0 )] = 0;
    if ( exp == 0x7FFF ) {
        if ( sig & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) {
            softfloat_extF80MToCommonNaN( aSPtr, &commonNaN );
            softfloat_commonNaNToF128M( &commonNaN, zWPtr );
            return;
        }
        uiZ96 = packToF128UI96( sign, 0x7FFF, 0 );
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp ) --exp;
    if ( ! (sig & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sig ) {
            uiZ96 = packToF128UI96( sign, 0, 0 );
            goto uiZ;
        }
        exp += softfloat_normExtF80SigM( &sig );
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    zWPtr[indexWord( 4, 1 )] = (uint32_t) sig<<17;
    sig >>= 15;
    zWPtr[indexWord( 4, 2 )] = sig;
    if ( exp < 0 ) {
        zWPtr[indexWordHi( 4 )] = sig>>32;
        softfloat_shiftRight96M(
            &zWPtr[indexMultiwordHi( 4, 3 )],
            -exp,
            &zWPtr[indexMultiwordHi( 4, 3 )]
        );
        exp = 0;
        sig = (uint64_t) zWPtr[indexWordHi( 4 )]<<32;
    }
    zWPtr[indexWordHi( 4 )] = packToF128UI96( sign, exp, sig>>32 );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 uiZ:
    zWPtr[indexWord( 4, 3 )] = uiZ96;
    zWPtr[indexWord( 4, 2 )] = 0;
    zWPtr[indexWord( 4, 1 )] = 0;

}

#endif

