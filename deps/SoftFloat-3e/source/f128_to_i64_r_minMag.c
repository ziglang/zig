
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

int_fast64_t f128_to_i64_r_minMag( float128_t a, bool exact )
{
    union ui128_f128 uA;
    uint_fast64_t uiA64, uiA0;
    bool sign;
    int_fast32_t exp;
    uint_fast64_t sig64, sig0;
    int_fast32_t shiftDist;
    int_fast8_t negShiftDist;
    int_fast64_t absZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.ui.v64;
    uiA0  = uA.ui.v0;
    sign  = signF128UI64( uiA64 );
    exp   = expF128UI64( uiA64 );
    sig64 = fracF128UI64( uiA64 );
    sig0  = uiA0;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    shiftDist = 0x402F - exp;
    if ( shiftDist < 0 ) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( shiftDist < -14 ) {
            if (
                   (uiA64 == UINT64_C( 0xC03E000000000000 ))
                && (sig0 < UINT64_C( 0x0002000000000000 ))
            ) {
                if ( exact && sig0 ) {
                    softfloat_exceptionFlags |= softfloat_flag_inexact;
                }
                return -INT64_C( 0x7FFFFFFFFFFFFFFF ) - 1;
            }
            softfloat_raiseFlags( softfloat_flag_invalid );
            return
                (exp == 0x7FFF) && (sig64 | sig0) ? i64_fromNaN
                    : sign ? i64_fromNegOverflow : i64_fromPosOverflow;
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        sig64 |= UINT64_C( 0x0001000000000000 );
        negShiftDist = -shiftDist;
        absZ = sig64<<negShiftDist | sig0>>(shiftDist & 63);
        if ( exact && (uint64_t) (sig0<<negShiftDist) ) {
            softfloat_exceptionFlags |= softfloat_flag_inexact;
        }
    } else {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        if ( 49 <= shiftDist ) {
            if ( exact && (exp | sig64 | sig0) ) {
                softfloat_exceptionFlags |= softfloat_flag_inexact;
            }
            return 0;
        }
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        sig64 |= UINT64_C( 0x0001000000000000 );
        absZ = sig64>>shiftDist;
        if ( exact && (sig0 || (absZ<<shiftDist != sig64)) ) {
            softfloat_exceptionFlags |= softfloat_flag_inexact;
        }
    }
    return sign ? -absZ : absZ;

}

