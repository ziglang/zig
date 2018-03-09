
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

#ifdef SOFTFLOAT_FAST_INT64

void f32_to_extF80M( float32_t a, extFloat80_t *zPtr )
{

    *zPtr = f32_to_extF80( a );

}

#else

void f32_to_extF80M( float32_t a, extFloat80_t *zPtr )
{
    struct extFloat80M *zSPtr;
    union ui32_f32 uA;
    uint32_t uiA;
    bool sign;
    int_fast16_t exp;
    uint32_t frac;
    struct commonNaN commonNaN;
    uint_fast16_t uiZ64;
    uint32_t uiZ32;
    struct exp16_sig32 normExpSig;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    zSPtr = (struct extFloat80M *) zPtr;
    uA.f = a;
    uiA = uA.ui;
    sign = signF32UI( uiA );
    exp  = expF32UI( uiA );
    frac = fracF32UI( uiA );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp == 0xFF ) {
        if ( frac ) {
            softfloat_f32UIToCommonNaN( uiA, &commonNaN );
            softfloat_commonNaNToExtF80M( &commonNaN, zSPtr );
            return;
        }
        uiZ64 = packToExtF80UI64( sign, 0x7FFF );
        uiZ32 = 0x80000000;
        goto uiZ;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! exp ) {
        if ( ! frac ) {
            uiZ64 = packToExtF80UI64( sign, 0 );
            uiZ32 = 0;
            goto uiZ;
        }
        normExpSig = softfloat_normSubnormalF32Sig( frac );
        exp = normExpSig.exp;
        frac = normExpSig.sig;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiZ64 = packToExtF80UI64( sign, exp + 0x3F80 );
    uiZ32 = 0x80000000 | (uint32_t) frac<<8;
 uiZ:
    zSPtr->signExp = uiZ64;
    zSPtr->signif = (uint64_t) uiZ32<<32;

}

#endif

