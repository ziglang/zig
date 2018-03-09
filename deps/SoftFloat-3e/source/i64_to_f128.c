
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

#include <stdint.h>
#include "platform.h"
#include "internals.h"
#include "softfloat.h"

float128_t i64_to_f128( int64_t a )
{
    uint_fast64_t uiZ64, uiZ0;
    bool sign;
    uint_fast64_t absA;
    int_fast8_t shiftDist;
    struct uint128 zSig;
    union ui128_f128 uZ;

    if ( ! a ) {
        uiZ64 = 0;
        uiZ0  = 0;
    } else {
        sign = (a < 0);
        absA = sign ? -(uint_fast64_t) a : (uint_fast64_t) a;
        shiftDist = softfloat_countLeadingZeros64( absA ) + 49;
        if ( 64 <= shiftDist ) {
            zSig.v64 = absA<<(shiftDist - 64);
            zSig.v0  = 0;
        } else {
            zSig = softfloat_shortShiftLeft128( 0, absA, shiftDist );
        }
        uiZ64 = packToF128UI64( sign, 0x406E - shiftDist, zSig.v64 );
        uiZ0  = zSig.v0;
    }
    uZ.ui.v64 = uiZ64;
    uZ.ui.v0  = uiZ0;
    return uZ.f;

}

