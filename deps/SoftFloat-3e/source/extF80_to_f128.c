
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014 The Regents of the University of California.
All rights reserved.

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

float128_t extF80_to_f128( extFloat80_t a )
{
    union { struct extFloat80M s; extFloat80_t f; } uA;
    uint_fast16_t uiA64;
    uint_fast64_t uiA0;
    uint_fast16_t exp;
    uint_fast64_t frac;
    struct commonNaN commonNaN;
    struct uint128 uiZ;
    bool sign;
    struct uint128 frac128;
    union ui128_f128 uZ;

    uA.f = a;
    uiA64 = uA.s.signExp;
    uiA0  = uA.s.signif;
    exp = expExtF80UI64( uiA64 );
    frac = uiA0 & UINT64_C( 0x7FFFFFFFFFFFFFFF );
    if ( (exp == 0x7FFF) && frac ) {
        softfloat_extF80UIToCommonNaN( uiA64, uiA0, &commonNaN );
        uiZ = softfloat_commonNaNToF128UI( &commonNaN );
    } else {
        sign = signExtF80UI64( uiA64 );
        frac128 = softfloat_shortShiftLeft128( 0, frac, 49 );
        uiZ.v64 = packToF128UI64( sign, exp, frac128.v64 );
        uiZ.v0  = frac128.v0;
    }
    uZ.ui = uiZ;
    return uZ.f;

}

