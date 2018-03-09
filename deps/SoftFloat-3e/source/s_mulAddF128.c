
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

float128_t
 softfloat_mulAddF128(
     uint_fast64_t uiA64,
     uint_fast64_t uiA0,
     uint_fast64_t uiB64,
     uint_fast64_t uiB0,
     uint_fast64_t uiC64,
     uint_fast64_t uiC0,
     uint_fast8_t op
 )
{
    bool signA;
    int_fast32_t expA;
    struct uint128 sigA;
    bool signB;
    int_fast32_t expB;
    struct uint128 sigB;
    bool signC;
    int_fast32_t expC;
    struct uint128 sigC;
    bool signZ;
    uint_fast64_t magBits;
    struct uint128 uiZ;
    struct exp32_sig128 normExpSig;
    int_fast32_t expZ;
    uint64_t sig256Z[4];
    struct uint128 sigZ;
    int_fast32_t shiftDist, expDiff;
    struct uint128 x128;
    uint64_t sig256C[4];
    static uint64_t zero256[4] = INIT_UINTM4( 0, 0, 0, 0 );
    uint_fast64_t sigZExtra, sig256Z0;
    union ui128_f128 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    signA = signF128UI64( uiA64 );
    expA  = expF128UI64( uiA64 );
    sigA.v64 = fracF128UI64( uiA64 );
    sigA.v0  = uiA0;
    signB = signF128UI64( uiB64 );
    expB  = expF128UI64( uiB64 );
    sigB.v64 = fracF128UI64( uiB64 );
    sigB.v0  = uiB0;
    signC = signF128UI64( uiC64 ) ^ (op == softfloat_mulAdd_subC);
    expC  = expF128UI64( uiC64 );
    sigC.v64 = fracF128UI64( uiC64 );
    sigC.v0  = uiC0;
    signZ = signA ^ signB ^ (op == softfloat_mulAdd_subProd);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FFF ) {
        if (
            (sigA.v64 | sigA.v0) || ((expB == 0x7FFF) && (sigB.v64 | sigB.v0))
        ) {
            goto propagateNaN_ABC;
        }
        magBits = expB | sigB.v64 | sigB.v0;
        goto infProdArg;
    }
    if ( expB == 0x7FFF ) {
        if ( sigB.v64 | sigB.v0 ) goto propagateNaN_ABC;
        magBits = expA | sigA.v64 | sigA.v0;
        goto infProdArg;
    }
    if ( expC == 0x7FFF ) {
        if ( sigC.v64 | sigC.v0 ) {
            uiZ.v64 = 0;
            uiZ.v0  = 0;
            goto propagateNaN_ZC;
        }
        uiZ.v64 = uiC64;
        uiZ.v0  = uiC0;
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) {
        if ( ! (sigA.v64 | sigA.v0) ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF128Sig( sigA.v64, sigA.v0 );
        expA = normExpSig.exp;
        sigA = normExpSig.sig;
    }
    if ( ! expB ) {
        if ( ! (sigB.v64 | sigB.v0) ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF128Sig( sigB.v64, sigB.v0 );
        expB = normExpSig.exp;
        sigB = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA + expB - 0x3FFE;
    sigA.v64 |= UINT64_C( 0x0001000000000000 );
    sigB.v64 |= UINT64_C( 0x0001000000000000 );
    sigA = softfloat_shortShiftLeft128( sigA.v64, sigA.v0, 8 );
    sigB = softfloat_shortShiftLeft128( sigB.v64, sigB.v0, 15 );
    softfloat_mul128To256M( sigA.v64, sigA.v0, sigB.v64, sigB.v0, sig256Z );
    sigZ.v64 = sig256Z[indexWord( 4, 3 )];
    sigZ.v0  = sig256Z[indexWord( 4, 2 )];
    shiftDist = 0;
    if ( ! (sigZ.v64 & UINT64_C( 0x0100000000000000 )) ) {
        --expZ;
        shiftDist = -1;
    }
    if ( ! expC ) {
        if ( ! (sigC.v64 | sigC.v0) ) {
            shiftDist += 8;
            goto sigZ;
        }
        normExpSig = softfloat_normSubnormalF128Sig( sigC.v64, sigC.v0 );
        expC = normExpSig.exp;
        sigC = normExpSig.sig;
    }
    sigC.v64 |= UINT64_C( 0x0001000000000000 );
    sigC = softfloat_shortShiftLeft128( sigC.v64, sigC.v0, 8 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expZ - expC;
    if ( expDiff < 0 ) {
        expZ = expC;
        if ( (signZ == signC) || (expDiff < -1) ) {
            shiftDist -= expDiff;
            if ( shiftDist ) {
                sigZ =
                    softfloat_shiftRightJam128( sigZ.v64, sigZ.v0, shiftDist );
            }
        } else {
            if ( ! shiftDist ) {
                x128 =
                    softfloat_shortShiftRight128(
                        sig256Z[indexWord( 4, 1 )], sig256Z[indexWord( 4, 0 )],
                        1
                    );
                sig256Z[indexWord( 4, 1 )] = (sigZ.v0<<63) | x128.v64;
                sig256Z[indexWord( 4, 0 )] = x128.v0;
                sigZ = softfloat_shortShiftRight128( sigZ.v64, sigZ.v0, 1 );
                sig256Z[indexWord( 4, 3 )] = sigZ.v64;
                sig256Z[indexWord( 4, 2 )] = sigZ.v0;
            }
        }
    } else {
        if ( shiftDist ) softfloat_add256M( sig256Z, sig256Z, sig256Z );
        if ( ! expDiff ) {
            sigZ.v64 = sig256Z[indexWord( 4, 3 )];
            sigZ.v0  = sig256Z[indexWord( 4, 2 )];
        } else {
            sig256C[indexWord( 4, 3 )] = sigC.v64;
            sig256C[indexWord( 4, 2 )] = sigC.v0;
            sig256C[indexWord( 4, 1 )] = 0;
            sig256C[indexWord( 4, 0 )] = 0;
            softfloat_shiftRightJam256M( sig256C, expDiff, sig256C );
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    shiftDist = 8;
    if ( signZ == signC ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff <= 0 ) {
            sigZ = softfloat_add128( sigC.v64, sigC.v0, sigZ.v64, sigZ.v0 );
        } else {
            softfloat_add256M( sig256Z, sig256C, sig256Z );
            sigZ.v64 = sig256Z[indexWord( 4, 3 )];
            sigZ.v0  = sig256Z[indexWord( 4, 2 )];
        }
        if ( sigZ.v64 & UINT64_C( 0x0200000000000000 ) ) {
            ++expZ;
            shiftDist = 9;
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff < 0 ) {
            signZ = signC;
            if ( expDiff < -1 ) {
                sigZ =
                    softfloat_sub128( sigC.v64, sigC.v0, sigZ.v64, sigZ.v0 );
                sigZExtra =
                    sig256Z[indexWord( 4, 1 )] | sig256Z[indexWord( 4, 0 )];
                if ( sigZExtra ) {
                    sigZ = softfloat_sub128( sigZ.v64, sigZ.v0, 0, 1 );
                }
                if ( ! (sigZ.v64 & UINT64_C( 0x0100000000000000 )) ) {
                    --expZ;
                    shiftDist = 7;
                }
                goto shiftRightRoundPack;
            } else {
                sig256C[indexWord( 4, 3 )] = sigC.v64;
                sig256C[indexWord( 4, 2 )] = sigC.v0;
                sig256C[indexWord( 4, 1 )] = 0;
                sig256C[indexWord( 4, 0 )] = 0;
                softfloat_sub256M( sig256C, sig256Z, sig256Z );
            }
        } else if ( ! expDiff ) {
            sigZ = softfloat_sub128( sigZ.v64, sigZ.v0, sigC.v64, sigC.v0 );
            if (
                ! (sigZ.v64 | sigZ.v0) && ! sig256Z[indexWord( 4, 1 )]
                    && ! sig256Z[indexWord( 4, 0 )]
            ) {
                goto completeCancellation;
            }
            sig256Z[indexWord( 4, 3 )] = sigZ.v64;
            sig256Z[indexWord( 4, 2 )] = sigZ.v0;
            if ( sigZ.v64 & UINT64_C( 0x8000000000000000 ) ) {
                signZ = ! signZ;
                softfloat_sub256M( zero256, sig256Z, sig256Z );
            }
        } else {
            softfloat_sub256M( sig256Z, sig256C, sig256Z );
            if ( 1 < expDiff ) {
                sigZ.v64 = sig256Z[indexWord( 4, 3 )];
                sigZ.v0  = sig256Z[indexWord( 4, 2 )];
                if ( ! (sigZ.v64 & UINT64_C( 0x0100000000000000 )) ) {
                    --expZ;
                    shiftDist = 7;
                }
                goto sigZ;
            }
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        sigZ.v64  = sig256Z[indexWord( 4, 3 )];
        sigZ.v0   = sig256Z[indexWord( 4, 2 )];
        sigZExtra = sig256Z[indexWord( 4, 1 )];
        sig256Z0  = sig256Z[indexWord( 4, 0 )];
        if ( sigZ.v64 ) {
            if ( sig256Z0 ) sigZExtra |= 1;
        } else {
            expZ -= 64;
            sigZ.v64  = sigZ.v0;
            sigZ.v0   = sigZExtra;
            sigZExtra = sig256Z0;
            if ( ! sigZ.v64 ) {
                expZ -= 64;
                sigZ.v64  = sigZ.v0;
                sigZ.v0   = sigZExtra;
                sigZExtra = 0;
                if ( ! sigZ.v64 ) {
                    expZ -= 64;
                    sigZ.v64 = sigZ.v0;
                    sigZ.v0  = 0;
                }
            }
        }
        shiftDist = softfloat_countLeadingZeros64( sigZ.v64 );
        expZ += 7 - shiftDist;
        shiftDist = 15 - shiftDist;
        if ( 0 < shiftDist ) goto shiftRightRoundPack;
        if ( shiftDist ) {
            shiftDist = -shiftDist;
            sigZ = softfloat_shortShiftLeft128( sigZ.v64, sigZ.v0, shiftDist );
            x128 = softfloat_shortShiftLeft128( 0, sigZExtra, shiftDist );
            sigZ.v0 |= x128.v64;
            sigZExtra = x128.v0;
        }
        goto roundPack;
    }
 sigZ:
    sigZExtra = sig256Z[indexWord( 4, 1 )] | sig256Z[indexWord( 4, 0 )];
 shiftRightRoundPack:
    sigZExtra = (uint64_t) (sigZ.v0<<(64 - shiftDist)) | (sigZExtra != 0);
    sigZ = softfloat_shortShiftRight128( sigZ.v64, sigZ.v0, shiftDist );
 roundPack:
    return
        softfloat_roundPackToF128(
            signZ, expZ - 1, sigZ.v64, sigZ.v0, sigZExtra );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN_ABC:
    uiZ = softfloat_propagateNaNF128UI( uiA64, uiA0, uiB64, uiB0 );
    goto propagateNaN_ZC;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infProdArg:
    if ( magBits ) {
        uiZ.v64 = packToF128UI64( signZ, 0x7FFF, 0 );
        uiZ.v0 = 0;
        if ( expC != 0x7FFF ) goto uiZ;
        if ( sigC.v64 | sigC.v0 ) goto propagateNaN_ZC;
        if ( signZ == signC ) goto uiZ;
    }
    softfloat_raiseFlags( softfloat_flag_invalid );
    uiZ.v64 = defaultNaNF128UI64;
    uiZ.v0  = defaultNaNF128UI0;
 propagateNaN_ZC:
    uiZ = softfloat_propagateNaNF128UI( uiZ.v64, uiZ.v0, uiC64, uiC0 );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zeroProd:
    uiZ.v64 = uiC64;
    uiZ.v0  = uiC0;
    if ( ! (expC | sigC.v64 | sigC.v0) && (signZ != signC) ) {
 completeCancellation:
        uiZ.v64 =
            packToF128UI64(
                (softfloat_roundingMode == softfloat_round_min), 0, 0 );
        uiZ.v0 = 0;
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

