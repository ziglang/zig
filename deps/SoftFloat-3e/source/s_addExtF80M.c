
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

void
 softfloat_addExtF80M(
     const struct extFloat80M *aSPtr,
     const struct extFloat80M *bSPtr,
     struct extFloat80M *zSPtr,
     bool negateB
 )
{
    uint32_t uiA64;
    int32_t expA;
    uint32_t uiB64;
    int32_t expB;
    uint32_t uiZ64;
    bool signZ, signB;
    const struct extFloat80M *tempSPtr;
    uint64_t sigZ, sigB;
    void
     (*roundPackRoutinePtr)(
         bool, int32_t, uint32_t *, uint_fast8_t, struct extFloat80M * );
    int32_t expDiff;
    uint32_t extSigX[3], sigZExtra;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    expA = expExtF80UI64( uiA64 );
    uiB64 = bSPtr->signExp;
    expB = expExtF80UI64( uiB64 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (expA == 0x7FFF) || (expB == 0x7FFF) ) {
        if ( softfloat_tryPropagateNaNExtF80M( aSPtr, bSPtr, zSPtr ) ) return;
        uiZ64 = uiA64;
        if ( expB == 0x7FFF ) {
            uiZ64 = uiB64 ^ packToExtF80UI64( negateB, 0 );
            if ( (expA == 0x7FFF) && (uiZ64 != uiA64) ) {
                softfloat_invalidExtF80M( zSPtr );
                return;
            }
        }
        zSPtr->signExp = uiZ64;
        zSPtr->signif = UINT64_C( 0x8000000000000000 );
        return;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    signZ = signExtF80UI64( uiA64 );
    signB = signExtF80UI64( uiB64 ) ^ negateB;
    negateB = (signZ != signB);
    if ( expA < expB ) {
        signZ = signB;
        expA = expB;
        expB = expExtF80UI64( uiA64 );
        tempSPtr = aSPtr;
        aSPtr = bSPtr;
        bSPtr = tempSPtr;
    }
    if ( ! expB ) {
        expB = 1;
        if ( ! expA ) expA = 1;
    }
    sigZ = aSPtr->signif;
    sigB = bSPtr->signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    roundPackRoutinePtr = softfloat_roundPackMToExtF80M;
    expDiff = expA - expB;
    if ( expDiff ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        extSigX[indexWord( 3, 2 )] = sigB>>32;
        extSigX[indexWord( 3, 1 )] = sigB;
        extSigX[indexWord( 3, 0 )] = 0;
        softfloat_shiftRightJam96M( extSigX, expDiff, extSigX );
        sigB =
            (uint64_t) extSigX[indexWord( 3, 2 )]<<32
                | extSigX[indexWord( 3, 1 )];
        if ( negateB ) {
            sigZ -= sigB;
            sigZExtra = extSigX[indexWordLo( 3 )];
            if ( sigZExtra ) {
                --sigZ;
                sigZExtra = -sigZExtra;
            }
            if ( ! (sigZ & UINT64_C( 0x8000000000000000 )) ) {
                if ( sigZ & UINT64_C( 0x4000000000000000 ) ) {
                    --expA;
                    sigZ = sigZ<<1 | sigZExtra>>31;
                    sigZExtra <<= 1;
                } else {
                    roundPackRoutinePtr = softfloat_normRoundPackMToExtF80M;
                }
            }
        } else {
            sigZ += sigB;
            if ( sigZ & UINT64_C( 0x8000000000000000 ) ) goto sigZ;
            sigZExtra = (uint32_t) sigZ<<31 | (extSigX[indexWordLo( 3 )] != 0);
            goto completeNormAfterAdd;
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        sigZExtra = 0;
        if ( negateB ) {
            if ( sigZ < sigB ) {
                signZ = ! signZ;
                sigZ = sigB - sigZ;
            } else {
                sigZ -= sigB;
                if ( ! sigZ ) {
                    signZ = (softfloat_roundingMode == softfloat_round_min);
                    zSPtr->signExp = packToExtF80UI64( signZ, 0 );
                    zSPtr->signif = 0;
                    return;
                }
            }
            roundPackRoutinePtr = softfloat_normRoundPackMToExtF80M;
        } else {
            sigZ += sigB;
            if ( sigZ < sigB ) {
                sigZExtra = (uint32_t) sigZ<<31;
 completeNormAfterAdd:
                ++expA;
                sigZ = UINT64_C( 0x8000000000000000 ) | sigZ>>1;
            } else {
                if ( ! (sigZ & UINT64_C( 0x8000000000000000 )) ) {
                    roundPackRoutinePtr = softfloat_normRoundPackMToExtF80M;
                }
            }
        }
    }
    extSigX[indexWord( 3, 0 )] = sigZExtra;
 sigZ:
    extSigX[indexWord( 3, 2 )] = sigZ>>32;
    extSigX[indexWord( 3, 1 )] = sigZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 roundPack:
    (*roundPackRoutinePtr)(
        signZ, expA, extSigX, extF80_roundingPrecision, zSPtr );

}

