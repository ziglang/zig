
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

float128_t f128_mul( float128_t a, float128_t b )
{
    union ui128_f128 uA;
    uint_fast64_t uiA64, uiA0;
    bool signA;
    int_fast32_t expA;
    struct uint128 sigA;
    union ui128_f128 uB;
    uint_fast64_t uiB64, uiB0;
    bool signB;
    int_fast32_t expB;
    struct uint128 sigB;
    bool signZ;
    uint_fast64_t magBits;
    struct exp32_sig128 normExpSig;
    int_fast32_t expZ;
    uint64_t sig256Z[4];
    uint_fast64_t sigZExtra;
    struct uint128 sigZ;
    struct uint128_extra sig128Extra;
    struct uint128 uiZ;
    union ui128_f128 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.ui.v64;
    uiA0  = uA.ui.v0;
    signA = signF128UI64( uiA64 );
    expA  = expF128UI64( uiA64 );
    sigA.v64 = fracF128UI64( uiA64 );
    sigA.v0  = uiA0;
    uB.f = b;
    uiB64 = uB.ui.v64;
    uiB0  = uB.ui.v0;
    signB = signF128UI64( uiB64 );
    expB  = expF128UI64( uiB64 );
    sigB.v64 = fracF128UI64( uiB64 );
    sigB.v0  = uiB0;
    signZ = signA ^ signB;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FFF ) {
        if (
            (sigA.v64 | sigA.v0) || ((expB == 0x7FFF) && (sigB.v64 | sigB.v0))
        ) {
            goto propagateNaN;
        }
        magBits = expB | sigB.v64 | sigB.v0;
        goto infArg;
    }
    if ( expB == 0x7FFF ) {
        if ( sigB.v64 | sigB.v0 ) goto propagateNaN;
        magBits = expA | sigA.v64 | sigA.v0;
        goto infArg;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) {
        if ( ! (sigA.v64 | sigA.v0) ) goto zero;
        normExpSig = softfloat_normSubnormalF128Sig( sigA.v64, sigA.v0 );
        expA = normExpSig.exp;
        sigA = normExpSig.sig;
    }
    if ( ! expB ) {
        if ( ! (sigB.v64 | sigB.v0) ) goto zero;
        normExpSig = softfloat_normSubnormalF128Sig( sigB.v64, sigB.v0 );
        expB = normExpSig.exp;
        sigB = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA + expB - 0x4000;
    sigA.v64 |= UINT64_C( 0x0001000000000000 );
    sigB = softfloat_shortShiftLeft128( sigB.v64, sigB.v0, 16 );
    softfloat_mul128To256M( sigA.v64, sigA.v0, sigB.v64, sigB.v0, sig256Z );
    sigZExtra = sig256Z[indexWord( 4, 1 )] | (sig256Z[indexWord( 4, 0 )] != 0);
    sigZ =
        softfloat_add128(
            sig256Z[indexWord( 4, 3 )], sig256Z[indexWord( 4, 2 )],
            sigA.v64, sigA.v0
        );
    if ( UINT64_C( 0x0002000000000000 ) <= sigZ.v64 ) {
        ++expZ;
        sig128Extra =
            softfloat_shortShiftRightJam128Extra(
                sigZ.v64, sigZ.v0, sigZExtra, 1 );
        sigZ = sig128Extra.v;
        sigZExtra = sig128Extra.extra;
    }
    return
        softfloat_roundPackToF128( signZ, expZ, sigZ.v64, sigZ.v0, sigZExtra );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN:
    uiZ = softfloat_propagateNaNF128UI( uiA64, uiA0, uiB64, uiB0 );
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 infArg:
    if ( ! magBits ) {
        softfloat_raiseFlags( softfloat_flag_invalid );
        uiZ.v64 = defaultNaNF128UI64;
        uiZ.v0  = defaultNaNF128UI0;
        goto uiZ;
    }
    uiZ.v64 = packToF128UI64( signZ, 0x7FFF, 0 );
    goto uiZ0;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 zero:
    uiZ.v64 = packToF128UI64( signZ, 0, 0 );
 uiZ0:
    uiZ.v0 = 0;
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

