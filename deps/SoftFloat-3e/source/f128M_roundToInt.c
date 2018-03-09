
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

#ifdef SOFTFLOAT_FAST_INT64

void
 f128M_roundToInt(
     const float128_t *aPtr,
     uint_fast8_t roundingMode,
     bool exact,
     float128_t *zPtr
 )
{

    *zPtr = f128_roundToInt( *aPtr, roundingMode, exact );

}

#else

void
 f128M_roundToInt(
     const float128_t *aPtr,
     uint_fast8_t roundingMode,
     bool exact,
     float128_t *zPtr
 )
{
    const uint32_t *aWPtr;
    uint32_t *zWPtr;
    uint32_t ui96;
    int32_t exp;
    uint32_t sigExtra;
    bool sign;
    uint_fast8_t bitPos;
    bool roundNear;
    unsigned int index, lastIndex;
    bool extra;
    uint32_t wordA, bit, wordZ;
    uint_fast8_t carry;
    uint32_t extrasMask;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aWPtr = (const uint32_t *) aPtr;
    zWPtr = (uint32_t *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    ui96 = aWPtr[indexWordHi( 4 )];
    exp = expF128UI96( ui96 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp < 0x3FFF ) {
        zWPtr[indexWord( 4, 2 )] = 0;
        zWPtr[indexWord( 4, 1 )] = 0;
        zWPtr[indexWord( 4, 0 )] = 0;
        sigExtra = aWPtr[indexWord( 4, 2 )];
        if ( !sigExtra ) {
            sigExtra = aWPtr[indexWord( 4, 1 )] | aWPtr[indexWord( 4, 0 )];
        }
        if ( !sigExtra && !(ui96 & 0x7FFFFFFF) ) goto ui96;
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
        sign = signF128UI96( ui96 );
        switch ( roundingMode ) {
         case softfloat_round_near_even:
            if ( !fracF128UI96( ui96 ) && !sigExtra ) break;
         case softfloat_round_near_maxMag:
            if ( exp == 0x3FFE ) goto mag1;
            break;
         case softfloat_round_min:
            if ( sign ) goto mag1;
            break;
         case softfloat_round_max:
            if ( !sign ) goto mag1;
            break;
#ifdef SOFTFLOAT_ROUND_ODD
         case softfloat_round_odd:
            goto mag1;
#endif
        }
        ui96 = packToF128UI96( sign, 0, 0 );
        goto ui96;
     mag1:
        ui96 = packToF128UI96( sign, 0x3FFF, 0 );
        goto ui96;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( 0x406F <= exp ) {
        if (
            (exp == 0x7FFF)
                && (fracF128UI96( ui96 )
                        || (aWPtr[indexWord( 4, 2 )] | aWPtr[indexWord( 4, 1 )]
                                | aWPtr[indexWord( 4, 0 )]))
        ) {
            softfloat_propagateNaNF128M( aWPtr, 0, zWPtr );
            return;
        }
        zWPtr[indexWord( 4, 2 )] = aWPtr[indexWord( 4, 2 )];
        zWPtr[indexWord( 4, 1 )] = aWPtr[indexWord( 4, 1 )];
        zWPtr[indexWord( 4, 0 )] = aWPtr[indexWord( 4, 0 )];
        goto ui96;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    bitPos = 0x406F - exp;
    roundNear =
           (roundingMode == softfloat_round_near_maxMag)
        || (roundingMode == softfloat_round_near_even);
    bitPos -= roundNear;
    index = indexWordLo( 4 );
    lastIndex = indexWordHi( 4 );
    extra = 0;
    for (;;) {
        wordA = aWPtr[index];
        if ( bitPos < 32 ) break;
        if ( wordA ) extra = 1;
        zWPtr[index] = 0;
        index += wordIncr;
        bitPos -= 32;
    }
    bit = (uint32_t) 1<<bitPos;
    if ( roundNear ) {
        wordZ = wordA + bit;
        carry = (wordZ < wordA);
        bit <<= 1;
        extrasMask = bit - 1;
        if ( exact && (extra || (wordA & extrasMask)) ) {
            softfloat_exceptionFlags |= softfloat_flag_inexact;
        }
        if (
            (roundingMode == softfloat_round_near_even)
                && !extra && !(wordZ & extrasMask)
        ) {
            if ( !bit ) {
                zWPtr[index] = wordZ;
                index += wordIncr;
                wordZ = aWPtr[index] + carry;
                carry &= !wordZ;
                zWPtr[index] = wordZ & ~1;
                goto propagateCarry;
            }
            wordZ &= ~bit;
        }
    } else {
        wordZ = wordA;
        carry = 0;
        extrasMask = bit - 1;
        if ( extra || (wordA & extrasMask) ) {
            if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
            if (
                roundingMode
                    == (signF128UI96( ui96 ) ? softfloat_round_min
                            : softfloat_round_max)
            ) {
                wordZ += bit;
                carry = (wordZ < wordA);
#ifdef SOFTFLOAT_ROUND_ODD
            } else if ( roundingMode == softfloat_round_odd ) {
                wordZ |= bit;
#endif
            }
        }
    }
    wordZ &= ~extrasMask;
    zWPtr[index] = wordZ;
 propagateCarry:
    while ( index != lastIndex ) {
        index += wordIncr;
        wordZ = aWPtr[index] + carry;
        zWPtr[index] = wordZ;
        carry &= !wordZ;
    }
    return;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 ui96:
    zWPtr[indexWordHi( 4 )] = ui96;

}

#endif

