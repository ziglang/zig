
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

#ifdef SOFTFLOAT_FAST_INT64

void f128M_to_extF80M( const float128_t *aPtr, extFloat80_t *zPtr )
{

    *zPtr = f128_to_extF80( *aPtr );

}

#else

void f128M_to_extF80M( const float128_t *aPtr, extFloat80_t *zPtr )
{
    const uint32_t *aWPtr;
    struct extFloat80M *zSPtr;
    uint32_t uiA96;
    bool sign;
    int32_t exp;
    struct commonNaN commonNaN;
    uint32_t sig[4];

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    aWPtr = (const uint32_t *) aPtr;
    zSPtr = (struct extFloat80M *) zPtr;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA96 = aWPtr[indexWordHi( 4 )];
    sign = signF128UI96( uiA96 );
    exp  = expF128UI96( uiA96 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( exp == 0x7FFF ) {
        if ( softfloat_isNaNF128M( aWPtr ) ) {
            softfloat_f128MToCommonNaN( aWPtr, &commonNaN );
            softfloat_commonNaNToExtF80M( &commonNaN, zSPtr );
            return;
        }
        zSPtr->signExp = packToExtF80UI64( sign, 0x7FFF );
        zSPtr->signif = UINT64_C( 0x8000000000000000 );
        return;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    exp = softfloat_shiftNormSigF128M( aWPtr, 15, sig );
    if ( exp == -128 ) {
        zSPtr->signExp = packToExtF80UI64( sign, 0 );
        zSPtr->signif = 0;
        return;
    }
    if ( sig[indexWord( 4, 0 )] ) sig[indexWord( 4, 1 )] |= 1;
    softfloat_roundPackMToExtF80M(
        sign, exp, &sig[indexMultiwordHi( 4, 3 )], 80, zSPtr );

}

#endif

