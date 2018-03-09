
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

void
 softfloat_normRoundPackMToExtF80M(
     bool sign,
     int32_t exp,
     uint32_t *extSigPtr,
     uint_fast8_t roundingPrecision,
     struct extFloat80M *zSPtr
 )
{
    int_fast16_t shiftDist;
    uint32_t wordSig;

    shiftDist = 0;
    wordSig = extSigPtr[indexWord( 3, 2 )];
    if ( ! wordSig ) {
        shiftDist = 32;
        wordSig = extSigPtr[indexWord( 3, 1 )];
        if ( ! wordSig ) {
            shiftDist = 64;
            wordSig = extSigPtr[indexWord( 3, 0 )];
            if ( ! wordSig ) {
                zSPtr->signExp = packToExtF80UI64( sign, 0 );
                zSPtr->signif = 0;
                return;
            }
        }
    }
    shiftDist += softfloat_countLeadingZeros32( wordSig );
    if ( shiftDist ) {
        exp -= shiftDist;
        softfloat_shiftLeft96M( extSigPtr, shiftDist, extSigPtr );
    }
    softfloat_roundPackMToExtF80M(
        sign, exp, extSigPtr, roundingPrecision, zSPtr );

}

