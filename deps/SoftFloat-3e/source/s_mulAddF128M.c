
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

void
 softfloat_mulAddF128M(
     const uint32_t *aWPtr,
     const uint32_t *bWPtr,
     const uint32_t *cWPtr,
     uint32_t *zWPtr,
     uint_fast8_t op
 )
{
    uint32_t uiA96;
    int32_t expA;
    uint32_t uiB96;
    int32_t expB;
    uint32_t uiC96;
    bool signC;
    int32_t expC;
    bool signProd, prodIsInfinite;
    uint32_t *ptr, uiZ96, sigA[4];
    uint_fast8_t shiftDist;
    uint32_t sigX[5];
    int32_t expProd;
    uint32_t sigProd[8], wordSig;
    bool doSub;
    uint_fast8_t
     (*addCarryMRoutinePtr)(
         uint_fast8_t,
         const uint32_t *,
         const uint32_t *,
         uint_fast8_t,
         uint32_t *
     );
    int32_t expDiff;
    bool signZ;
    int32_t expZ;
    uint32_t *extSigPtr;
    uint_fast8_t carry;
    void (*roundPackRoutinePtr)( bool, int32_t, uint32_t *, uint32_t * );

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA96 = aWPtr[indexWordHi( 4 )];
    expA = expF128UI96( uiA96 );
    uiB96 = bWPtr[indexWordHi( 4 )];
    expB = expF128UI96( uiB96 );
    uiC96 = cWPtr[indexWordHi( 4 )];
    signC = signF128UI96( uiC96 ) ^ (op == softfloat_mulAdd_subC);
    expC = expF128UI96( uiC96 );
    signProd =
        signF128UI96( uiA96 ) ^ signF128UI96( uiB96 )
            ^ (op == softfloat_mulAdd_subProd);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    prodIsInfinite = false;
    if ( (expA == 0x7FFF) || (expB == 0x7FFF) ) {
        if ( softfloat_tryPropagateNaNF128M( aWPtr, bWPtr, zWPtr ) ) {
            goto propagateNaN_ZC;
        }
        ptr = (uint32_t *) aWPtr;
        if ( ! (uint32_t) (uiA96<<1) ) goto possibleInvalidProd;
        if ( ! (uint32_t) (uiB96<<1) ) {
            ptr = (uint32_t *) bWPtr;
     possibleInvalidProd:
            if (
                ! (ptr[indexWord( 4, 2 )] | ptr[indexWord( 4, 1 )]
                       | ptr[indexWord( 4, 0 )])
            ) {
                goto invalid;
            }
        }
        prodIsInfinite = true;
    }
    if ( expC == 0x7FFF ) {
        if (
            fracF128UI96( uiC96 )
                || (cWPtr[indexWord( 4, 2 )] | cWPtr[indexWord( 4, 1 )]
                        | cWPtr[indexWord( 4, 0 )])
        ) {
            zWPtr[indexWordHi( 4 )] = 0;
            goto propagateNaN_ZC;
        }
        if ( prodIsInfinite && (signProd != signC) ) goto invalid;
        goto copyC;
    }
    if ( prodIsInfinite ) {
        uiZ96 = packToF128UI96( signProd, 0x7FFF, 0 );
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA ) {
        sigA[indexWordHi( 4 )] = fracF128UI96( uiA96 ) | 0x00010000;
        sigA[indexWord( 4, 2 )] = aWPtr[indexWord( 4, 2 )];
        sigA[indexWord( 4, 1 )] = aWPtr[indexWord( 4, 1 )];
        sigA[indexWord( 4, 0 )] = aWPtr[indexWord( 4, 0 )];
    } else {
        expA = softfloat_shiftNormSigF128M( aWPtr, 0, sigA );
        if ( expA == -128 ) goto zeroProd;
    }
    if ( expB ) {
        sigX[indexWordHi( 4 )] = fracF128UI96( uiB96 ) | 0x00010000;
        sigX[indexWord( 4, 2 )] = bWPtr[indexWord( 4, 2 )];
        sigX[indexWord( 4, 1 )] = bWPtr[indexWord( 4, 1 )];
        sigX[indexWord( 4, 0 )] = bWPtr[indexWord( 4, 0 )];
    } else {
        expB = softfloat_shiftNormSigF128M( bWPtr, 0, sigX );
        if ( expB == -128 ) goto zeroProd;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expProd = expA + expB - 0x3FF0;
    softfloat_mul128MTo256M( sigA, sigX, sigProd );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    wordSig = fracF128UI96( uiC96 );
    if ( expC ) {
        --expC;
        wordSig |= 0x00010000;
    }
    sigX[indexWordHi( 5 )] = wordSig;
    sigX[indexWord( 5, 3 )] = cWPtr[indexWord( 4, 2 )];
    sigX[indexWord( 5, 2 )] = cWPtr[indexWord( 4, 1 )];
    sigX[indexWord( 5, 1 )] = cWPtr[indexWord( 4, 0 )];
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    doSub = (signProd != signC);
    addCarryMRoutinePtr =
        doSub ? softfloat_addComplCarryM : softfloat_addCarryM;
    expDiff = expProd - expC;
    if ( expDiff <= 0 ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        signZ = signC;
        expZ = expC;
        if (
            sigProd[indexWord( 8, 2 )]
                || (sigProd[indexWord( 8, 1 )] | sigProd[indexWord( 8, 0 )])
        ) {
            sigProd[indexWord( 8, 3 )] |= 1;
        }
        extSigPtr = &sigProd[indexMultiwordHi( 8, 5 )];
        if ( expDiff ) {
            softfloat_shiftRightJam160M( extSigPtr, -expDiff, extSigPtr );
        }
        carry = 0;
        if ( doSub ) {
            wordSig = extSigPtr[indexWordLo( 5 )];
            extSigPtr[indexWordLo( 5 )] = -wordSig;
            carry = ! wordSig;
        }
        (*addCarryMRoutinePtr)(
            4,
            &sigX[indexMultiwordHi( 5, 4 )],
            extSigPtr + indexMultiwordHi( 5, 4 ),
            carry,
            extSigPtr + indexMultiwordHi( 5, 4 )
        );
        wordSig = extSigPtr[indexWordHi( 5 )];
        if ( ! expZ ) {
            if ( wordSig & 0x80000000 ) {
                signZ = ! signZ;
                softfloat_negX160M( extSigPtr );
                wordSig = extSigPtr[indexWordHi( 5 )];
            }
            goto checkCancellation;
        }
        if ( wordSig < 0x00010000 ) {
            --expZ;
            softfloat_add160M( extSigPtr, extSigPtr, extSigPtr );
            goto roundPack;
        }
        goto extSigReady_noCancellation;
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        signZ = signProd;
        expZ = expProd;
        sigX[indexWordLo( 5 )] = 0;
        expDiff -= 128;
        if ( 0 <= expDiff ) {
            /*----------------------------------------------------------------
            *----------------------------------------------------------------*/
            if ( expDiff ) softfloat_shiftRightJam160M( sigX, expDiff, sigX );
            wordSig = sigX[indexWordLo( 5 )];
            carry = 0;
            if ( doSub ) {
                carry = ! wordSig;
                wordSig = -wordSig;
            }
            carry =
                (*addCarryMRoutinePtr)(
                    4,
                    &sigProd[indexMultiwordLo( 8, 4 )],
                    &sigX[indexMultiwordHi( 5, 4 )],
                    carry,
                    &sigProd[indexMultiwordLo( 8, 4 )]
                );
            sigProd[indexWord( 8, 2 )] |= wordSig;
            ptr = &sigProd[indexWord( 8, 4 )];
        } else {
            /*----------------------------------------------------------------
            *----------------------------------------------------------------*/
            shiftDist = expDiff & 31;
            if ( shiftDist ) {
                softfloat_shortShiftRight160M( sigX, shiftDist, sigX );
            }
            expDiff >>= 5;
            extSigPtr =
                &sigProd[indexMultiwordLo( 8, 5 )] - wordIncr
                    + expDiff * -wordIncr;
            carry =
                (*addCarryMRoutinePtr)( 5, extSigPtr, sigX, doSub, extSigPtr );
            if ( expDiff == -4 ) {
                /*------------------------------------------------------------
                *------------------------------------------------------------*/
                wordSig = sigProd[indexWordHi( 8 )];
                if ( wordSig & 0x80000000 ) {
                    signZ = ! signZ;
                    softfloat_negX256M( sigProd );
                    wordSig = sigProd[indexWordHi( 8 )];
                }
                /*------------------------------------------------------------
                *------------------------------------------------------------*/
                if ( wordSig ) goto expProdBigger_noWordShift;
                wordSig = sigProd[indexWord( 8, 6 )];
                if ( 0x00040000 <= wordSig ) goto expProdBigger_noWordShift;
                expZ -= 32;
                extSigPtr = &sigProd[indexMultiwordHi( 8, 5 )] - wordIncr;
                for (;;) {
                    if ( wordSig ) break;
                    wordSig = extSigPtr[indexWord( 5, 3 )];
                    if ( 0x00040000 <= wordSig ) break;
                    expZ -= 32;
                    extSigPtr -= wordIncr;
                    if ( extSigPtr == &sigProd[indexMultiwordLo( 8, 5 )] ) {
                        goto checkCancellation;
                    }
                }
                /*------------------------------------------------------------
                *------------------------------------------------------------*/
                ptr = extSigPtr + indexWordLo( 5 );
                do {
                    ptr -= wordIncr;
                    if ( *ptr ) {
                        extSigPtr[indexWordLo( 5 )] |= 1;
                        break;
                    }
                } while ( ptr != &sigProd[indexWordLo( 8 )] );
                wordSig = extSigPtr[indexWordHi( 5 )];
                goto extSigReady;
            }
            ptr = extSigPtr + indexWordHi( 5 ) + wordIncr;
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( carry != doSub ) {
            if ( doSub ) {
                do {
                    wordSig = *ptr;
                    *ptr = wordSig - 1;
                    ptr += wordIncr;
                } while ( ! wordSig );
            } else {
                do {
                    wordSig = *ptr + 1;
                    *ptr = wordSig;
                    ptr += wordIncr;
                } while ( ! wordSig );
            }
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
     expProdBigger_noWordShift:
        if (
            sigProd[indexWord( 8, 2 )]
                || (sigProd[indexWord( 8, 1 )] | sigProd[indexWord( 8, 0 )])
        ) {
            sigProd[indexWord( 8, 3 )] |= 1;
        }
        extSigPtr = &sigProd[indexMultiwordHi( 8, 5 )];
        wordSig = extSigPtr[indexWordHi( 5 )];
    }
 extSigReady:
    roundPackRoutinePtr = softfloat_normRoundPackMToF128M;
    if ( wordSig < 0x00010000 ) goto doRoundPack;
 extSigReady_noCancellation:
    if ( 0x00020000 <= wordSig ) {
        ++expZ;
        softfloat_shortShiftRightJam160M( extSigPtr, 1, extSigPtr );
    }
 roundPack:
    roundPackRoutinePtr = softfloat_roundPackMToF128M;
 doRoundPack:
    (*roundPackRoutinePtr)( signZ, expZ, extSigPtr, zWPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_invalidF128M( zWPtr );
 propagateNaN_ZC:
    softfloat_propagateNaNF128M( zWPtr, cWPtr, zWPtr );
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zeroProd:
    if (
        ! (uint32_t) (uiC96<<1) && (signProd != signC)
            && ! cWPtr[indexWord( 4, 2 )]
            && ! (cWPtr[indexWord( 4, 1 )] | cWPtr[indexWord( 4, 0 )])
    ) {
        goto completeCancellation;
    }
 copyC:
    zWPtr[indexWordHi( 4 )] = uiC96;
    zWPtr[indexWord( 4, 2 )] = cWPtr[indexWord( 4, 2 )];
    zWPtr[indexWord( 4, 1 )] = cWPtr[indexWord( 4, 1 )];
    zWPtr[indexWord( 4, 0 )] = cWPtr[indexWord( 4, 0 )];
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 checkCancellation:
    if (
        wordSig
            || (extSigPtr[indexWord( 5, 3 )] | extSigPtr[indexWord( 5, 2 )])
            || (extSigPtr[indexWord( 5, 1 )] | extSigPtr[indexWord( 5, 0 )])
    ) {
        goto extSigReady;
    }
 completeCancellation:
    uiZ96 =
        packToF128UI96(
            (softfloat_roundingMode == softfloat_round_min), 0, 0 );
 uiZ:
    zWPtr[indexWordHi( 4 )] = uiZ96;
    zWPtr[indexWord( 4, 2 )] = 0;
    zWPtr[indexWord( 4, 1 )] = 0;
    zWPtr[indexWord( 4, 0 )] = 0;

}

