
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

float64_t
 softfloat_mulAddF64(
     uint_fast64_t uiA, uint_fast64_t uiB, uint_fast64_t uiC, uint_fast8_t op )
{
    bool signA;
    int_fast16_t expA;
    uint_fast64_t sigA;
    bool signB;
    int_fast16_t expB;
    uint_fast64_t sigB;
    bool signC;
    int_fast16_t expC;
    uint_fast64_t sigC;
    bool signZ;
    uint_fast64_t magBits, uiZ;
    struct exp16_sig64 normExpSig;
    int_fast16_t expZ;
    struct uint128 sig128Z;
    uint_fast64_t sigZ;
    int_fast16_t expDiff;
    struct uint128 sig128C;
    int_fast8_t shiftDist;
    union ui64_f64 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    signA = signF64UI( uiA );
    expA  = expF64UI( uiA );
    sigA  = fracF64UI( uiA );
    signB = signF64UI( uiB );
    expB  = expF64UI( uiB );
    sigB  = fracF64UI( uiB );
    signC = signF64UI( uiC ) ^ (op == softfloat_mulAdd_subC);
    expC  = expF64UI( uiC );
    sigC  = fracF64UI( uiC );
    signZ = signA ^ signB ^ (op == softfloat_mulAdd_subProd);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FF ) {
        if ( sigA || ((expB == 0x7FF) && sigB) ) goto propagateNaN_ABC;
        magBits = expB | sigB;
        goto infProdArg;
    }
    if ( expB == 0x7FF ) {
        if ( sigB ) goto propagateNaN_ABC;
        magBits = expA | sigA;
        goto infProdArg;
    }
    if ( expC == 0x7FF ) {
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
        normExpSig = softfloat_normSubnormalF64Sig( sigA );
        expA = normExpSig.exp;
        sigA = normExpSig.sig;
    }
    if ( ! expB ) {
        if ( ! sigB ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF64Sig( sigB );
        expB = normExpSig.exp;
        sigB = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA + expB - 0x3FE;
    sigA = (sigA | UINT64_C( 0x0010000000000000 ))<<10;
    sigB = (sigB | UINT64_C( 0x0010000000000000 ))<<10;
    sig128Z = softfloat_mul64To128( sigA, sigB );
    if ( sig128Z.v64 < UINT64_C( 0x2000000000000000 ) ) {
        --expZ;
        sig128Z =
            softfloat_add128(
                sig128Z.v64, sig128Z.v0, sig128Z.v64, sig128Z.v0 );
    }
    if ( ! expC ) {
        if ( ! sigC ) {
            --expZ;
            sigZ = sig128Z.v64<<1 | (sig128Z.v0 != 0);
            goto roundPack;
        }
        normExpSig = softfloat_normSubnormalF64Sig( sigC );
        expC = normExpSig.exp;
        sigC = normExpSig.sig;
    }
    sigC = (sigC | UINT64_C( 0x0010000000000000 ))<<9;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expZ - expC;
    if ( expDiff < 0 ) {
        expZ = expC;
        if ( (signZ == signC) || (expDiff < -1) ) {
            sig128Z.v64 = softfloat_shiftRightJam64( sig128Z.v64, -expDiff );
        } else {
            sig128Z =
                softfloat_shortShiftRightJam128( sig128Z.v64, sig128Z.v0, 1 );
        }
    } else if ( expDiff ) {
        sig128C = softfloat_shiftRightJam128( sigC, 0, expDiff );
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( signZ == signC ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff <= 0 ) {
            sigZ = (sigC + sig128Z.v64) | (sig128Z.v0 != 0);
        } else {
            sig128Z =
                softfloat_add128(
                    sig128Z.v64, sig128Z.v0, sig128C.v64, sig128C.v0 );
            sigZ = sig128Z.v64 | (sig128Z.v0 != 0);
        }
        if ( sigZ < UINT64_C( 0x4000000000000000 ) ) {
            --expZ;
            sigZ <<= 1;
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff < 0 ) {
            signZ = signC;
            sig128Z = softfloat_sub128( sigC, 0, sig128Z.v64, sig128Z.v0 );
        } else if ( ! expDiff ) {
            sig128Z.v64 = sig128Z.v64 - sigC;
            if ( ! (sig128Z.v64 | sig128Z.v0) ) goto completeCancellation;
            if ( sig128Z.v64 & UINT64_C( 0x8000000000000000 ) ) {
                signZ = ! signZ;
                sig128Z = softfloat_sub128( 0, 0, sig128Z.v64, sig128Z.v0 );
            }
        } else {
            sig128Z =
                softfloat_sub128(
                    sig128Z.v64, sig128Z.v0, sig128C.v64, sig128C.v0 );
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( ! sig128Z.v64 ) {
            expZ -= 64;
            sig128Z.v64 = sig128Z.v0;
            sig128Z.v0 = 0;
        }
        shiftDist = softfloat_countLeadingZeros64( sig128Z.v64 ) - 1;
        expZ -= shiftDist;
        if ( shiftDist < 0 ) {
            sigZ = softfloat_shortShiftRightJam64( sig128Z.v64, -shiftDist );
        } else {
            sig128Z =
                softfloat_shortShiftLeft128(
                    sig128Z.v64, sig128Z.v0, shiftDist );
            sigZ = sig128Z.v64;
        }
        sigZ |= (sig128Z.v0 != 0);
    }
 roundPack:
    return softfloat_roundPackToF64( signZ, expZ, sigZ );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN_ABC:
    uiZ = softfloat_propagateNaNF64UI( uiA, uiB );
    goto propagateNaN_ZC;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infProdArg:
    if ( magBits ) {
        uiZ = packToF64UI( signZ, 0x7FF, 0 );
        if ( expC != 0x7FF ) goto uiZ;
        if ( sigC ) goto propagateNaN_ZC;
        if ( signZ == signC ) goto uiZ;
    }
    softfloat_raiseFlags( softfloat_flag_invalid );
    uiZ = defaultNaNF64UI;
 propagateNaN_ZC:
    uiZ = softfloat_propagateNaNF64UI( uiZ, uiC );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zeroProd:
    uiZ = uiC;
    if ( ! (expC | sigC) && (signZ != signC) ) {
 completeCancellation:
        uiZ =
            packToF64UI(
                (softfloat_roundingMode == softfloat_round_min), 0, 0 );
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

#else

float64_t
 softfloat_mulAddF64(
     uint_fast64_t uiA, uint_fast64_t uiB, uint_fast64_t uiC, uint_fast8_t op )
{
    bool signA;
    int_fast16_t expA;
    uint64_t sigA;
    bool signB;
    int_fast16_t expB;
    uint64_t sigB;
    bool signC;
    int_fast16_t expC;
    uint64_t sigC;
    bool signZ;
    uint64_t magBits, uiZ;
    struct exp16_sig64 normExpSig;
    int_fast16_t expZ;
    uint32_t sig128Z[4];
    uint64_t sigZ;
    int_fast16_t shiftDist, expDiff;
    uint32_t sig128C[4];
    union ui64_f64 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    signA = signF64UI( uiA );
    expA  = expF64UI( uiA );
    sigA  = fracF64UI( uiA );
    signB = signF64UI( uiB );
    expB  = expF64UI( uiB );
    sigB  = fracF64UI( uiB );
    signC = signF64UI( uiC ) ^ (op == softfloat_mulAdd_subC);
    expC  = expF64UI( uiC );
    sigC  = fracF64UI( uiC );
    signZ = signA ^ signB ^ (op == softfloat_mulAdd_subProd);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FF ) {
        if ( sigA || ((expB == 0x7FF) && sigB) ) goto propagateNaN_ABC;
        magBits = expB | sigB;
        goto infProdArg;
    }
    if ( expB == 0x7FF ) {
        if ( sigB ) goto propagateNaN_ABC;
        magBits = expA | sigA;
        goto infProdArg;
    }
    if ( expC == 0x7FF ) {
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
        normExpSig = softfloat_normSubnormalF64Sig( sigA );
        expA = normExpSig.exp;
        sigA = normExpSig.sig;
    }
    if ( ! expB ) {
        if ( ! sigB ) goto zeroProd;
        normExpSig = softfloat_normSubnormalF64Sig( sigB );
        expB = normExpSig.exp;
        sigB = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA + expB - 0x3FE;
    sigA = (sigA | UINT64_C( 0x0010000000000000 ))<<10;
    sigB = (sigB | UINT64_C( 0x0010000000000000 ))<<11;
    softfloat_mul64To128M( sigA, sigB, sig128Z );
    sigZ =
        (uint64_t) sig128Z[indexWord( 4, 3 )]<<32 | sig128Z[indexWord( 4, 2 )];
    shiftDist = 0;
    if ( ! (sigZ & UINT64_C( 0x4000000000000000 )) ) {
        --expZ;
        shiftDist = -1;
    }
    if ( ! expC ) {
        if ( ! sigC ) {
            if ( shiftDist ) sigZ <<= 1;
            goto sigZ;
        }
        normExpSig = softfloat_normSubnormalF64Sig( sigC );
        expC = normExpSig.exp;
        sigC = normExpSig.sig;
    }
    sigC = (sigC | UINT64_C( 0x0010000000000000 ))<<10;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expZ - expC;
    if ( expDiff < 0 ) {
        expZ = expC;
        if ( (signZ == signC) || (expDiff < -1) ) {
            shiftDist -= expDiff;
            if ( shiftDist) {
                sigZ = softfloat_shiftRightJam64( sigZ, shiftDist );
            }
        } else {
            if ( ! shiftDist ) {
                softfloat_shortShiftRight128M( sig128Z, 1, sig128Z );
            }
        }
    } else {
        if ( shiftDist ) softfloat_add128M( sig128Z, sig128Z, sig128Z );
        if ( ! expDiff ) {
            sigZ =
                (uint64_t) sig128Z[indexWord( 4, 3 )]<<32
                    | sig128Z[indexWord( 4, 2 )];
        } else {
            sig128C[indexWord( 4, 3 )] = sigC>>32;
            sig128C[indexWord( 4, 2 )] = sigC;
            sig128C[indexWord( 4, 1 )] = 0;
            sig128C[indexWord( 4, 0 )] = 0;
            softfloat_shiftRightJam128M( sig128C, expDiff, sig128C );
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( signZ == signC ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff <= 0 ) {
            sigZ += sigC;
        } else {
            softfloat_add128M( sig128Z, sig128C, sig128Z );
            sigZ =
                (uint64_t) sig128Z[indexWord( 4, 3 )]<<32
                    | sig128Z[indexWord( 4, 2 )];
        }
        if ( sigZ & UINT64_C( 0x8000000000000000 ) ) {
            ++expZ;
            sigZ = softfloat_shortShiftRightJam64( sigZ, 1 );
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( expDiff < 0 ) {
            signZ = signC;
            if ( expDiff < -1 ) {
                sigZ = sigC - sigZ;
                if (
                    sig128Z[indexWord( 4, 1 )] || sig128Z[indexWord( 4, 0 )]
                ) {
                    sigZ = (sigZ - 1) | 1;
                }
                if ( ! (sigZ & UINT64_C( 0x4000000000000000 )) ) {
                    --expZ;
                    sigZ <<= 1;
                }
                goto roundPack;
            } else {
                sig128C[indexWord( 4, 3 )] = sigC>>32;
                sig128C[indexWord( 4, 2 )] = sigC;
                sig128C[indexWord( 4, 1 )] = 0;
                sig128C[indexWord( 4, 0 )] = 0;
                softfloat_sub128M( sig128C, sig128Z, sig128Z );
            }
        } else if ( ! expDiff ) {
            sigZ -= sigC;
            if (
                ! sigZ && ! sig128Z[indexWord( 4, 1 )]
                    && ! sig128Z[indexWord( 4, 0 )]
            ) {
                goto completeCancellation;
            }
            sig128Z[indexWord( 4, 3 )] = sigZ>>32;
            sig128Z[indexWord( 4, 2 )] = sigZ;
            if ( sigZ & UINT64_C( 0x8000000000000000 ) ) {
                signZ = ! signZ;
                softfloat_negX128M( sig128Z );
            }
        } else {
            softfloat_sub128M( sig128Z, sig128C, sig128Z );
            if ( 1 < expDiff ) {
                sigZ =
                    (uint64_t) sig128Z[indexWord( 4, 3 )]<<32
                        | sig128Z[indexWord( 4, 2 )];
                if ( ! (sigZ & UINT64_C( 0x4000000000000000 )) ) {
                    --expZ;
                    sigZ <<= 1;
                }
                goto sigZ;
            }
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        shiftDist = 0;
        sigZ =
            (uint64_t) sig128Z[indexWord( 4, 3 )]<<32
                | sig128Z[indexWord( 4, 2 )];
        if ( ! sigZ ) {
            shiftDist = 64;
            sigZ =
                (uint64_t) sig128Z[indexWord( 4, 1 )]<<32
                    | sig128Z[indexWord( 4, 0 )];
        }
        shiftDist += softfloat_countLeadingZeros64( sigZ ) - 1;
        if ( shiftDist ) {
            expZ -= shiftDist;
            softfloat_shiftLeft128M( sig128Z, shiftDist, sig128Z );
            sigZ =
                (uint64_t) sig128Z[indexWord( 4, 3 )]<<32
                    | sig128Z[indexWord( 4, 2 )];
        }
    }
 sigZ:
    if ( sig128Z[indexWord( 4, 1 )] || sig128Z[indexWord( 4, 0 )] ) sigZ |= 1;
 roundPack:
    return softfloat_roundPackToF64( signZ, expZ - 1, sigZ );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN_ABC:
    uiZ = softfloat_propagateNaNF64UI( uiA, uiB );
    goto propagateNaN_ZC;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infProdArg:
    if ( magBits ) {
        uiZ = packToF64UI( signZ, 0x7FF, 0 );
        if ( expC != 0x7FF ) goto uiZ;
        if ( sigC ) goto propagateNaN_ZC;
        if ( signZ == signC ) goto uiZ;
    }
    softfloat_raiseFlags( softfloat_flag_invalid );
    uiZ = defaultNaNF64UI;
 propagateNaN_ZC:
    uiZ = softfloat_propagateNaNF64UI( uiZ, uiC );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zeroProd:
    uiZ = uiC;
    if ( ! (expC | sigC) && (signZ != signC) ) {
 completeCancellation:
        uiZ =
            packToF64UI(
                (softfloat_roundingMode == softfloat_round_min), 0, 0 );
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

#endif

