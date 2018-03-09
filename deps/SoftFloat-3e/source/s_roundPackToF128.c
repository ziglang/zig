
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
#include "softfloat.h"

float128_t
 softfloat_roundPackToF128(
     bool sign,
     int_fast32_t exp,
     uint_fast64_t sig64,
     uint_fast64_t sig0,
     uint_fast64_t sigExtra
 )
{
    uint_fast8_t roundingMode;
    bool roundNearEven, doIncrement, isTiny;
    struct uint128_extra sig128Extra;
    uint_fast64_t uiZ64, uiZ0;
    struct uint128 sig128;
    union ui128_f128 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    roundingMode = softfloat_roundingMode;
    roundNearEven = (roundingMode == softfloat_round_near_even);
    doIncrement = (UINT64_C( 0x8000000000000000 ) <= sigExtra);
    if ( ! roundNearEven && (roundingMode != softfloat_round_near_maxMag) ) {
        doIncrement =
            (roundingMode
                 == (sign ? softfloat_round_min : softfloat_round_max))
                && sigExtra;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( 0x7FFD <= (uint32_t) exp ) {
        if ( exp < 0 ) {
            /*----------------------------------------------------------------
            *----------------------------------------------------------------*/
            isTiny =
                   (softfloat_detectTininess
                        == softfloat_tininess_beforeRounding)
                || (exp < -1)
                || ! doIncrement
                || softfloat_lt128(
                       sig64,
                       sig0,
                       UINT64_C( 0x0001FFFFFFFFFFFF ),
                       UINT64_C( 0xFFFFFFFFFFFFFFFF )
                   );
            sig128Extra =
                softfloat_shiftRightJam128Extra( sig64, sig0, sigExtra, -exp );
            sig64 = sig128Extra.v.v64;
            sig0  = sig128Extra.v.v0;
            sigExtra = sig128Extra.extra;
            exp = 0;
            if ( isTiny && sigExtra ) {
                softfloat_raiseFlags( softfloat_flag_underflow );
            }
            doIncrement = (UINT64_C( 0x8000000000000000 ) <= sigExtra);
            if (
                   ! roundNearEven
                && (roundingMode != softfloat_round_near_maxMag)
            ) {
                doIncrement =
                    (roundingMode
                         == (sign ? softfloat_round_min : softfloat_round_max))
                        && sigExtra;
            }
        } else if (
               (0x7FFD < exp)
            || ((exp == 0x7FFD)
                    && softfloat_eq128( 
                           sig64,
                           sig0,
                           UINT64_C( 0x0001FFFFFFFFFFFF ),
                           UINT64_C( 0xFFFFFFFFFFFFFFFF )
                       )
                    && doIncrement)
        ) {
            /*----------------------------------------------------------------
            *----------------------------------------------------------------*/
            softfloat_raiseFlags(
                softfloat_flag_overflow | softfloat_flag_inexact );
            if (
                   roundNearEven
                || (roundingMode == softfloat_round_near_maxMag)
                || (roundingMode
                        == (sign ? softfloat_round_min : softfloat_round_max))
            ) {
                uiZ64 = packToF128UI64( sign, 0x7FFF, 0 );
                uiZ0  = 0;
            } else {
                uiZ64 =
                    packToF128UI64(
                        sign, 0x7FFE, UINT64_C( 0x0000FFFFFFFFFFFF ) );
                uiZ0 = UINT64_C( 0xFFFFFFFFFFFFFFFF );
            }
            goto uiZ;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( sigExtra ) {
        softfloat_exceptionFlags |= softfloat_flag_inexact;
#ifdef SOFTFLOAT_ROUND_ODD
        if ( roundingMode == softfloat_round_odd ) {
            sig0 |= 1;
            goto packReturn;
        }
#endif
    }
    if ( doIncrement ) {
        sig128 = softfloat_add128( sig64, sig0, 0, 1 );
        sig64 = sig128.v64;
        sig0 =
            sig128.v0
                & ~(uint64_t)
                       (! (sigExtra & UINT64_C( 0x7FFFFFFFFFFFFFFF ))
                            & roundNearEven);
    } else {
        if ( ! (sig64 | sig0) ) exp = 0;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 packReturn:
    uiZ64 = packToF128UI64( sign, exp, sig64 );
    uiZ0  = sig0;
 uiZ:
    uZ.ui.v64 = uiZ64;
    uZ.ui.v0  = uiZ0;
    return uZ.f;

}

