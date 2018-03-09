
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016 The Regents of the University of
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

void
 extF80M_div(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{

    *zPtr = extF80_div( *aPtr, *bPtr );

}

#else

void
 extF80M_div(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{
    const struct extFloat80M *aSPtr, *bSPtr;
    struct extFloat80M *zSPtr;
    uint_fast16_t uiA64;
    int32_t expA;
    uint_fast16_t uiB64;
    int32_t expB;
    bool signZ;
    uint64_t sigA, x64;
    int32_t expZ;
    int shiftDist;
    uint32_t y[3], recip32, sigB[3];
    int ix;
    uint32_t q, qs[2];
    uint_fast16_t uiZ64;
    uint64_t uiZ0;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aSPtr = (const struct extFloat80M *) aPtr;
    bSPtr = (const struct extFloat80M *) bPtr;
    zSPtr = (struct extFloat80M *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    expA = expExtF80UI64( uiA64 );
    uiB64 = bSPtr->signExp;
    expB = expExtF80UI64( uiB64 );
    signZ = signExtF80UI64( uiA64 ) ^ signExtF80UI64( uiB64 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (expA == 0x7FFF) || (expB == 0x7FFF) ) {
        if ( softfloat_tryPropagateNaNExtF80M( aSPtr, bSPtr, zSPtr ) ) return;
        if ( expA == 0x7FFF ) {
            if ( expB == 0x7FFF ) goto invalid;
            goto infinity;
        }
        goto zero;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    sigA = aSPtr->signif;
    x64 = bSPtr->signif;
    if ( ! expB ) expB = 1;
    if ( ! (x64 & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! x64 ) {
            if ( ! sigA ) goto invalid;
            softfloat_raiseFlags( softfloat_flag_infinite );
            goto infinity;
        }
        expB += softfloat_normExtF80SigM( &x64 );
    }
    if ( ! expA ) expA = 1;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigA ) goto zero;
        expA += softfloat_normExtF80SigM( &sigA );
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA - expB + 0x3FFF;
    shiftDist = 29;
    if ( sigA < x64 ) {
        --expZ;
        shiftDist = 30;
    }
    softfloat_shortShiftLeft64To96M( sigA, shiftDist, y );
    recip32 = softfloat_approxRecip32_1( x64>>32 );
    sigB[indexWord( 3, 0 )] = (uint32_t) x64<<30;
    x64 >>= 2;
    sigB[indexWord( 3, 2 )] = x64>>32;
    sigB[indexWord( 3, 1 )] = x64;
    ix = 2;
    for (;;) {
        x64 = (uint64_t) y[indexWordHi( 3 )] * recip32;
        q = (x64 + 0x80000000)>>32;
        --ix;
        if ( ix < 0 ) break;
        softfloat_remStep96MBy32( y, 29, sigB, q, y );
        if ( y[indexWordHi( 3 )] & 0x80000000 ) {
            --q;
            softfloat_add96M( y, sigB, y );
        }
        qs[ix] = q;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ((q + 1) & 0x3FFFFF) < 2 ) {
        softfloat_remStep96MBy32( y, 29, sigB, q, y );
        if ( y[indexWordHi( 3 )] & 0x80000000 ) {
            --q;
            softfloat_add96M( y, sigB, y );
        } else if ( softfloat_compare96M( sigB, y ) <= 0 ) {
            ++q;
            softfloat_sub96M( y, sigB, y );
        }
        if (
            y[indexWordLo( 3 )] || y[indexWord( 3, 1 )] || y[indexWord( 3, 2 )]
        ) {
            q |= 1;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    x64 = (uint64_t) q<<9;
    y[indexWord( 3, 0 )] = x64;
    x64 = ((uint64_t) qs[0]<<6) + (x64>>32);
    y[indexWord( 3, 1 )] = x64;
    y[indexWord( 3, 2 )] = (qs[1]<<3) + (x64>>32);
    softfloat_roundPackMToExtF80M(
        signZ, expZ, y, extF80_roundingPrecision, zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_invalidExtF80M( zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infinity:
    uiZ64 = packToExtF80UI64( signZ, 0x7FFF );
    uiZ0  = UINT64_C( 0x8000000000000000 );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zero:
    uiZ64 = packToExtF80UI64( signZ, 0 );
    uiZ0  = 0;
 uiZ:
    zSPtr->signExp = uiZ64;
    zSPtr->signif  = uiZ0;

}

#endif

