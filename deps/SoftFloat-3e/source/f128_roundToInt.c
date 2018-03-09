
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

float128_t
 f128_roundToInt( float128_t a, uint_fast8_t roundingMode, bool exact )
{
    union ui128_f128 uA;
    uint_fast64_t uiA64, uiA0;
    int_fast32_t exp;
    struct uint128 uiZ;
    uint_fast64_t lastBitMask0, roundBitsMask;
    bool roundNearEven;
    uint_fast64_t lastBitMask64;
    union ui128_f128 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.ui.v64;
    uiA0  = uA.ui.v0;
    exp = expF128UI64( uiA64 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( 0x402F <= exp ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( 0x406F <= exp ) {
            if ( (exp == 0x7FFF) && (fracF128UI64( uiA64 ) | uiA0) ) {
                uiZ = softfloat_propagateNaNF128UI( uiA64, uiA0, 0, 0 );
                goto uiZ;
            }
            return a;
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        lastBitMask0 = (uint_fast64_t) 2<<(0x406E - exp);
        roundBitsMask = lastBitMask0 - 1;
        uiZ.v64 = uiA64;
        uiZ.v0  = uiA0;
        roundNearEven = (roundingMode == softfloat_round_near_even);
        if ( roundNearEven || (roundingMode == softfloat_round_near_maxMag) ) {
            if ( exp == 0x402F ) {
                if ( UINT64_C( 0x8000000000000000 ) <= uiZ.v0 ) {
                    ++uiZ.v64;
                    if (
                        roundNearEven
                            && (uiZ.v0 == UINT64_C( 0x8000000000000000 ))
                    ) {
                        uiZ.v64 &= ~1;
                    }
                }
            } else {
                uiZ = softfloat_add128( uiZ.v64, uiZ.v0, 0, lastBitMask0>>1 );
                if ( roundNearEven && !(uiZ.v0 & roundBitsMask) ) {
                    uiZ.v0 &= ~lastBitMask0;
                }
            }
        } else if (
            roundingMode
                == (signF128UI64( uiZ.v64 ) ? softfloat_round_min
                        : softfloat_round_max)
        ) {
            uiZ = softfloat_add128( uiZ.v64, uiZ.v0, 0, roundBitsMask );
        }
        uiZ.v0 &= ~roundBitsMask;
        lastBitMask64 = !lastBitMask0;
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( exp < 0x3FFF ) {
            if ( !((uiA64 & UINT64_C( 0x7FFFFFFFFFFFFFFF )) | uiA0) ) return a;
            if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
            uiZ.v64 = uiA64 & packToF128UI64( 1, 0, 0 );
            uiZ.v0  = 0;
            switch ( roundingMode ) {
             case softfloat_round_near_even:
                if ( !(fracF128UI64( uiA64 ) | uiA0) ) break;
             case softfloat_round_near_maxMag:
                if ( exp == 0x3FFE ) uiZ.v64 |= packToF128UI64( 0, 0x3FFF, 0 );
                break;
             case softfloat_round_min:
                if ( uiZ.v64 ) uiZ.v64 = packToF128UI64( 1, 0x3FFF, 0 );
                break;
             case softfloat_round_max:
                if ( !uiZ.v64 ) uiZ.v64 = packToF128UI64( 0, 0x3FFF, 0 );
                break;
#ifdef SOFTFLOAT_ROUND_ODD
             case softfloat_round_odd:
                uiZ.v64 |= packToF128UI64( 0, 0x3FFF, 0 );
                break;
#endif
            }
            goto uiZ;
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        uiZ.v64 = uiA64;
        uiZ.v0  = 0;
        lastBitMask64 = (uint_fast64_t) 1<<(0x402F - exp);
        roundBitsMask = lastBitMask64 - 1;
        if ( roundingMode == softfloat_round_near_maxMag ) {
            uiZ.v64 += lastBitMask64>>1;
        } else if ( roundingMode == softfloat_round_near_even ) {
            uiZ.v64 += lastBitMask64>>1;
            if ( !((uiZ.v64 & roundBitsMask) | uiA0) ) {
                uiZ.v64 &= ~lastBitMask64;
            }
        } else if (
            roundingMode
                == (signF128UI64( uiZ.v64 ) ? softfloat_round_min
                        : softfloat_round_max)
        ) {
            uiZ.v64 = (uiZ.v64 | (uiA0 != 0)) + roundBitsMask;
        }
        uiZ.v64 &= ~roundBitsMask;
        lastBitMask0 = 0;
    }
    if ( (uiZ.v64 != uiA64) || (uiZ.v0 != uiA0) ) {
#ifdef SOFTFLOAT_ROUND_ODD
        if ( roundingMode == softfloat_round_odd ) {
            uiZ.v64 |= lastBitMask64;
            uiZ.v0  |= lastBitMask0;
        }
#endif
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

