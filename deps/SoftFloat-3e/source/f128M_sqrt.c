
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2017 The Regents of the University of
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

void f128M_sqrt( const float128_t *aPtr, float128_t *zPtr )
{

    *zPtr = f128_sqrt( *aPtr );

}

#else

void f128M_sqrt( const float128_t *aPtr, float128_t *zPtr )
{
    const uint32_t *aWPtr;
    uint32_t *zWPtr;
    uint32_t uiA96;
    bool signA;
    int32_t rawExpA;
    uint32_t rem[6];
    int32_t expA, expZ;
    uint64_t rem64;
    uint32_t sig32A, recipSqrt32, sig32Z, qs[3], q;
    uint64_t sig64Z;
    uint32_t term[5];
    uint64_t x64;
    uint32_t y[5], rem32;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aWPtr = (const uint32_t *) aPtr;
    zWPtr = (uint32_t *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA96 = aWPtr[indexWordHi( 4 )];
    signA = signF128UI96( uiA96 );
    rawExpA  = expF128UI96( uiA96 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( rawExpA == 0x7FFF ) {
        if (
            fracF128UI96( uiA96 )
                || (aWPtr[indexWord( 4, 2 )] | aWPtr[indexWord( 4, 1 )]
                        | aWPtr[indexWord( 4, 0 )])
        ) {
            softfloat_propagateNaNF128M( aWPtr, 0, zWPtr );
            return;
        }
        if ( ! signA ) goto copyA;
        goto invalid;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expA = softfloat_shiftNormSigF128M( aWPtr, 13 - (rawExpA & 1), rem );
    if ( expA == -128 ) goto copyA;
    if ( signA ) goto invalid;
    /*------------------------------------------------------------------------
    | (`sig32Z' is guaranteed to be a lower bound on the square root of
    | `sig32A', which makes `sig32Z' also a lower bound on the square root of
    | `sigA'.)
    *------------------------------------------------------------------------*/
    expZ = ((expA - 0x3FFF)>>1) + 0x3FFE;
    expA &= 1;
    rem64 = (uint64_t) rem[indexWord( 4, 3 )]<<32 | rem[indexWord( 4, 2 )];
    if ( expA ) {
        if ( ! rawExpA ) {
            softfloat_shortShiftRight128M( rem, 1, rem );
            rem64 >>= 1;
        }
        sig32A = rem64>>29;
    } else {
        sig32A = rem64>>30;
    }
    recipSqrt32 = softfloat_approxRecipSqrt32_1( expA, sig32A );
    sig32Z = ((uint64_t) sig32A * recipSqrt32)>>32;
    if ( expA ) sig32Z >>= 1;
    qs[2] = sig32Z;
    rem64 -= (uint64_t) sig32Z * sig32Z;
    rem[indexWord( 4, 3 )] = rem64>>32;
    rem[indexWord( 4, 2 )] = rem64;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    q = ((uint32_t) (rem64>>2) * (uint64_t) recipSqrt32)>>32;
    sig64Z = ((uint64_t) sig32Z<<32) + ((uint64_t) q<<3);
    term[indexWord( 4, 3 )] = 0;
    term[indexWord( 4, 0 )] = 0;
    /*------------------------------------------------------------------------
    | (Repeating this loop is a rare occurrence.)
    *------------------------------------------------------------------------*/
    for (;;) {
        x64 = ((uint64_t) sig32Z<<32) + sig64Z;
        term[indexWord( 4, 2 )] = x64>>32;
        term[indexWord( 4, 1 )] = x64;
        softfloat_remStep128MBy32( rem, 29, term, q, y );
        rem32 = y[indexWord( 4, 3 )];
        if ( ! (rem32 & 0x80000000) ) break;
        --q;
        sig64Z -= 1<<3;
    }
    qs[1] = q;
    rem64 = (uint64_t) rem32<<32 | y[indexWord( 4, 2 )];
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    q = ((uint32_t) (rem64>>2) * (uint64_t) recipSqrt32)>>32;
    if ( rem64>>34 ) q += recipSqrt32;
    sig64Z <<= 1;
    /*------------------------------------------------------------------------
    | (Repeating this loop is a rare occurrence.)
    *------------------------------------------------------------------------*/
    for (;;) {
        x64 = sig64Z + (q>>26);
        term[indexWord( 4, 2 )] = x64>>32;
        term[indexWord( 4, 1 )] = x64;
        term[indexWord( 4, 0 )] = q<<6;
        softfloat_remStep128MBy32(
            y, 29, term, q, &rem[indexMultiwordHi( 6, 4 )] );
        rem32 = rem[indexWordHi( 6 )];
        if ( ! (rem32 & 0x80000000) ) break;
        --q;
    }
    qs[0] = q;
    rem64 = (uint64_t) rem32<<32 | rem[indexWord( 6, 4 )];
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    q = (((uint32_t) (rem64>>2) * (uint64_t) recipSqrt32)>>32) + 2;
    if ( rem64>>34 ) q += recipSqrt32;
    x64 = (uint64_t) q<<27;
    y[indexWord( 5, 0 )] = x64;
    x64 = ((uint64_t) qs[0]<<24) + (x64>>32);
    y[indexWord( 5, 1 )] = x64;
    x64 = ((uint64_t) qs[1]<<21) + (x64>>32);
    y[indexWord( 5, 2 )] = x64;
    x64 = ((uint64_t) qs[2]<<18) + (x64>>32);
    y[indexWord( 5, 3 )] = x64;
    y[indexWord( 5, 4 )] = x64>>32;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (q & 0xF) <= 2 ) {
        q &= ~3;
        y[indexWordLo( 5 )] = q<<27;
        term[indexWord( 5, 4 )] = 0;
        term[indexWord( 5, 3 )] = 0;
        term[indexWord( 5, 2 )] = 0;
        term[indexWord( 5, 1 )] = q>>6;
        term[indexWord( 5, 0 )] = q<<26;
        softfloat_sub160M( y, term, term );
        rem[indexWord( 6, 1 )] = 0;
        rem[indexWord( 6, 0 )] = 0;
        softfloat_remStep160MBy32(
            &rem[indexMultiwordLo( 6, 5 )],
            14,
            term,
            q,
            &rem[indexMultiwordLo( 6, 5 )]
        );
        rem32 = rem[indexWord( 6, 4 )];
        if ( rem32 & 0x80000000 ) {
            softfloat_sub1X160M( y );
        } else {
            if (
                rem32 || rem[indexWord( 6, 0 )] || rem[indexWord( 6, 1 )]
                    || (rem[indexWord( 6, 3 )] | rem[indexWord( 6, 2 )])
            ) {
                y[indexWordLo( 5 )] |= 1;
            }
        }
    }
    softfloat_roundPackMToF128M( 0, expZ, y, zWPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_invalidF128M( zWPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 copyA:
    zWPtr[indexWordHi( 4 )] = uiA96;
    zWPtr[indexWord( 4, 2 )] = aWPtr[indexWord( 4, 2 )];
    zWPtr[indexWord( 4, 1 )] = aWPtr[indexWord( 4, 1 )];
    zWPtr[indexWord( 4, 0 )] = aWPtr[indexWord( 4, 0 )];

}

#endif

