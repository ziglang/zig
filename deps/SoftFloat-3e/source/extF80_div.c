
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

extFloat80_t extF80_div( extFloat80_t a, extFloat80_t b )
{
    union { struct extFloat80M s; extFloat80_t f; } uA;
    uint_fast16_t uiA64;
    uint_fast64_t uiA0;
    bool signA;
    int_fast32_t expA;
    uint_fast64_t sigA;
    union { struct extFloat80M s; extFloat80_t f; } uB;
    uint_fast16_t uiB64;
    uint_fast64_t uiB0;
    bool signB;
    int_fast32_t expB;
    uint_fast64_t sigB;
    bool signZ;
    struct exp32_sig64 normExpSig;
    int_fast32_t expZ;
    struct uint128 rem;
    uint_fast32_t recip32;
    uint_fast64_t sigZ;
    int ix;
    uint_fast64_t q64;
    uint_fast32_t q;
    struct uint128 term;
    uint_fast64_t sigZExtra;
    struct uint128 uiZ;
    uint_fast16_t uiZ64;
    uint_fast64_t uiZ0;
    union { struct extFloat80M s; extFloat80_t f; } uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.s.signExp;
    uiA0  = uA.s.signif;
    signA = signExtF80UI64( uiA64 );
    expA  = expExtF80UI64( uiA64 );
    sigA  = uiA0;
    uB.f = b;
    uiB64 = uB.s.signExp;
    uiB0  = uB.s.signif;
    signB = signExtF80UI64( uiB64 );
    expB  = expExtF80UI64( uiB64 );
    sigB  = uiB0;
    signZ = signA ^ signB;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FFF ) {
        if ( sigA & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) goto propagateNaN;
        if ( expB == 0x7FFF ) {
            if ( sigB & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) goto propagateNaN;
            goto invalid;
        }
        goto infinity;
    }
    if ( expB == 0x7FFF ) {
        if ( sigB & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) goto propagateNaN;
        goto zero;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expB ) expB = 1;
    if ( ! (sigB & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigB ) {
            if ( ! sigA ) goto invalid;
            softfloat_raiseFlags( softfloat_flag_infinite );
            goto infinity;
        }
        normExpSig = softfloat_normSubnormalExtF80Sig( sigB );
        expB += normExpSig.exp;
        sigB = normExpSig.sig;
    }
    if ( ! expA ) expA = 1;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigA ) goto zero;
        normExpSig = softfloat_normSubnormalExtF80Sig( sigA );
        expA += normExpSig.exp;
        sigA = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expZ = expA - expB + 0x3FFF;
    if ( sigA < sigB ) {
        --expZ;
        rem = softfloat_shortShiftLeft128( 0, sigA, 32 );
    } else {
        rem = softfloat_shortShiftLeft128( 0, sigA, 31 );
    }
    recip32 = softfloat_approxRecip32_1( sigB>>32 );
    sigZ = 0;
    ix = 2;
    for (;;) {
        q64 = (uint_fast64_t) (uint32_t) (rem.v64>>2) * recip32;
        q = (q64 + 0x80000000)>>32;
        --ix;
        if ( ix < 0 ) break;
        rem = softfloat_shortShiftLeft128( rem.v64, rem.v0, 29 );
        term = softfloat_mul64ByShifted32To128( sigB, q );
        rem = softfloat_sub128( rem.v64, rem.v0, term.v64, term.v0 );
        if ( rem.v64 & UINT64_C( 0x8000000000000000 ) ) {
            --q;
            rem = softfloat_add128( rem.v64, rem.v0, sigB>>32, sigB<<32 );
        }
        sigZ = (sigZ<<29) + q;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ((q + 1) & 0x3FFFFF) < 2 ) {
        rem = softfloat_shortShiftLeft128( rem.v64, rem.v0, 29 );
        term = softfloat_mul64ByShifted32To128( sigB, q );
        rem = softfloat_sub128( rem.v64, rem.v0, term.v64, term.v0 );
        term = softfloat_shortShiftLeft128( 0, sigB, 32 );
        if ( rem.v64 & UINT64_C( 0x8000000000000000 ) ) {
            --q;
            rem = softfloat_add128( rem.v64, rem.v0, term.v64, term.v0 );
        } else if ( softfloat_le128( term.v64, term.v0, rem.v64, rem.v0 ) ) {
            ++q;
            rem = softfloat_sub128( rem.v64, rem.v0, term.v64, term.v0 );
        }
        if ( rem.v64 | rem.v0 ) q |= 1;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    sigZ = (sigZ<<6) + (q>>23);
    sigZExtra = (uint64_t) ((uint_fast64_t) q<<41);
    return
        softfloat_roundPackToExtF80(
            signZ, expZ, sigZ, sigZExtra, extF80_roundingPrecision );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 propagateNaN:
    uiZ = softfloat_propagateNaNExtF80UI( uiA64, uiA0, uiB64, uiB0 );
    uiZ64 = uiZ.v64;
    uiZ0  = uiZ.v0;
    goto uiZ;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_raiseFlags( softfloat_flag_invalid );
    uiZ64 = defaultNaNExtF80UI64;
    uiZ0  = defaultNaNExtF80UI0;
    goto uiZ;
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
    uZ.s.signExp = uiZ64;
    uZ.s.signif  = uiZ0;
    return uZ.f;

}

