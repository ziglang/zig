
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

float128_t
 softfloat_normRoundPackToF128(
     bool sign, int_fast32_t exp, uint_fast64_t sig64, uint_fast64_t sig0 )
{
    int_fast8_t shiftDist;
    struct uint128 sig128;
    union ui128_f128 uZ;
    uint_fast64_t sigExtra;
    struct uint128_extra sig128Extra;

    if ( ! sig64 ) {
        exp -= 64;
        sig64 = sig0;
        sig0 = 0;
    }
    shiftDist = softfloat_countLeadingZeros64( sig64 ) - 15;
    exp -= shiftDist;
    if ( 0 <= shiftDist ) {
        if ( shiftDist ) {
            sig128 = softfloat_shortShiftLeft128( sig64, sig0, shiftDist );
            sig64 = sig128.v64;
            sig0  = sig128.v0;
        }
        if ( (uint32_t) exp < 0x7FFD ) {
            uZ.ui.v64 = packToF128UI64( sign, sig64 | sig0 ? exp : 0, sig64 );
            uZ.ui.v0  = sig0;
            return uZ.f;
        }
        sigExtra = 0;
    } else {
        sig128Extra =
            softfloat_shortShiftRightJam128Extra( sig64, sig0, 0, -shiftDist );
        sig64 = sig128Extra.v.v64;
        sig0  = sig128Extra.v.v0;
        sigExtra = sig128Extra.extra;
    }
    return softfloat_roundPackToF128( sign, exp, sig64, sig0, sigExtra );

}

