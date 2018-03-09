
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2017 The Regents of the University of
California.  All rights reserved.

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

void extF80M_sqrt( const extFloat80_t *aPtr, extFloat80_t *zPtr )
{

    *zPtr = extF80_sqrt( *aPtr );

}

#else

void extF80M_sqrt( const extFloat80_t *aPtr, extFloat80_t *zPtr )
{
    const struct extFloat80M *aSPtr;
    struct extFloat80M *zSPtr;
    uint_fast16_t uiA64, signUI64;
    int32_t expA;
    uint64_t rem64;
    int32_t expZ;
    uint32_t rem96[3], sig32A, recipSqrt32, sig32Z, q;
    uint64_t sig64Z, x64;
    uint32_t rem32, term[4], rem[4], extSigZ[3];

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aSPtr = (const struct extFloat80M *) aPtr;
    zSPtr = (struct extFloat80M *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    signUI64 = uiA64 & packToExtF80UI64( 1, 0 );
    expA = expExtF80UI64( uiA64 );
    rem64 = aSPtr->signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FFF ) {
        if ( rem64 & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) {
            softfloat_propagateNaNExtF80M( aSPtr, 0, zSPtr );
            return;
        }
        if ( signUI64 ) goto invalid;
        rem64 = UINT64_C( 0x8000000000000000 );
        goto copyA;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) expA = 1;
    if ( ! (rem64 & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! rem64 ) {
            uiA64 = signUI64;
            goto copyA;
        }
        expA += softfloat_normExtF80SigM( &rem64 );
    }
    if ( signUI64 ) goto invalid;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = ((expA - 0x3FFF)>>1) + 0x3FFF;
    expA &= 1;
    softfloat_shortShiftLeft64To96M( rem64, 30 - expA, rem96 );
    sig32A = rem64>>32;
    recipSqrt32 = softfloat_approxRecipSqrt32_1( expA, sig32A );
    sig32Z = ((uint64_t) sig32A * recipSqrt32)>>32;
    if ( expA ) sig32Z >>= 1;
    rem64 =
        ((uint64_t) rem96[indexWord( 3, 2 )]<<32 | rem96[indexWord( 3, 1 )])
            - (uint64_t) sig32Z * sig32Z;
    rem96[indexWord( 3, 2 )] = rem64>>32;
    rem96[indexWord( 3, 1 )] = rem64;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    q = ((uint32_t) (rem64>>2) * (uint64_t) recipSqrt32)>>32;
    sig64Z = ((uint64_t) sig32Z<<32) + ((uint64_t) q<<3);
    term[indexWord( 3, 2 )] = 0;
    /*------------------------------------------------------------------------
    | (Repeating this loop is a rare occurrence.)
    *------------------------------------------------------------------------*/
    for (;;) {
        x64 = ((uint64_t) sig32Z<<32) + sig64Z;
        term[indexWord( 3, 1 )] = x64>>32;
        term[indexWord( 3, 0 )] = x64;
        softfloat_remStep96MBy32(
            rem96, 29, term, q, &rem[indexMultiwordHi( 4, 3 )] );
        rem32 = rem[indexWord( 4, 3 )];
        if ( ! (rem32 & 0x80000000) ) break;
        --q;
        sig64Z -= 1<<3;
    }
    rem64 = (uint64_t) rem32<<32 | rem[indexWord( 4, 2 )];
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    q = (((uint32_t) (rem64>>2) * (uint64_t) recipSqrt32)>>32) + 2;
    if ( rem64>>34 ) q += recipSqrt32;
    x64 = (uint64_t) q<<7;
    extSigZ[indexWord( 3, 0 )] = x64;
    x64 = (sig64Z<<1) + (x64>>32);
    extSigZ[indexWord( 3, 2 )] = x64>>32;
    extSigZ[indexWord( 3, 1 )] = x64;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (q & 0xFFFFFF) <= 2 ) {
        q &= ~(uint32_t) 0xFFFF;
        extSigZ[indexWordLo( 3 )] = q<<7;
        x64 = sig64Z + (q>>27);
        term[indexWord( 4, 3 )] = 0;
        term[indexWord( 4, 2 )] = x64>>32;
        term[indexWord( 4, 1 )] = x64;
        term[indexWord( 4, 0 )] = q<<5;
        rem[indexWord( 4, 0 )] = 0;
        softfloat_remStep128MBy32( rem, 28, term, q, rem );
        q = rem[indexWordHi( 4 )];
        if ( q & 0x80000000 ) {
            softfloat_sub1X96M( extSigZ );
        } else {
            if ( q || rem[indexWord( 4, 1 )] || rem[indexWord( 4, 2 )] ) {
                extSigZ[indexWordLo( 3 )] |= 1;
            }
        }
    }
    softfloat_roundPackMToExtF80M(
        0, expZ, extSigZ, extF80_roundingPrecision, zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_invalidExtF80M( zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 copyA:
    zSPtr->signExp = uiA64;
    zSPtr->signif  = rem64;

}

#endif

