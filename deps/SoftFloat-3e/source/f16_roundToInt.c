
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2017 The Regents of the University of
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

float16_t f16_roundToInt( float16_t a, uint_fast8_t roundingMode, bool exact )
{
    union ui16_f16 uA;
    uint_fast16_t uiA;
    int_fast8_t exp;
    uint_fast16_t uiZ, lastBitMask, roundBitsMask;
    union ui16_f16 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA = uA.ui;
    exp = expF16UI( uiA );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp <= 0xE ) {
        if ( !(uint16_t) (uiA<<1) ) return a;
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
        uiZ = uiA & packToF16UI( 1, 0, 0 );
        switch ( roundingMode ) {
         case softfloat_round_near_even:
            if ( !fracF16UI( uiA ) ) break;
         case softfloat_round_near_maxMag:
            if ( exp == 0xE ) uiZ |= packToF16UI( 0, 0xF, 0 );
            break;
         case softfloat_round_min:
            if ( uiZ ) uiZ = packToF16UI( 1, 0xF, 0 );
            break;
         case softfloat_round_max:
            if ( !uiZ ) uiZ = packToF16UI( 0, 0xF, 0 );
            break;
#ifdef SOFTFLOAT_ROUND_ODD
         case softfloat_round_odd:
            uiZ |= packToF16UI( 0, 0xF, 0 );
            break;
#endif
        }
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( 0x19 <= exp ) {
        if ( (exp == 0x1F) && fracF16UI( uiA ) ) {
            uiZ = softfloat_propagateNaNF16UI( uiA, 0 );
            goto uiZ;
        }
        return a;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiZ = uiA;
    lastBitMask = (uint_fast16_t) 1<<(0x19 - exp);
    roundBitsMask = lastBitMask - 1;
    if ( roundingMode == softfloat_round_near_maxMag ) {
        uiZ += lastBitMask>>1;
    } else if ( roundingMode == softfloat_round_near_even ) {
        uiZ += lastBitMask>>1;
        if ( !(uiZ & roundBitsMask) ) uiZ &= ~lastBitMask;
    } else if (
        roundingMode
            == (signF16UI( uiZ ) ? softfloat_round_min : softfloat_round_max)
    ) {
        uiZ += roundBitsMask;
    }
    uiZ &= ~roundBitsMask;
    if ( uiZ != uiA ) {
#ifdef SOFTFLOAT_ROUND_ODD
        if ( roundingMode == softfloat_round_odd ) uiZ |= lastBitMask;
#endif
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
    }
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

