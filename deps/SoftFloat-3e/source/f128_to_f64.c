
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015 The Regents of the University of
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

float64_t f128_to_f64( float128_t a )
{
    union ui128_f128 uA;
    uint_fast64_t uiA64, uiA0;
    bool sign;
    int_fast32_t exp;
    uint_fast64_t frac64, frac0;
    struct commonNaN commonNaN;
    uint_fast64_t uiZ;
    struct uint128 frac128;
    union ui64_f64 uZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uA.f = a;
    uiA64 = uA.ui.v64;
    uiA0  = uA.ui.v0;
    sign  = signF128UI64( uiA64 );
    exp   = expF128UI64( uiA64 );
    frac64 = fracF128UI64( uiA64 );
    frac0  = uiA0;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp == 0x7FFF ) {
        if ( frac64 | frac0 ) {
            softfloat_f128UIToCommonNaN( uiA64, uiA0, &commonNaN );
            uiZ = softfloat_commonNaNToF64UI( &commonNaN );
        } else {
            uiZ = packToF64UI( sign, 0x7FF, 0 );
        }
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    frac128 = softfloat_shortShiftLeft128( frac64, frac0, 14 );
    frac64 = frac128.v64 | (frac128.v0 != 0);
    if ( ! (exp | frac64) ) {
        uiZ = packToF64UI( sign, 0, 0 );
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    exp -= 0x3C01;
    if ( sizeof (int_fast16_t) < sizeof (int_fast32_t) ) {
        if ( exp < -0x1000 ) exp = -0x1000;
    }
    return
        softfloat_roundPackToF64(
            sign, exp, frac64 | UINT64_C( 0x4000000000000000 ) );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 uiZ:
    uZ.ui = uiZ;
    return uZ.f;

}

