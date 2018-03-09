
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2017 The Regents of the University of
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

extFloat80_t
 extF80_roundToInt( extFloat80_t a, uint_fast8_t roundingMode, bool exact )
{
    union { struct extFloat80M s; extFloat80_t f; } uA;
    uint_fast16_t uiA64, signUI64;
    int_fast32_t exp;
    uint_fast64_t sigA;
    uint_fast16_t uiZ64;
    uint_fast64_t sigZ;
    struct exp32_sig64 normExpSig;
    struct uint128 uiZ;
    uint_fast64_t lastBitMask, roundBitsMask;
    union { struct extFloat80M s; extFloat80_t f; } uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.s.signExp;
    signUI64 = uiA64 & packToExtF80UI64( 1, 0 );
    exp = expExtF80UI64( uiA64 );
    sigA = uA.s.signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( !(sigA & UINT64_C( 0x8000000000000000 )) && (exp != 0x7FFF) ) {
        if ( !sigA ) {
            uiZ64 = signUI64;
            sigZ = 0;
            goto uiZ;
        }
        normExpSig = softfloat_normSubnormalExtF80Sig( sigA );
        exp += normExpSig.exp;
        sigA = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( 0x403E <= exp ) {
        if ( exp == 0x7FFF ) {
            if ( sigA & UINT64_C( 0x7FFFFFFFFFFFFFFF ) ) {
                uiZ = softfloat_propagateNaNExtF80UI( uiA64, sigA, 0, 0 );
                uiZ64 = uiZ.v64;
                sigZ  = uiZ.v0;
                goto uiZ;
            }
            sigZ = UINT64_C( 0x8000000000000000 );
        } else {
            sigZ = sigA;
        }
        uiZ64 = signUI64 | exp;
        goto uiZ;
    }
    if ( exp <= 0x3FFE ) {
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
        switch ( roundingMode ) {
         case softfloat_round_near_even:
            if ( !(sigA & UINT64_C( 0x7FFFFFFFFFFFFFFF )) ) break;
         case softfloat_round_near_maxMag:
            if ( exp == 0x3FFE ) goto mag1;
            break;
         case softfloat_round_min:
            if ( signUI64 ) goto mag1;
            break;
         case softfloat_round_max:
            if ( !signUI64 ) goto mag1;
            break;
#ifdef SOFTFLOAT_ROUND_ODD
         case softfloat_round_odd:
            goto mag1;
#endif
        }
        uiZ64 = signUI64;
        sigZ  = 0;
        goto uiZ;
     mag1:
        uiZ64 = signUI64 | 0x3FFF;
        sigZ  = UINT64_C( 0x8000000000000000 );
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiZ64 = signUI64 | exp;
    lastBitMask = (uint_fast64_t) 1<<(0x403E - exp);
    roundBitsMask = lastBitMask - 1;
    sigZ = sigA;
    if ( roundingMode == softfloat_round_near_maxMag ) {
        sigZ += lastBitMask>>1;
    } else if ( roundingMode == softfloat_round_near_even ) {
        sigZ += lastBitMask>>1;
        if ( !(sigZ & roundBitsMask) ) sigZ &= ~lastBitMask;
    } else if (
        roundingMode == (signUI64 ? softfloat_round_min : softfloat_round_max)
    ) {
        sigZ += roundBitsMask;
    }
    sigZ &= ~roundBitsMask;
    if ( !sigZ ) {
        ++uiZ64;
        sigZ = UINT64_C( 0x8000000000000000 );
    }
    if ( sigZ != sigA ) {
#ifdef SOFTFLOAT_ROUND_ODD
        if ( roundingMode == softfloat_round_odd ) sigZ |= lastBitMask;
#endif
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
    }
 uiZ:
    uZ.s.signExp = uiZ64;
    uZ.s.signif = sigZ;
    return uZ.f;

}

