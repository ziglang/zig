
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

void
 extF80M_mul(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{

    *zPtr = extF80_mul( *aPtr, *bPtr );

}

#else

void
 extF80M_mul(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{
    const struct extFloat80M *aSPtr, *bSPtr;
    struct extFloat80M *zSPtr;
    uint_fast16_t uiA64;
    int32_t expA;
    uint_fast16_t uiB64;
    int32_t expB;
    bool signZ;
    uint_fast16_t exp, uiZ64;
    uint64_t uiZ0, sigA, sigB;
    int32_t expZ;
    uint32_t sigProd[4], *extSigZPtr;

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
        if (
               (! aSPtr->signif && (expA != 0x7FFF))
            || (! bSPtr->signif && (expB != 0x7FFF))
        ) {
            softfloat_invalidExtF80M( zSPtr );
            return;
        }
        uiZ64 = packToExtF80UI64( signZ, 0x7FFF );
        uiZ0  = UINT64_C( 0x8000000000000000 );
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) expA = 1;
    sigA = aSPtr->signif;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigA ) goto zero;
        expA += softfloat_normExtF80SigM( &sigA );
    }
    if ( ! expB ) expB = 1;
    sigB = bSPtr->signif;
    if ( ! (sigB & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigB ) goto zero;
        expB += softfloat_normExtF80SigM( &sigB );
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA + expB - 0x3FFE;
    softfloat_mul64To128M( sigA, sigB, sigProd );
    if ( sigProd[indexWordLo( 4 )] ) sigProd[indexWord( 4, 1 )] |= 1;
    extSigZPtr = &sigProd[indexMultiwordHi( 4, 3 )];
    if ( sigProd[indexWordHi( 4 )] < 0x80000000 ) {
        --expZ;
        softfloat_add96M( extSigZPtr, extSigZPtr, extSigZPtr );
    }
    softfloat_roundPackMToExtF80M(
        signZ, expZ, extSigZPtr, extF80_roundingPrecision, zSPtr );
    return;
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

