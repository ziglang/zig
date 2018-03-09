
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
 extF80M_rem(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{

    *zPtr = extF80_rem( *aPtr, *bPtr );

}

#else

void
 extF80M_rem(
     const extFloat80_t *aPtr, const extFloat80_t *bPtr, extFloat80_t *zPtr )
{
    const struct extFloat80M *aSPtr, *bSPtr;
    struct extFloat80M *zSPtr;
    uint_fast16_t uiA64;
    int32_t expA, expB;
    uint64_t x64;
    bool signRem;
    uint64_t sigA;
    int32_t expDiff;
    uint32_t rem[3], x[3], sig32B, q, recip32, rem2[3], *remPtr, *altRemPtr;
    uint32_t *newRemPtr, wordMeanRem;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aSPtr = (const struct extFloat80M *) aPtr;
    bSPtr = (const struct extFloat80M *) bPtr;
    zSPtr = (struct extFloat80M *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    expA = expExtF80UI64( uiA64 );
    expB = expExtF80UI64( bSPtr->signExp );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (expA == 0x7FFF) || (expB == 0x7FFF) ) {
        if ( softfloat_tryPropagateNaNExtF80M( aSPtr, bSPtr, zSPtr ) ) return;
        if ( expA == 0x7FFF ) goto invalid;
        /*--------------------------------------------------------------------
        | If we get here, then argument b is an infinity and `expB' is 0x7FFF;
        | Doubling `expB' is an easy way to ensure that `expDiff' later is
        | less than -1, which will result in returning a canonicalized version
        | of argument a.
        *--------------------------------------------------------------------*/
        expB += expB;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expB ) expB = 1;
    x64 = bSPtr->signif;
    if ( ! (x64 & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! x64 ) goto invalid;
        expB += softfloat_normExtF80SigM( &x64 );
    }
    signRem = signExtF80UI64( uiA64 );
    if ( ! expA ) expA = 1;
    sigA = aSPtr->signif;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigA ) {
            expA = 0;
            goto copyA;
        }
        expA += softfloat_normExtF80SigM( &sigA );
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expA - expB;
    if ( expDiff < -1 ) goto copyA;
    rem[indexWord( 3, 2 )] = sigA>>34;
    rem[indexWord( 3, 1 )] = sigA>>2;
    rem[indexWord( 3, 0 )] = (uint32_t) sigA<<30;
    x[indexWord( 3, 0 )] = (uint32_t) x64<<30;
    sig32B = x64>>32;
    x64 >>= 2;
    x[indexWord( 3, 2 )] = x64>>32;
    x[indexWord( 3, 1 )] = x64;
    if ( expDiff < 1 ) {
        if ( expDiff ) {
            --expB;
            softfloat_add96M( x, x, x );
            q = 0;
        } else {
            q = (softfloat_compare96M( x, rem ) <= 0);
            if ( q ) softfloat_sub96M( rem, x, rem );
        }
    } else {
        recip32 = softfloat_approxRecip32_1( sig32B );
        expDiff -= 30;
        for (;;) {
            x64 = (uint64_t) rem[indexWordHi( 3 )] * recip32;
            if ( expDiff < 0 ) break;
            q = (x64 + 0x80000000)>>32;
            softfloat_remStep96MBy32( rem, 29, x, q, rem );
            if ( rem[indexWordHi( 3 )] & 0x80000000 ) {
                softfloat_add96M( rem, x, rem );
            }
            expDiff -= 29;
        }
        /*--------------------------------------------------------------------
        | (`expDiff' cannot be less than -29 here.)
        *--------------------------------------------------------------------*/
        q = (uint32_t) (x64>>32)>>(~expDiff & 31);
        softfloat_remStep96MBy32( rem, expDiff + 30, x, q, rem );
        if ( rem[indexWordHi( 3 )] & 0x80000000 ) {
            remPtr = rem;
            altRemPtr = rem2;
            softfloat_add96M( remPtr, x, altRemPtr );
            goto selectRem;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    remPtr = rem;
    altRemPtr = rem2;
    do {
        ++q;
        newRemPtr = altRemPtr;
        softfloat_sub96M( remPtr, x, newRemPtr );
        altRemPtr = remPtr;
        remPtr = newRemPtr;
    } while ( ! (remPtr[indexWordHi( 3 )] & 0x80000000) );
 selectRem:
    softfloat_add96M( remPtr, altRemPtr, x );
    wordMeanRem = x[indexWordHi( 3 )];
    if (
        (wordMeanRem & 0x80000000)
            || (! wordMeanRem && (q & 1) && ! x[indexWord( 3, 0 )]
                    && ! x[indexWord( 3, 1 )])
    ) {
        remPtr = altRemPtr;
    }
    if ( remPtr[indexWordHi( 3 )] & 0x80000000 ) {
        signRem = ! signRem;
        softfloat_negX96M( remPtr );
    }
    softfloat_normRoundPackMToExtF80M( signRem, expB + 2, remPtr, 80, zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_invalidExtF80M( zSPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 copyA:
    if ( expA < 1 ) {
        sigA >>= 1 - expA;
        expA = 0;
    }
    zSPtr->signExp = packToExtF80UI64( signRem, expA );
    zSPtr->signif = sigA;

}

#endif

