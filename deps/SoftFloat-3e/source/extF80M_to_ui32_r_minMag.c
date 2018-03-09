
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

uint_fast32_t extF80M_to_ui32_r_minMag( const extFloat80_t *aPtr, bool exact )
{

    return extF80_to_ui32_r_minMag( *aPtr, exact );

}

#else

uint_fast32_t extF80M_to_ui32_r_minMag( const extFloat80_t *aPtr, bool exact )
{
    const struct extFloat80M *aSPtr;
    uint_fast16_t uiA64;
    int32_t exp;
    uint64_t sig;
    int32_t shiftDist;
    bool sign;
    uint64_t shiftedSig;
    uint32_t z;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aSPtr = (const struct extFloat80M *) aPtr;
    uiA64 = aSPtr->signExp;
    exp = expExtF80UI64( uiA64 );
    sig = aSPtr->signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! sig && (exp != 0x7FFF) ) return 0;
    shiftDist = 0x403E - exp;
    if ( 64 <= shiftDist ) {
        if ( exact ) softfloat_exceptionFlags |= softfloat_flag_inexact;
        return 0;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    sign = signExtF80UI64( uiA64 );
    if ( shiftDist < 0 ) {
        if ( sign || sig>>32 || (shiftDist <= -31) ) goto invalid;
        shiftedSig = (uint64_t) (uint32_t) sig<<-shiftDist;
        if ( shiftedSig>>32 ) goto invalid;
        z = shiftedSig;
    } else {
        shiftedSig = sig;
        if ( shiftDist ) shiftedSig >>= shiftDist;
        if ( shiftedSig>>32 ) goto invalid;
        z = shiftedSig;
        if ( sign && z ) goto invalid;
        if ( exact && shiftDist && ((uint64_t) z<<shiftDist != sig) ) {
            softfloat_exceptionFlags |= softfloat_flag_inexact;
        }
    }
    return z;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_raiseFlags( softfloat_flag_invalid );
    return
        (exp == 0x7FFF) && (sig & UINT64_C( 0x7FFFFFFFFFFFFFFF ))
            ? ui32_fromNaN
            : sign ? ui32_fromNegOverflow : ui32_fromPosOverflow;

}

#endif

