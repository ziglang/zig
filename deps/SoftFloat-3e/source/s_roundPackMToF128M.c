
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
#include "softfloat.h"

void
 softfloat_roundPackMToF128M(
     bool sign, int32_t exp, uint32_t *extSigPtr, uint32_t *zWPtr )
{
    uint_fast8_t roundingMode;
    bool roundNearEven;
    uint32_t sigExtra;
    bool doIncrement, isTiny;
    static const uint32_t maxSig[4] =
        INIT_UINTM4( 0x0001FFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF );
    uint32_t ui, uj;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    roundingMode = softfloat_roundingMode;
    roundNearEven = (roundingMode == softfloat_round_near_even);
    sigExtra = extSigPtr[indexWordLo( 5 )];
    doIncrement = (0x80000000 <= sigExtra);
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
                || (softfloat_compare128M(
                        extSigPtr + indexMultiwordHi( 5, 4 ), maxSig )
                        < 0);
            softfloat_shiftRightJam160M( extSigPtr, -exp, extSigPtr );
            exp = 0;
            sigExtra = extSigPtr[indexWordLo( 5 )];
            if ( isTiny && sigExtra ) {
                softfloat_raiseFlags( softfloat_flag_underflow );
            }
            doIncrement = (0x80000000 <= sigExtra);
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
            || ((exp == 0x7FFD) && doIncrement
                    && (softfloat_compare128M(
                            extSigPtr + indexMultiwordHi( 5, 4 ), maxSig )
                            == 0))
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
                ui = packToF128UI96( sign, 0x7FFF, 0 );
                uj = 0;
            } else {
                ui = packToF128UI96( sign, 0x7FFE, 0x0000FFFF );
                uj = 0xFFFFFFFF;
            }
            zWPtr[indexWordHi( 4 )] = ui;
            zWPtr[indexWord( 4, 2 )] = uj;
            zWPtr[indexWord( 4, 1 )] = uj;
            zWPtr[indexWord( 4, 0 )] = uj;
            return;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uj = extSigPtr[indexWord( 5, 1 )];
    if ( sigExtra ) {
        softfloat_exceptionFlags |= softfloat_flag_inexact;
#ifdef SOFTFLOAT_ROUND_ODD
        if ( roundingMode == softfloat_round_odd ) {
            uj |= 1;
            goto noIncrementPackReturn;
        }
#endif
    }
    if ( doIncrement ) {
        ++uj;
        if ( uj ) {
            if ( ! (sigExtra & 0x7FFFFFFF) && roundNearEven ) uj &= ~1;
            zWPtr[indexWord( 4, 2 )] = extSigPtr[indexWord( 5, 3 )];
            zWPtr[indexWord( 4, 1 )] = extSigPtr[indexWord( 5, 2 )];
            zWPtr[indexWord( 4, 0 )] = uj;
            ui = extSigPtr[indexWordHi( 5 )];
        } else {
            zWPtr[indexWord( 4, 0 )] = uj;
            ui = extSigPtr[indexWord( 5, 2 )] + 1;
            zWPtr[indexWord( 4, 1 )] = ui;
            uj = extSigPtr[indexWord( 5, 3 )];
            if ( ui ) {
                zWPtr[indexWord( 4, 2 )] = uj;
                ui = extSigPtr[indexWordHi( 5 )];
            } else {
                ++uj;
                zWPtr[indexWord( 4, 2 )] = uj;
                ui = extSigPtr[indexWordHi( 5 )];
                if ( ! uj ) ++ui;
            }
        }
    } else {
 noIncrementPackReturn:
        zWPtr[indexWord( 4, 0 )] = uj;
        ui = extSigPtr[indexWord( 5, 2 )];
        zWPtr[indexWord( 4, 1 )] = ui;
        uj |= ui;
        ui = extSigPtr[indexWord( 5, 3 )];
        zWPtr[indexWord( 4, 2 )] = ui;
        uj |= ui;
        ui = extSigPtr[indexWordHi( 5 )];
        uj |= ui;
        if ( ! uj ) exp = 0;
    }
    zWPtr[indexWordHi( 4 )] = packToF128UI96( sign, exp, ui );

}

