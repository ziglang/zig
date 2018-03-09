
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

float32_t
 softfloat_mulAddF32(
     uint_fast32_t uiA, uint_fast32_t uiB, uint_fast32_t uiC, uint_fast8_t op )
{
    bool signA;
    int_fast16_t expA;
    uint_fast32_t sigA;
    bool signB;
    int_fast16_t expB;
    uint_fast32_t sigB;
    bool signC;
    int_fast16_t expC;
    uint_fast32_t sigC;
    bool signProd;
    uint_fast32_t magBits, uiZ;
    struct exp16_sig32 normExpSig;
    int_fast16_t expProd;
    uint_fast64_t sigProd;
    bool signZ;
    int_fast16_t expZ;
    uint_fast32_t sigZ;
    int_fast16_t expDiff;
    uint_fast64_t sig64Z, sig64C;
    int_fast8_t shiftDist;
    union ui32_f32 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    signA = signF32UI( uiA );
    expA  = expF32UI( uiA );
    sigA  = fracF32UI( uiA );
    signB = signF32UI( uiB );
    expB  = expF32UI( uiB );
    sigB  = fracF32UI( uiB );
    signC = signF32UI( uiC ) ^ (op == softfloat_mulAdd_subC);
    expC  = expF32UI( uiC );
    sigC  = fracF32UI( uiC );
    signProd = signA ^ signB ^ (op == softfloat_mulAdd_subProd);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0xFF ) {
        if ( sigA || ((expB == 0xFF) && sigB) ) goto propagateNaN_ABC;
        magBits = expB | sigB;
        goto infProdArg;
    }
    if ( expB == 0xFF ) {
        if ( sigB ) goto propagateNaN_ABC;
        magBits = expA | sigA;
        goto infProdArg;
    }
    if ( expC == 0xFF ) {
        if ( sigC ) {
            uiZ = 0;
            goto propagateNaN_ZC;
        }
        uiZ = uiC;
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) {
        if ( ! sigA ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF32Sig( sigA );
        expA = normExpSig.exp;
        sigA = normExpSig.sig;
    }
    if ( ! expB ) {
        if ( ! sigB ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF32Sig( sigB );
        expB = normExpSig.exp;
        sigB = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expProd = expA + expB - 0x7E;
    sigA = (sigA | 0x00800000)<<7;
    sigB = (sigB | 0x00800000)<<7;
    sigProd = (uint_fast64_t) sigA * sigB;
    if ( sigProd < UINT64_C( 0x2000000000000000 ) ) {
        --expProd;
        sigProd <<= 1;
    }
    signZ = signProd;
    if ( ! expC ) {
        if ( ! sigC ) {
            expZ = expProd - 1;
            sigZ = softfloat_shortShiftRightJam64( sigProd, 31 );
            goto roundPack;
        }
        normExpSig = softfloat_normSubnormalF32Sig( sigC );
        expC = normExpSig.exp;
        sigC = normExpSig.sig;
    }
    sigC = (sigC | 0x00800000)<<6;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expProd - expC;
    if ( signProd == signC ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff <= 0 ) {
            expZ = expC;
            sigZ = sigC + softfloat_shiftRightJam64( sigProd, 32 - expDiff );
        } else {
            expZ = expProd;
            sig64Z =
                sigProd
                    + softfloat_shiftRightJam64(
                          (uint_fast64_t) sigC<<32, expDiff );
            sigZ = softfloat_shortShiftRightJam64( sig64Z, 32 );
        }
        if ( sigZ < 0x40000000 ) {
            --expZ;
            sigZ <<= 1;
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        sig64C = (uint_fast64_t) sigC<<32;
        if ( expDiff < 0 ) {
            signZ = signC;
            expZ = expC;
            sig64Z = sig64C - softfloat_shiftRightJam64( sigProd, -expDiff );
        } else if ( ! expDiff ) {
            expZ = expProd;
            sig64Z = sigProd - sig64C;
            if ( ! sig64Z ) goto completeCancellation;
            if ( sig64Z & UINT64_C( 0x8000000000000000 ) ) {
                signZ = ! signZ;
                sig64Z = -sig64Z;
            }
        } else {
            expZ = expProd;
            sig64Z = sigProd - softfloat_shiftRightJam64( sig64C, expDiff );
        }
        shiftDist = softfloat_countLeadingZeros64( sig64Z ) - 1;
        expZ -= shiftDist;
        shiftDist -= 32;
        if ( shiftDist < 0 ) {
            sigZ = softfloat_shortShiftRightJam64( sig64Z, -shiftDist );
        } else {
            sigZ = (uint_fast32_t) sig64Z<<shiftDist;
        }
    }
 roundPack:
    return softfloat_roundPackToF32( signZ, expZ, sigZ );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN_ABC:
    uiZ = softfloat_propagateNaNF32UI( uiA, uiB );
    goto propagateNaN_ZC;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infProdArg:
    if ( magBits ) {
        uiZ = packToF32UI( signProd, 0xFF, 0 );
        if ( expC != 0xFF ) goto uiZ;
        if ( sigC ) goto propagateNaN_ZC;
        if ( signProd == signC ) goto uiZ;
    }
    softfloat_raiseFlags( softfloat_flag_invalid );
    uiZ = defaultNaNF32UI;
 propagateNaN_ZC:
    uiZ = softfloat_propagateNaNF32UI( uiZ, uiC );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zeroProd:
    uiZ = uiC;
    if ( ! (expC | sigC) && (signProd != signC) ) {
 completeCancellation:
        uiZ =
            packToF32UI(
                (softfloat_roundingMode == softfloat_round_min), 0, 0 );
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

