
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
University of California.  All rights reserved.

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

extFloat80_t extF80_rem( extFloat80_t a, extFloat80_t b )
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
    int_fast32_t expB;
    uint_fast64_t sigB;
    struct exp32_sig64 normExpSig;
    int_fast32_t expDiff;
    struct uint128 rem, shiftedSigB;
    uint_fast32_t q, recip32;
    uint_fast64_t q64;
    struct uint128 term, altRem, meanRem;
    bool signRem;
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
    expB  = expExtF80UI64( uiB64 );
    sigB  = uiB0;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( expA == 0x7FFF ) {
        if (
               (sigA & UINT64_C( 0x7FFFFFFFFFFFFFFF ))
            || ((expB == 0x7FFF) && (sigB & UINT64_C( 0x7FFFFFFFFFFFFFFF )))
        ) {
            goto propagateNaN;
        }
        goto invalid;
    }
    if ( expB == 0x7FFF ) {
        if ( sigB & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) goto propagateNaN;
        /*--------------------------------------------------------------------
        | Argument b is an infinity.  Doubling `expB' is an easy way to ensure
        | that `expDiff' later is less than -1, which will result in returning
        | a canonicalized version of argument a.
        *--------------------------------------------------------------------*/
        expB += expB;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expB ) expB = 1;
    if ( ! (sigB & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigB ) goto invalid;
        normExpSig = softfloat_normSubnormalExtF80Sig( sigB );
        expB += normExpSig.exp;
        sigB = normExpSig.sig;
    }
    if ( ! expA ) expA = 1;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( ! sigA ) {
            expA = 0;
            goto copyA;
        }
        normExpSig = softfloat_normSubnormalExtF80Sig( sigA );
        expA += normExpSig.exp;
        sigA = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expDiff = expA - expB;
    if ( expDiff < -1 ) goto copyA;
    rem = softfloat_shortShiftLeft128( 0, sigA, 32 );
    shiftedSigB = softfloat_shortShiftLeft128( 0, sigB, 32 );
    if ( expDiff < 1 ) {
        if ( expDiff ) {
            --expB;
            shiftedSigB = softfloat_shortShiftLeft128( 0, sigB, 33 );
            q = 0;
        } else {
            q = (sigB <= sigA);
            if ( q ) {
                rem =
                    softfloat_sub128(
                        rem.v64, rem.v0, shiftedSigB.v64, shiftedSigB.v0 );
            }
        }
    } else {
        recip32 = softfloat_approxRecip32_1( sigB>>32 );
        expDiff -= 30;
        for (;;) {
            q64 = (uint_fast64_t) (uint32_t) (rem.v64>>2) * recip32;
            if ( expDiff < 0 ) break;
            q = (q64 + 0x80000000)>>32;
            rem = softfloat_shortShiftLeft128( rem.v64, rem.v0, 29 );
            term = softfloat_mul64ByShifted32To128( sigB, q );
            rem = softfloat_sub128( rem.v64, rem.v0, term.v64, term.v0 );
            if ( rem.v64 & UINT64_C( 0x8000000000000000 ) ) {
                rem =
                    softfloat_add128(
                        rem.v64, rem.v0, shiftedSigB.v64, shiftedSigB.v0 );
            }
            expDiff -= 29;
        }
        /*--------------------------------------------------------------------
        | (`expDiff' cannot be less than -29 here.)
        *--------------------------------------------------------------------*/
        q = (uint32_t) (q64>>32)>>(~expDiff & 31);
        rem = softfloat_shortShiftLeft128( rem.v64, rem.v0, expDiff + 30 );
        term = softfloat_mul64ByShifted32To128( sigB, q );
        rem = softfloat_sub128( rem.v64, rem.v0, term.v64, term.v0 );
        if ( rem.v64 & UINT64_C( 0x8000000000000000 ) ) {
            altRem =
                softfloat_add128(
                    rem.v64, rem.v0, shiftedSigB.v64, shiftedSigB.v0 );
            goto selectRem;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    do {
        altRem = rem;
        ++q;
        rem =
            softfloat_sub128(
                rem.v64, rem.v0, shiftedSigB.v64, shiftedSigB.v0 );
    } while ( ! (rem.v64 & UINT64_C( 0x8000000000000000 )) );
 selectRem:
    meanRem = softfloat_add128( rem.v64, rem.v0, altRem.v64, altRem.v0 );
    if (
        (meanRem.v64 & UINT64_C( 0x8000000000000000 ))
            || (! (meanRem.v64 | meanRem.v0) && (q & 1))
    ) {
        rem = altRem;
    }
    signRem = signA;
    if ( rem.v64 & UINT64_C( 0x8000000000000000 ) ) {
        signRem = ! signRem;
        rem = softfloat_sub128( 0, 0, rem.v64, rem.v0 );
    }
    return
        softfloat_normRoundPackToExtF80(
            signRem, rem.v64 | rem.v0 ? expB + 32 : 0, rem.v64, rem.v0, 80 );
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
 copyA:
    if ( expA < 1 ) {
        sigA >>= 1 - expA;
        expA = 0;
    }
    uiZ64 = packToExtF80UI64( signA, expA );
    uiZ0  = sigA;
 uiZ:
    uZ.s.signExp = uiZ64;
    uZ.s.signif  = uiZ0;
    return uZ.f;

}

